import SwiftUI
import FanShared

/// The curve is the control: two orange handles on a ruled plate. Left handle = where the fans start to climb,
/// right handle = where they reach full speed. Height = how hard the fans work (% of each fan's own range).
struct CurveEditor: View {
    @EnvironmentObject var model: AppModel
    private let tMin = 20.0, tMax = 100.0
    private let pad = EdgeInsets(top: 22, leading: 42, bottom: 30, trailing: 18)

    var body: some View {
        GeometryReader { geo in
            let plot = CGRect(x: pad.leading, y: pad.top,
                              width: geo.size.width - pad.leading - pad.trailing,
                              height: geo.size.height - pad.top - pad.bottom)
            let c = model.config.sanitized()
            let xOf = { (t: Double) in plot.minX + (t - tMin) / (tMax - tMin) * plot.width }
            let yOf = { (p: Double) in plot.maxY - p / 100 * plot.height }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.well)

                Canvas { ctx, _ in
                    // ruled grid: every 10°, quarter heights
                    for t in stride(from: 20.0, through: 100.0, by: 10.0) {
                        var p = Path(); p.move(to: CGPoint(x: xOf(t), y: plot.minY)); p.addLine(to: CGPoint(x: xOf(t), y: plot.maxY))
                        ctx.stroke(p, with: .color(Theme.hairline), lineWidth: 1)
                        ctx.draw(Text("\(Int(t))°").font(Theme.caption).foregroundColor(Theme.inkSoft),
                                 at: CGPoint(x: xOf(t), y: plot.maxY + 15), anchor: .center)
                    }
                    for p in [Double](arrayLiteral: 0, 50, 100) {
                        var l = Path(); l.move(to: CGPoint(x: plot.minX, y: yOf(p))); l.addLine(to: CGPoint(x: plot.maxX, y: yOf(p)))
                        ctx.stroke(l, with: .color(Theme.hairline), lineWidth: 1)
                        ctx.draw(Text("\(Int(p))%").font(Theme.caption).foregroundColor(Theme.inkSoft),
                                 at: CGPoint(x: plot.minX - 8, y: yOf(p)), anchor: .trailing)
                    }
                    // the curve, with a faint fill beneath it
                    var line = Path()
                    line.move(to: CGPoint(x: xOf(tMin), y: yOf(c.minPercent)))
                    line.addLine(to: CGPoint(x: xOf(c.minTemp), y: yOf(c.minPercent)))
                    line.addLine(to: CGPoint(x: xOf(c.maxTemp), y: yOf(c.maxPercent)))
                    line.addLine(to: CGPoint(x: xOf(tMax), y: yOf(c.maxPercent)))
                    var fill = line
                    fill.addLine(to: CGPoint(x: xOf(tMax), y: plot.maxY)); fill.addLine(to: CGPoint(x: xOf(tMin), y: plot.maxY)); fill.closeSubpath()
                    ctx.fill(fill, with: .color(Theme.ink.opacity(model.config.enabled ? 0.07 : 0.04)))
                    ctx.stroke(line, with: .color(model.config.enabled ? Theme.ink : Theme.inkSoft),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    // where the Mac is right now
                    if let t = model.currentTemp {
                        let tx = xOf(min(max(t, tMin), tMax))
                        var m = Path(); m.move(to: CGPoint(x: tx, y: plot.minY)); m.addLine(to: CGPoint(x: tx, y: plot.maxY))
                        ctx.stroke(m, with: .color(Theme.inkSoft), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        let py = yOf(c.percent(at: t))
                        ctx.fill(Path(ellipseIn: CGRect(x: tx - 5, y: py - 5, width: 10, height: 10)), with: .color(Theme.ink))
                        ctx.stroke(Path(ellipseIn: CGRect(x: tx - 5, y: py - 5, width: 10, height: 10)), with: .color(Theme.well), lineWidth: 2)
                        ctx.draw(Text("now \(Int(t.rounded()))°").font(Theme.caption).foregroundColor(Theme.ink),
                                 at: CGPoint(x: min(max(tx, plot.minX + 30), plot.maxX - 30), y: plot.minY - 10), anchor: .center)
                    }
                }
                .allowsHitTesting(false)

                handle(at: CGPoint(x: xOf(c.minTemp), y: yOf(c.minPercent)), plot: plot, tMin: tMin, isStart: true)
                handle(at: CGPoint(x: xOf(c.maxTemp), y: yOf(c.maxPercent)), plot: plot, tMin: tMin, isStart: false)
            }
            .coordinateSpace(name: "plot")
        }
        .frame(height: 230)
    }

    @ViewBuilder
    private func handle(at p: CGPoint, plot: CGRect, tMin: Double, isStart: Bool) -> some View {
        let c = model.config.sanitized()
        let temp = isStart ? c.minTemp : c.maxTemp
        let power = isStart ? c.minPercent : c.maxPercent
        ZStack {
            Circle().fill(Theme.accent).frame(width: 22, height: 22)
            Circle().strokeBorder(Theme.panel, lineWidth: 3).frame(width: 22, height: 22)
        }
        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1.5)
        .frame(width: 44, height: 44)                              // generous hit target
        .contentShape(Circle())
        .overlay {
            // label goes where the curve isn't: above-left of the start handle, below-right of the end handle
            let dx: CGFloat = isStart ? (p.x < plot.minX + 90 ? 46 : -46) : (p.x > plot.maxX - 90 ? -46 : 46)
            let dy: CGFloat = isStart ? -26 : (p.y < plot.minY + 40 ? 26 : -26)
            Text("\(Int(temp))° · \(Int(power))%")
                .font(Theme.caption).foregroundStyle(Theme.ink)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(Theme.panel))
                .fixedSize()
                .offset(x: dx, y: dy)
                .allowsHitTesting(false)
        }
        .position(p)
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("plot")).onChanged { v in
            let t = (tMin + (v.location.x - plot.minX) / plot.width * (tMax - tMin)).rounded()
            let pw = ((plot.maxY - v.location.y) / plot.height * 100 / 5).rounded() * 5
            var cfg = model.config
            if isStart {
                cfg.minTemp = min(max(t, tMin), cfg.maxTemp - 5)
                cfg.minPercent = min(max(pw, 0), cfg.maxPercent)
            } else {
                cfg.maxTemp = min(max(t, cfg.minTemp + 5), tMax)
                cfg.maxPercent = min(max(pw, cfg.minPercent), 100)
            }
            model.config = cfg
            model.pushConfig()
        })
        .accessibilityElement()
        .accessibilityLabel(isStart ? "Where the fans start to climb" : "Where the fans reach full speed")
        .accessibilityValue("\(Int(temp)) degrees, \(Int(power)) percent fan power")
        .accessibilityAdjustableAction { dir in
            var cfg = model.config
            let d: Double = dir == .increment ? 1 : -1
            if isStart { cfg.minTemp = min(max(cfg.minTemp + d, 20), cfg.maxTemp - 5) }
            else { cfg.maxTemp = min(max(cfg.maxTemp + d, cfg.minTemp + 5), 100) }
            model.config = cfg
            model.pushConfig()
        }
    }
}
