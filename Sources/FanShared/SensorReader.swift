import Foundation

/// Read-only view of the Mac's fans and temperatures. Works without root, so the app can show live data
/// even before the helper is installed.
public final class SensorReader {
    private let smc: SMC
    private var sensorKeys: [SensorGroup: [String]] = [:]

    public init(smc: SMC) {
        self.smc = smc
        discover()
    }

    /// Convenience for the app: opens its own SMC connection.
    public convenience init?() {
        guard let smc = SMC() else { return nil }
        self.init(smc: smc)
    }

    private func discover() {
        var groups: [SensorGroup: [String]] = [:]
        for key in smc.allKeys() where key.hasPrefix("T") {
            guard let v = smc.value(key), v > 10, v < 130 else { continue }
            groups[.hottest, default: []].append(key)
            if key.hasPrefix("Tp") || key.hasPrefix("Te") {
                groups[.cpu, default: []].append(key)
                groups[.cpuAverage, default: []].append(key)
            }
            else if key.hasPrefix("Tg") { groups[.gpu, default: []].append(key) }
            else if key.hasPrefix("TH") || key.hasPrefix("TN") { groups[.ssd, default: []].append(key) }
            else if key.hasPrefix("Tm") { groups[.memory, default: []].append(key) }
        }
        sensorKeys = groups
    }

    public var summary: String {
        sensorKeys.map { "\($0.key.rawValue)=\($0.value.count)" }.sorted().joined(separator: " ")
    }

    /// Highest plausible reading per group, keyed by `SensorGroup.rawValue`.
    public func temperatures() -> [String: Double] {
        var out: [String: Double] = [:]
        for (g, keys) in sensorKeys {
            let vals = keys.compactMap { smc.value($0) }.filter { $0 > 10 && $0 < 130 }
            if g == .cpuAverage { if !vals.isEmpty { out[g.rawValue] = vals.reduce(0, +) / Double(vals.count) } }
            else if let m = vals.max() { out[g.rawValue] = m }
        }
        return out
    }

    public func fans() -> [FanInfo] {
        (0..<smc.fanCount).map { i in
            FanInfo(index: i,
                    actual: smc.value("F\(i)Ac") ?? 0,
                    min: smc.value("F\(i)Mn") ?? 0,
                    max: smc.value("F\(i)Mx") ?? 0,
                    target: smc.value("F\(i)Tg") ?? 0,
                    manual: (smc.value("F\(i)Md") ?? 0) == 1)
        }
    }
}
