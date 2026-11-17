import SwiftUI
import FanShared

/// A printed dial: 41 ticks over a 270° sweep, a pointer that glides to the live rpm, big rounded numerals.
struct DialView: View {
    let fan: FanInfo
    var size: CGFloat = 220
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var scaleMax: Double { max(500, (fan.max / 500).rounded(.up) * 500) }
    private var fraction: Double { min(max(fan.actual / scaleMax, 0), 1) }
    private var angle: Double { 135 + 270 * fraction }

    var body: some View {
        ZStack {
            Canvas { ctx, sz in
                let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let r = min(sz.width, sz.height) / 2
                // recessed face
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Theme.well))
                // the fan's own working range, as a soft band under the ticks
                func pt(_ f: Double, _ rad: CGFloat) -> CGPoint {
                    let a = (135 + 270 * f) * .pi / 180
                    return CGPoint(x: c.x + rad * cos(a), y: c.y + rad * sin(a))
                }
                let f0 = fan.min / scaleMax, f1 = fan.max / scaleMax
                var band = Path()
                band.addArc(center: c, radius: r * 0.80, startAngle: .degrees(135 + 270 * f0),
                            endAngle: .degrees(135 + 270 * f1), clockwise: false)
                ctx.stroke(band, with: .color(Theme.ink.opacity(0.10)), style: StrokeStyle(lineWidth: r * 0.10, lineCap: .round))
                for i in 0...40 {
                    let f = Double(i) / 40
                    let major = i % 5 == 0
                    var p = Path()
                    p.move(to: pt(f, r * (major ? 0.80 : 0.84)))
                    p.addLine(to: pt(f, r * 0.92))
                    ctx.stroke(p, with: .color(Theme.inkSoft.opacity(major ? 0.9 : 0.45)),
                               style: StrokeStyle(lineWidth: major ? 2 : 1, lineCap: .round))
                }
            }
            // pointer: drawn at 3 o'clock, rotated into place
            ZStack {
                Capsule().fill(Theme.ink)
                    .frame(width: size * 0.15, height: 5)
                    .position(x: size - size * 0.15 / 2 - size * 0.075, y: size / 2)
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(angle))
            .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.82), value: angle)

            VStack(spacing: 0) {
                Text(Int(fan.actual).formatted())
                    .font(Theme.font(size * 0.20, .semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("rpm").font(Theme.font(max(11, size * 0.06), .medium)).foregroundStyle(Theme.inkSoft)
            }
            .offset(y: size * 0.04)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fan \(fan.index + 1) speed")
        .accessibilityValue("\(Int(fan.actual)) revolutions per minute")
    }
}
