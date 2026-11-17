// fanhelperd — root launchd daemon. Owns the fan curve so it keeps working when the menu-bar app is closed.
// Safety rules:
//   * fans go back to macOS automatic control when the curve is switched off, the helper is stopped
//     (SIGTERM/SIGINT/SIGHUP) or the chosen sensor disappears; above 95 °C they are forced to full speed;
//   * targets are always clamped to each fan's own min…max.
import Foundation
import FanShared

setvbuf(stdout, nil, _IOLBF, 0)
setvbuf(stderr, nil, _IOLBF, 0)

final class Controller {
    private let smc: SMC
    private let reader: SensorReader
    private let lock = NSLock()
    private var config: FanConfig
    private var smoothed: Double?
    private var smoothedSensor: SensorGroup?
    private var ramped: Double?          // fan power actually requested, slewed toward the curve
    private var lastTick = Date()
    private var status: HelperStatus
    private let configPath = configDir + "/config.json"

    init(smc: SMC) {
        self.smc = smc
        self.reader = SensorReader(smc: smc)
        if let d = try? Data(contentsOf: URL(fileURLWithPath: configDir + "/config.json")),
           let c = try? JSONDecoder().decode(FanConfig.self, from: d) {
            config = c.sanitized()
        } else {
            config = FanConfig()
        }
        status = HelperStatus(version: appVersion, fans: [], temps: [:], config: config, controlling: false,
                              targetPercent: nil, error: nil, failsafe: nil)
        print("sensors:", reader.summary)
    }

    /// Where the fans are right now, as % of their own range (average over fans).
    private func currentFanPercent() -> Double? {
        let vals: [Double] = (0..<smc.fanCount).compactMap { i in
            guard let a = smc.value(fanKey(i, "Ac")), let lo = smc.value(fanKey(i, "Mn")),
                  let hi = smc.value(fanKey(i, "Mx")), hi > lo else { return nil }
            return min(max((a - lo) / (hi - lo) * 100, 0), 100)
        }
        return vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
    }

    private func fanKey(_ i: Int, _ s: String) -> String { "F\(i)\(s)" }

    /// Give every fan back to macOS.
    private func handBack() {
        for i in 0..<smc.fanCount where (smc.value(fanKey(i, "Md")) ?? 0) != 0 {
            let r = smc.write(fanKey(i, "Md"), 0)
            if r != 0 { print("handBack fan \(i): write failed \(r)") }
        }
    }

    func setConfig(_ c: FanConfig) {
        lock.lock(); defer { lock.unlock() }
        config = c.sanitized()
        smoothed = nil
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(config) { try? d.write(to: URL(fileURLWithPath: configPath)) }
        tickLocked()
    }

    func tick() { lock.lock(); defer { lock.unlock() }; tickLocked() }

    func currentStatus() -> HelperStatus { lock.lock(); defer { lock.unlock() }; return status }

    func shutdown() { lock.lock(); handBack(); lock.unlock() }

    private func tickLocked() {
        let now = Date()
        let dt = min(max(now.timeIntervalSince(lastTick), 0), 5)
        lastTick = now
        let temps = reader.temperatures()

        var error: String?
        var failsafe: String?
        var controlling = false
        var pct: Double?

        let sensor = temps[config.sensor.rawValue]
        if let s = sensor {
            if smoothedSensor != config.sensor { smoothed = nil; smoothedSensor = config.sensor }
            smoothed = smoothed.map { 0.6 * $0 + 0.4 * s } ?? s       // damp spikes so the fans don't hunt
        }

        if !config.enabled {
            ramped = nil
            handBack()
        } else if sensor == nil || smoothed == nil {
            failsafe = "Sensor \(config.sensor.title) unavailable: macOS is in control"
            ramped = nil
            handBack()
        } else {
            let wanted = config.percent(at: smoothed!)
            if ramped == nil { ramped = currentFanPercent() ?? wanted }   // start from where the fans are: no jump
            if config.rampSeconds <= 0 {
                ramped = wanted
            } else {
                let step = 100 / config.rampSeconds * dt                  // % per second × elapsed seconds
                ramped = ramped! + min(max(wanted - ramped!, -step), step)
            }
            var p = ramped!
            if (sensor ?? 0) >= 95 || (temps[SensorGroup.hottest.rawValue] ?? 0) >= 105 {
                p = 100                                              // never let a quiet curve cook the machine
                ramped = 100                                         // safety is never delayed by the ramp
                failsafe = "Very hot: fans forced to full speed"
            }
            pct = p
            for i in 0..<smc.fanCount {
                guard let fmin = smc.value(fanKey(i, "Mn")), let fmax = smc.value(fanKey(i, "Mx")), fmax > fmin else { continue }
                let target = min(max(fmin + (fmax - fmin) * p / 100, fmin), fmax)
                if (smc.value(fanKey(i, "Md")) ?? 0) != 1 {
                    let r = smc.write(fanKey(i, "Md"), 1)
                    if r != 0 { error = "macOS refused manual fan mode (code \(r))"; continue }
                }
                let r = smc.write(fanKey(i, "Tg"), target)
                if r != 0 { error = "macOS refused the fan speed write (code \(r))"; continue }
                if (smc.value(fanKey(i, "Md")) ?? 0) != 1 { error = "macOS switched the fan back to automatic" }
            }
            controlling = error == nil
        }

        status = HelperStatus(version: appVersion, fans: reader.fans(), temps: temps, config: config,
                              controlling: controlling, targetPercent: pct, error: error, failsafe: failsafe)
    }
}

// MARK: - start up
guard let smc = SMC() else {
    fputs("cannot open AppleSMC\n", stderr)
    exit(1)
}
let controller = Controller(smc: smc)
print("fanhelperd \(appVersion) started, uid \(getuid()), fans \(smc.fanCount)")

// hand fans back to macOS on any normal way of stopping
var sources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT, SIGHUP] {
    signal(sig, SIG_IGN)
    let s = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    s.setEventHandler { controller.shutdown(); print("stopped (signal \(sig)), fans returned to macOS"); exit(0) }
    s.resume()
    sources.append(s)
}

let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "fan.tick"))
timer.schedule(deadline: .now(), repeating: 2.0)
timer.setEventHandler { controller.tick() }
timer.resume()

Thread.detachNewThread {
    serveHelper { req in
        switch req.cmd {
        case "config": if let c = req.config { controller.setConfig(c) }
        case "auto": var c = controller.currentStatus().config; c.enabled = false; controller.setConfig(c)
        default: break
        }
        return controller.currentStatus()
    }
}

dispatchMain()
