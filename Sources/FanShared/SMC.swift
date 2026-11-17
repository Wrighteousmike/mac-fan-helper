import Foundation
import IOKit

/// Minimal AppleSMC client. Reads work as any user; writes need root.
/// The kernel wants an 80-byte SMCKeyData struct; we fill it by hand-computed byte offsets
/// (Swift's own struct layout does not match the C one):
///   key@0  keyInfo{dataSize@28, dataType@32}  result@40  data8(command)@42  data32(index)@44  bytes@48
public final class SMC {
    private var conn: io_connect_t = 0

    public init?() {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard svc != 0 else { return nil }
        defer { IOObjectRelease(svc) }
        guard IOServiceOpen(svc, mach_task_self_, 0, &conn) == KERN_SUCCESS else { return nil }
    }

    deinit { if conn != 0 { IOServiceClose(conn) } }

    // MARK: raw calls
    private func call(_ input: [UInt8]) -> (out: [UInt8], kr: kern_return_t) {
        var inp = input
        var out = [UInt8](repeating: 0, count: 80)
        var size = 80
        let kr = IOConnectCallStructMethod(conn, 2, &inp, 80, &out, &size)
        return (out, kr)
    }

    private static func fourcc(_ s: String) -> UInt32 { s.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }
    private static func string(_ v: UInt32) -> String {
        String(bytes: [UInt8(v >> 24), UInt8((v >> 16) & 255), UInt8((v >> 8) & 255), UInt8(v & 255)], encoding: .ascii) ?? "????"
    }
    private static func u32(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24
    }
    private static func put32(_ b: inout [UInt8], _ o: Int, _ v: UInt32) {
        for k in 0..<4 { b[o + k] = UInt8((v >> (8 * UInt32(k))) & 255) }
    }

    public struct KeyInfo { public let size: Int; public let type: String }

    public func info(_ key: String) -> KeyInfo? {
        var i = [UInt8](repeating: 0, count: 80)
        SMC.put32(&i, 0, SMC.fourcc(key)); i[42] = 9
        let (o, kr) = call(i)
        guard kr == KERN_SUCCESS, o[40] == 0 else { return nil }
        return KeyInfo(size: Int(SMC.u32(o, 28)), type: SMC.string(SMC.u32(o, 32)))
    }

    public func readBytes(_ key: String) -> (type: String, bytes: [UInt8])? {
        guard let ki = info(key), ki.size > 0, ki.size <= 32 else { return nil }
        var i = [UInt8](repeating: 0, count: 80)
        SMC.put32(&i, 0, SMC.fourcc(key)); SMC.put32(&i, 28, UInt32(ki.size)); i[42] = 5
        let (o, kr) = call(i)
        guard kr == KERN_SUCCESS, o[40] == 0 else { return nil }
        return (ki.type, Array(o[48..<(48 + ki.size)]))
    }

    /// Numeric value of a key (flt / ui8 / ui16 / ui32 / sp78 / fpe2), nil if unreadable or another type.
    public func value(_ key: String) -> Double? {
        guard let (t, b) = readBytes(key) else { return nil }
        switch t {
        case "flt " where b.count == 4: return Double(Float(bitPattern: SMC.u32(b, 0)))
        case "ui8 " where b.count == 1: return Double(b[0])
        case "ui16" where b.count == 2: return Double((Int(b[0]) << 8) | Int(b[1]))
        case "ui32" where b.count == 4: return Double(b.reduce(0) { ($0 << 8) | UInt64($1) })
        case "sp78" where b.count == 2: return Double(Int8(bitPattern: b[0])) + Double(b[1]) / 256
        case "fpe2" where b.count == 2: return Double((Int(b[0]) << 6) | (Int(b[1]) >> 2))
        default: return nil
        }
    }

    /// Writes a number, encoded to the key's own type. Returns 0 on success, otherwise an IOKit / SMC error code.
    public func write(_ key: String, _ v: Double) -> Int32 {
        guard let ki = info(key) else { return -1 }
        var bytes: [UInt8]
        switch ki.type {
        case "flt ":
            let b = Float(v).bitPattern
            bytes = [UInt8(b & 255), UInt8((b >> 8) & 255), UInt8((b >> 16) & 255), UInt8((b >> 24) & 255)]
        case "ui8 ": bytes = [UInt8(max(0, min(255, v)))]
        case "fpe2":
            let n = Int(max(0, min(16383, v))) << 2
            bytes = [UInt8((n >> 8) & 255), UInt8(n & 255)]
        default: return -2
        }
        guard bytes.count == ki.size else { return -3 }
        var i = [UInt8](repeating: 0, count: 80)
        SMC.put32(&i, 0, SMC.fourcc(key)); SMC.put32(&i, 28, UInt32(ki.size)); i[42] = 6
        for (k, x) in bytes.enumerated() { i[48 + k] = x }
        let (o, kr) = call(i)
        return kr != KERN_SUCCESS ? Int32(bitPattern: UInt32(bitPattern: kr)) : Int32(o[40])
    }

    public func allKeys() -> [String] {
        let count = Int(value("#KEY") ?? 0)
        var out: [String] = []
        out.reserveCapacity(count)
        for idx in 0..<count {
            var i = [UInt8](repeating: 0, count: 80)
            i[42] = 8; SMC.put32(&i, 44, UInt32(idx))
            let (o, kr) = call(i)
            if kr == KERN_SUCCESS { out.append(SMC.string(SMC.u32(o, 0))) }
        }
        return out
    }

    public var fanCount: Int { Int(value("FNum") ?? 0) }
}
