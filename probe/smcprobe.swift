import Foundation
import IOKit

var conn: io_connect_t = 0
let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
guard svc != 0, IOServiceOpen(svc, mach_task_self_, 0, &conn) == KERN_SUCCESS else { print("cannot open AppleSMC"); exit(1) }

func fourcc(_ s: String) -> UInt32 { s.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }
func str(_ v: UInt32) -> String { String(bytes: [UInt8(v>>24), UInt8((v>>16)&255), UInt8((v>>8)&255), UInt8(v&255)], encoding: .ascii) ?? "?" }

// 80-byte SMCKeyData: key@0 keyInfo{size@28,type@32,attr@36} result@40 status@41 data8@42 data32@44 bytes@48
func call(_ i: [UInt8]) -> ([UInt8], kern_return_t) {
    var inp = i; var out = [UInt8](repeating: 0, count: 80); var sz = 80
    let r = IOConnectCallStructMethod(conn, 2, &inp, 80, &out, &sz)
    return (out, r)
}
func u32(_ b: [UInt8], _ o: Int) -> UInt32 { UInt32(b[o]) | UInt32(b[o+1])<<8 | UInt32(b[o+2])<<16 | UInt32(b[o+3])<<24 }
func put32(_ b: inout [UInt8], _ o: Int, _ v: UInt32) { for k in 0..<4 { b[o+k] = UInt8((v >> (8*UInt32(k))) & 255) } }

func info(_ key: UInt32) -> (UInt32, UInt32)? {
    var i = [UInt8](repeating: 0, count: 80); put32(&i, 0, key); i[42] = 9
    let (o, r) = call(i); return (r == 0 && o[40] == 0) ? (u32(o, 28), u32(o, 32)) : nil
}
func read(_ key: String) -> (String, [UInt8])? {
    guard let (sz, ty) = info(fourcc(key)) else { return nil }
    var i = [UInt8](repeating: 0, count: 80); put32(&i, 0, fourcc(key)); put32(&i, 28, sz); i[42] = 5
    let (o, r) = call(i); guard r == 0, o[40] == 0 else { return nil }
    return (str(ty), Array(o[48..<(48+Int(sz))]))
}
func decode(_ t: String, _ b: [UInt8]) -> String {
    switch t {
    case "flt ": return b.count == 4 ? String(Float(bitPattern: u32(b, 0))) : "\(b)"
    case "ui8 ": return "\(b[0])"
    case "ui16": return "\((Int(b[0])<<8)|Int(b[1]))"
    case "ui32": return "\(b.reduce(0) { ($0<<8)|Int($1) })"
    case "sp78": return String(Double(Int8(bitPattern: b[0])) + Double(b[1])/256)
    case "fpe2": return String(Double((Int(b[0])<<6)|(Int(b[1])>>2)))
    default: return "\(t) \(b)"
    }
}
func write(_ key: String, _ bytes: [UInt8]) -> kern_return_t {
    guard let (sz, _) = info(fourcc(key)), Int(sz) == bytes.count else { return -1 }
    var i = [UInt8](repeating: 0, count: 80); put32(&i, 0, fourcc(key)); put32(&i, 28, sz); i[42] = 6
    for (k, v) in bytes.enumerated() { i[48 + k] = v }
    let (o, r) = call(i); return r != 0 ? r : kern_return_t(o[40])
}
func f32le(_ v: Float) -> [UInt8] { let b = v.bitPattern; return [UInt8(b & 255), UInt8((b>>8)&255), UInt8((b>>16)&255), UInt8((b>>24)&255)] }
func rpm() -> String { if let (t,b) = read("F0Ac") { return decode(t,b) } else { return "?" } }

if CommandLine.arguments.count >= 3 && CommandLine.arguments[1] == "set" {
    let target = Float(CommandLine.arguments[2]) ?? 3000
    func restore() { let r = write("F0Md", [0]); print("restore auto mode ->", r); }
    signal(SIGINT) { _ in _ = write("F0Md", [0]); exit(0) }
    signal(SIGTERM) { _ in _ = write("F0Md", [0]); exit(0) }
    print("root?", getuid() == 0, " fan now", rpm(), "rpm; mode", read("F0Md").map { decode($0.0, $0.1) } ?? "?")
    print("set manual mode F0Md=1 ->", write("F0Md", [1]))
    print("set target F0Tg=\(target) ->", write("F0Tg", f32le(target)))
    for s in 1...12 { Thread.sleep(forTimeInterval: 1); print("  t+\(s)s actual", rpm(), "target", read("F0Tg").map { decode($0.0, $0.1) } ?? "?", "mode", read("F0Md").map { decode($0.0, $0.1) } ?? "?") }
    restore(); Thread.sleep(forTimeInterval: 2); print("after restore: mode", read("F0Md").map { decode($0.0, $0.1) } ?? "?", "rpm", rpm())
    exit(0)
}
var cnt = 0
if let (t, b) = read("#KEY") { cnt = Int(decode(t, b)) ?? 0 }
print("key count:", cnt)
var names: [String] = []
for idx in 0..<cnt {
    var i = [UInt8](repeating: 0, count: 80); i[42] = 8; put32(&i, 44, UInt32(idx))
    let (o, r) = call(i); if r == 0 { names.append(str(u32(o, 0))) }
}
print("fan keys:")
for n in names where n.hasPrefix("F") { if let (t,b) = read(n) { print("  \(n) [\(t)] =", decode(t,b)) } }
print("temperature-like keys (T*, plausible values):")
var shown = 0
for n in names where n.hasPrefix("T") {
    if let (t,b) = read(n), t == "flt " || t == "sp78", let d = Double(decode(t,b)), d > 5 && d < 150 { print("  \(n) =", d); shown += 1 }
}
print("shown", shown)
