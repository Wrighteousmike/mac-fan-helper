import Foundation

public let appVersion = "0.2.1"
public let helperLabel = "com.local.fanhelper.daemon"
public var socketPath: String { ProcessInfo.processInfo.environment["FANHELPER_SOCKET"] ?? "/var/run/fanhelper.sock" }
public var configDir: String {
    ProcessInfo.processInfo.environment["FANHELPER_CONFIG_DIR"] ?? "/Library/Application Support/FanHelper"
}

/// Which temperature drives the curve.
public enum SensorGroup: String, CaseIterable, Codable {
    case cpu, cpuAverage, gpu, ssd, memory, hottest
    public var title: String {
        switch self {
        case .cpu: return "CPU"
        case .cpuAverage: return "CPU average"
        case .gpu: return "GPU"
        case .ssd: return "SSD"
        case .memory: return "Memory"
        case .hottest: return "Hottest sensor"
        }
    }
}

public struct FanConfig: Codable, Equatable {
    public var enabled = false
    public var sensor: SensorGroup = .cpu
    public var minTemp = 50.0          // °C at/below which the fans run at minPercent
    public var maxTemp = 85.0          // °C at/above which the fans run at maxPercent
    public var minPercent = 0.0        // % of each fan's own min…max rpm range
    public var maxPercent = 100.0
    public var rampSeconds = 15.0      // time for the fans to travel the full 0…100 % when the curve asks for a change
    public init() {}

    enum CodingKeys: String, CodingKey { case enabled, sensor, minTemp, maxTemp, minPercent, maxPercent, rampSeconds }
    public init(from d: Decoder) throws {          // older config files have no rampSeconds
        let c = try d.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        sensor = (try? c.decodeIfPresent(SensorGroup.self, forKey: .sensor)) ?? .cpu
        minTemp = try c.decodeIfPresent(Double.self, forKey: .minTemp) ?? 50
        maxTemp = try c.decodeIfPresent(Double.self, forKey: .maxTemp) ?? 85
        minPercent = try c.decodeIfPresent(Double.self, forKey: .minPercent) ?? 0
        maxPercent = try c.decodeIfPresent(Double.self, forKey: .maxPercent) ?? 100
        rampSeconds = try c.decodeIfPresent(Double.self, forKey: .rampSeconds) ?? 15
    }

    /// Keeps hand-edited or stale values sane.
    public func sanitized() -> FanConfig {
        var c = self
        c.minTemp = min(max(c.minTemp, 20), 100)
        c.maxTemp = min(max(c.maxTemp, c.minTemp + 5), 110)
        c.minPercent = min(max(c.minPercent, 0), 100)
        c.maxPercent = min(max(c.maxPercent, c.minPercent), 100)
        c.rampSeconds = min(max(c.rampSeconds, 0), 120)
        return c
    }

    /// Fan power (0…100 % of the fan's range) for a temperature: flat, then a straight ramp, then flat.
    public func percent(at temp: Double) -> Double {
        let c = sanitized()
        if temp <= c.minTemp { return c.minPercent }
        if temp >= c.maxTemp { return c.maxPercent }
        let f = (temp - c.minTemp) / (c.maxTemp - c.minTemp)
        return c.minPercent + f * (c.maxPercent - c.minPercent)
    }
}

public struct FanInfo: Codable, Identifiable {
    public var index: Int
    public var actual: Double
    public var min: Double
    public var max: Double
    public var target: Double
    public var manual: Bool
    public var id: Int { index }
    public init(index: Int, actual: Double, min: Double, max: Double, target: Double, manual: Bool) {
        self.index = index; self.actual = actual; self.min = min; self.max = max; self.target = target; self.manual = manual
    }
}

public struct HelperStatus: Codable {
    public var version: String
    public var fans: [FanInfo]
    public var temps: [String: Double]      // SensorGroup.rawValue -> °C
    public var config: FanConfig
    public var controlling: Bool            // true while the helper is overriding the system fan curve
    public var targetPercent: Double?
    public var error: String?               // e.g. macOS refused the fan write
    public var failsafe: String?            // why control was handed back to macOS
    public init(version: String, fans: [FanInfo], temps: [String: Double], config: FanConfig, controlling: Bool,
                targetPercent: Double?, error: String?, failsafe: String?) {
        self.version = version; self.fans = fans; self.temps = temps; self.config = config
        self.controlling = controlling; self.targetPercent = targetPercent; self.error = error; self.failsafe = failsafe
    }
}

public struct HelperRequest: Codable {
    public var cmd: String                  // "status" | "config" | "auto"
    public var config: FanConfig?
    public init(cmd: String, config: FanConfig? = nil) { self.cmd = cmd; self.config = config }
}

// MARK: - unix-socket plumbing (one JSON request per connection, answered then closed)

private func makeAddr(_ path: String) -> sockaddr_un {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutablePointer(to: &addr.sun_path) {
        $0.withMemoryRebound(to: CChar.self, capacity: 104) { _ = strncpy($0, path, 103) }
    }
    return addr
}

private func setTimeouts(_ fd: Int32, seconds: Int) {
    var tv = timeval(tv_sec: seconds, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
}

private func writeAll(_ fd: Int32, _ data: Data) {
    data.withUnsafeBytes { raw in
        var sent = 0
        while sent < data.count {
            let n = send(fd, raw.baseAddress! + sent, data.count - sent, 0)
            if n <= 0 { return }
            sent += n
        }
    }
}

private func readAll(_ fd: Int32, limit: Int = 1 << 16) -> Data {
    var data = Data()
    var buf = [UInt8](repeating: 0, count: 4096)
    while data.count < limit {
        let n = recv(fd, &buf, buf.count, 0)
        if n <= 0 { break }
        data.append(buf, count: n)
    }
    return data
}

/// App side: ask the helper something. nil = helper not installed / not running / not answering.
public func helperCall(_ req: HelperRequest, timeout: Int = 3) -> HelperStatus? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    defer { close(fd) }
    setTimeouts(fd, seconds: timeout)
    var addr = makeAddr(socketPath)
    let rc = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    guard rc == 0, let body = try? JSONEncoder().encode(req) else { return nil }
    writeAll(fd, body)
    shutdown(fd, SHUT_WR)
    return try? JSONDecoder().decode(HelperStatus.self, from: readAll(fd))
}

/// Helper side: serve requests forever on the calling thread. `allowedUID` is the console user (and root is always allowed).
public func serveHelper(handler: @escaping (HelperRequest) -> HelperStatus) {
    unlink(socketPath)
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { fputs("socket() failed\n", stderr); return }
    var addr = makeAddr(socketPath)
    let rc = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    guard rc == 0, listen(fd, 8) == 0 else { fputs("bind/listen failed: \(errno)\n", stderr); return }
    chmod(socketPath, 0o666)        // any local user may connect; the peer-uid check below decides who is served

    while true {
        let c = accept(fd, nil, nil)
        if c < 0 { continue }
        setTimeouts(c, seconds: 2)
        var uid: uid_t = 0, gid: gid_t = 0
        var consoleStat = stat()
        let consoleUID: uid_t = stat("/dev/console", &consoleStat) == 0 ? consoleStat.st_uid : 0
        if getpeereid(c, &uid, &gid) == 0, uid == 0 || uid == consoleUID,
           let req = try? JSONDecoder().decode(HelperRequest.self, from: readAll(c)),
           let out = try? JSONEncoder().encode(handler(req)) {
            writeAll(c, out)
        }
        close(c)
    }
}
