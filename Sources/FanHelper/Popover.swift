import SwiftUI
import FanShared

/// The small menu-bar panel: glanceable, with the three feels and the switch. The big window does the setup.
struct PopoverView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.fans.first.map { Int($0.actual).formatted() } ?? "–")
                        .font(Theme.font(34, .semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                    Text("rpm").font(Theme.small).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(model.currentTemp.map { "\(Int($0.rounded()))°" } ?? "–")
                        .font(Theme.font(34, .semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                    Text(model.config.sensor.title).font(Theme.small).foregroundStyle(Theme.inkSoft)
                }
            }
            StatusPill()

            if model.reachable {
                HStack(spacing: 8) {
                    ForEach(FanPreset.all) { p in
                        let on = model.activePreset == p
                        Button { model.apply(preset: p) } label: {
                            Text(p.name).font(Theme.font(13, .semibold)).foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity).frame(height: 34)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(on ? Theme.accent.opacity(0.14) : Theme.well))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(on ? Theme.accent : .clear, lineWidth: 2))
                        }.buttonStyle(.plain)
                    }
                }
                Toggle("Use my fan curve", isOn: Binding(get: { model.config.enabled }, set: { model.setEnabled($0) }))
                    .toggleStyle(.switch).tint(Theme.accent).font(Theme.bodyBold)
            } else {
                Text("Open Fan Helper to finish setup.").font(Theme.body).foregroundStyle(Theme.ink)
            }

            HStack {
                Button("Open Fan Helper") { model.openMainWindow() }.buttonStyle(RubberButtonStyle(compact: true))
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(QuietButtonStyle())
            }
        }
        .padding(16)
        .frame(width: 304)
        .background(Theme.panel)
    }
}
