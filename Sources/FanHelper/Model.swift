import Foundation
import SwiftUI
import FanShared

struct FanPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let blurb: String
    let minTemp: Double, maxTemp: Double, minPercent: Double, maxPercent: Double

    static let all: [FanPreset] = [
        FanPreset(id: "quiet", name: "Quiet", blurb: "Hushed until things get properly warm.",
                  minTemp: 60, maxTemp: 90, minPercent: 0, maxPercent: 70),
        FanPreset(id: "balanced", name: "Balanced", blurb: "Rises steadily as your Mac warms up.",
                  minTemp: 50, maxTemp: 85, minPercent: 0, maxPercent: 100),
        FanPreset(id: "cool", name: "Cool", blurb: "Starts early to keep it cooler. A bit more fan noise.",
                  minTemp: 40, maxTemp: 75, minPercent: 15, maxPercent: 100),
    ]
}

enum StatusTone { case idle, active, alert }

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    // from the helper
    @Published var status: HelperStatus?
    @Published var reachable = false
    // read straight from the SMC (works before the helper exists)
    @Published var liveTemps: [String: Double] = [:]
    @Published var liveFans: [FanInfo] = []

    @Published var config = FanConfig()
    @Published var busy = false
    @Published var message: String?
    @Published var launchAtLogin = Installer.loginItemEnabled
    @AppStorage("showReadout") var showReadout = true

    // wired up by the app delegate
    var openMainWindow: () -> Void = {}
    var closeMainWindow: () -> Void = {}

    private let reader = SensorReader()
    private var timer: Timer?
    private var adoptedConfig = false
    private var pushTask: Task<Void, Never>?
    private var refreshing = false

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: derived
    var helperOutdated: Bool { reachable && status?.version != appVersion }
    var currentTemp: Double? { liveTemps[config.sensor.rawValue] }
    var fans: [FanInfo] { liveFans.isEmpty ? (status?.fans ?? []) : liveFans }
    var activePreset: FanPreset? {
        FanPreset.all.first { $0.minTemp == config.minTemp && $0.maxTemp == config.maxTemp
            && $0.minPercent == config.minPercent && $0.maxPercent == config.maxPercent }
    }

    var statusText: (String, StatusTone) {
        guard let s = status else { return ("Helper not installed yet", .idle) }
        if let e = s.error { return (e, .alert) }
        if let f = s.failsafe { return (f, .alert) }
        if s.controlling, let p = s.targetPercent { return ("Your curve is in charge · \(Int(p.rounded()))% fan power", .active) }
        return ("macOS is in charge of the fans", .idle)
    }

    /// One plain sentence describing the curve.
    var curveSentence: String {
        let c = config.sanitized()
        let lo = c.minPercent == 0 ? "stay at their quietest" : "run at \(Int(c.minPercent))%"
        let hi = c.maxPercent == 100 ? "full speed" : "\(Int(c.maxPercent))% power"
        return "Fans \(lo) until \(Int(c.minTemp))°, then climb to \(hi) by \(Int(c.maxTemp))°."
    }

    // MARK: polling
    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        let reader = self.reader
        Task.detached {
            let temps = reader?.temperatures() ?? [:]
            let fans = reader?.fans() ?? []
            let s = helperCall(HelperRequest(cmd: "status"))
            await MainActor.run {
                self.liveTemps = temps
                self.liveFans = fans
                self.apply(s)
                self.refreshing = false
            }
        }
    }

    private func apply(_ s: HelperStatus?) {
        status = s
        reachable = s != nil
        if let s = s, !adoptedConfig { config = s.config; adoptedConfig = true }
        if s == nil { adoptedConfig = false }
    }

    // MARK: actions
    /// Debounced, so dragging a handle sends one update, not hundreds.
    func pushConfig() {
        guard reachable else { return }
        pushTask?.cancel()
        let cfg = config.sanitized()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            let s = await Task.detached { helperCall(HelperRequest(cmd: "config", config: cfg)) }.value
            self?.apply(s)
        }
    }

    func apply(preset p: FanPreset) {
        config.minTemp = p.minTemp; config.maxTemp = p.maxTemp
        config.minPercent = p.minPercent; config.maxPercent = p.maxPercent
        pushConfig()
    }

    func setEnabled(_ on: Bool) {
        config.enabled = on
        pushConfig()
    }

    func installHelper() { run("Installing helper…") { Installer.installHelper() } }
    func removeHelper() { run("Removing helper…") { Installer.removeHelper() } }

    private func run(_ title: String, _ work: @escaping @Sendable () -> (Bool, String)) {
        busy = true
        message = title
        Task.detached {
            let (ok, msg) = work()
            try? await Task.sleep(nanoseconds: 1_200_000_000)    // give launchd a moment to start the daemon
            let s = helperCall(HelperRequest(cmd: "status"))
            await MainActor.run {
                self.busy = false
                self.adoptedConfig = false
                self.apply(s)
                self.message = ok ? nil : (msg.isEmpty ? "That didn't work." : msg)
                if ok && s == nil && title.hasPrefix("Installing") {
                    self.message = "Installed, but the helper isn't answering yet. Check System Settings › General › Login Items & Extensions."
                }
                if msg == "Cancelled" { self.message = nil }
            }
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        if let err = Installer.setLoginItem(on) { message = err }
        launchAtLogin = Installer.loginItemEnabled
    }
}
