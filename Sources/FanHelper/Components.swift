import SwiftUI
import FanShared

// MARK: surfaces

/// A raised plate. Elevation is one soft shadow; no border on top of it.
struct Plate<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel))
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.07), radius: 10, x: 0, y: 3)
    }
}

// MARK: buttons

/// The big rubber button. Orange means "press me".
struct RubberButtonStyle: ButtonStyle {
    var compact = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(compact ? 13 : 15, .semibold))
            .foregroundStyle(enabled ? Theme.onAccent : Theme.inkSoft)
            .padding(.horizontal, compact ? 14 : 20)
            .frame(height: compact ? 32 : 44)
            .background(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous)
                .fill(enabled ? Theme.accent : Theme.well))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet secondary button (recessed, ink text).
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(13, .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.well))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: status

struct StatusPill: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        let (text, tone) = model.statusText
        HStack(spacing: 7) {
            Circle().fill(tone == .alert ? Theme.alert : (tone == .active ? Theme.ink : Theme.inkSoft.opacity(0.5)))
                .frame(width: 7, height: 7)
            Text(text).font(Theme.small).foregroundStyle(tone == .alert ? Theme.alert : Theme.ink)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Theme.well))
        .animation(.easeOut(duration: 0.2), value: text)
        .accessibilityElement(children: .combine)
    }
}

// MARK: sensor chips

struct SensorChips: View {
    @EnvironmentObject var model: AppModel
    private let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(SensorGroup.allCases, id: \.self) { g in
                let selected = model.config.sensor == g
                Button {
                    model.config.sensor = g
                    model.pushConfig()
                } label: {
                    VStack(spacing: 2) {
                        Text(g == .hottest ? "Hottest" : (g == .cpuAverage ? "CPU avg" : g.title)).font(Theme.caption).foregroundStyle(Theme.inkSoft)
                        Text(model.liveTemps[g.rawValue].map { "\(Int($0.rounded()))°" } ?? "–")
                            .font(Theme.font(17, .semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                    }
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? Theme.accent.opacity(0.14) : Theme.well))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(g.title) temperature")
                .accessibilityValue("\(model.liveTemps[g.rawValue].map { "\(Int($0.rounded())) degrees" } ?? "unavailable")")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }
}
