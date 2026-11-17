import SwiftUI
import AppKit

/// "Soft appliance" palette: warm putty body, warm charcoal ink, and ONE rubber-button orange that appears
/// only on things you can press or drag. Every colour has a light and a dark value.
enum Theme {
    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            let isDark = ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    static let ground     = dyn(0xE6E1D6, 0x1E1C19)   // the body of the appliance
    static let panel      = dyn(0xF3EFE7, 0x2A2724)   // raised plates
    static let well       = dyn(0xE9E4DA, 0x221F1C)   // recessed areas (the curve plate, chips)
    static let ink        = dyn(0x2B2824, 0xEDE7DC)
    static let inkSoft    = dyn(0x6B6358, 0xA79E90)   // ≥4.5:1 on panel and well in both modes
    static let hairline   = dyn(0xD6D0C3, 0x3A3631)
    static let accent     = dyn(0xCC4A18, 0xF07A45)   // rubber orange (white text on light, dark text on dark)
    static let onAccent   = dyn(0xFFFFFF, 0x1E1C19)
    static let alert      = dyn(0xB3261E, 0xFF8A80)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // fixed scale, ~1.2 steps
    static let caption  = font(11, .medium)
    static let small    = font(12)
    static let body     = font(14)
    static let bodyBold = font(14, .semibold)
    static let title    = font(22, .semibold)
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}
