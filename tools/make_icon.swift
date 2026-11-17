// Draws the app icon (putty tile, ink fan, orange hub) and writes Resources/AppIcon.icns via iconutil.
import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    let inset = s * 0.055
    let tile = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: tile, xRadius: s * 0.205, yRadius: s * 0.205)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = s * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.set()
    color(0xEDE8DD).setFill()
    path.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    // soft top-light
    NSGraphicsContext.current?.saveGraphicsState()
    path.addClip()
    NSGradient(starting: NSColor.white.withAlphaComponent(0.35), ending: NSColor.clear)?
        .draw(in: tile, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // ink fan
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.56, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "fan.fill", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: sym.size)
        tinted.lockFocus()
        sym.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        color(0x2B2824).set()
        NSRect(origin: .zero, size: sym.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        let r = NSRect(x: (s - tinted.size.width) / 2, y: (s - tinted.size.height) / 2, width: tinted.size.width, height: tinted.size.height)
        tinted.draw(in: r)
    }
    // rubber-orange hub
    let hub = s * 0.085
    color(0xCC4A18).setFill()
    NSBezierPath(ovalIn: NSRect(x: s / 2 - hub, y: s / 2 - hub, width: hub * 2, height: hub * 2)).fill()
    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

let dir = CommandLine.arguments[1]
let set = dir + "/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
for (name, px) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
                   ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
                   ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(set)/\(name).png"))
}
