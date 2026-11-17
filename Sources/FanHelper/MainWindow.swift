import SwiftUI
import AppKit
import FanShared

struct MainWindowView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmRemove = false

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            VStack(spacing: 0) {
                // sits level with the traffic lights; the whole strip drags the window
                HStack {
                    Spacer().frame(width: 84)
                    Text("Fan Helper").font(Theme.font(13, .semibold)).foregroundStyle(Theme.inkSoft)
                    Spacer()
                }
                .frame(height: 30)
                .padding(.bottom, 12)

                HStack(alignment: .top, spacing: 20) {
                    LivePanel().frame(width: 316)
                    Group {
                        if model.reachable { CurvePanel() } else { HelperPanel() }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
                .frame(maxHeight: .infinity)

                if let m = model.message {
                    Text(m).font(Theme.small).foregroundStyle(Theme.alert)
                        .padding(.horizontal, 28).padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                FooterBar(confirmRemove: $confirmRemove)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 900, minHeight: 650)
        .disabled(model.busy)
        .overlay { if model.busy { ProgressView().controlSize(.large) } }
        .confirmationDialog("Remove the helper?", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive) { model.removeHelper() }
        } message: {
            Text("Your fan curve stops and macOS takes the fans back. You can install the helper again any time.")
        }
    }
}

// MARK: left: what the Mac is doing

struct LivePanel: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Plate {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Right now").font(Theme.title).foregroundStyle(Theme.ink)
                    Text("Live from your Mac").font(Theme.small).foregroundStyle(Theme.inkSoft)
                }
                let fans = model.fans
                if fans.count <= 1 {
                    if let f = fans.first {
                        VStack(spacing: 6) {
                            DialView(fan: f, size: 240).frame(maxWidth: .infinity)
                            Text("Fan speed range \(Int(f.min).formatted())–\(Int(f.max).formatted()) rpm")
                                .font(Theme.caption).foregroundStyle(Theme.inkSoft).frame(maxWidth: .infinity)
                        }
                    } else {
                        Text("No fans found on this Mac.").font(Theme.body).foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(fans) { f in DialView(fan: f, size: 128) }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fans listen to").font(Theme.bodyBold).foregroundStyle(Theme.ink)
                    SensorChips()
                }
            }
        }
    }
}

// MARK: right: your curve

struct CurvePanel: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Plate {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your fan curve").font(Theme.title).foregroundStyle(Theme.ink)
                    Spacer()
                    StatusPill()
                }
                if model.helperOutdated {
                    HStack {
                        Text("The helper is out of date.").font(Theme.small).foregroundStyle(Theme.ink)
                        Button("Reinstall helper…") { model.installHelper() }.buttonStyle(QuietButtonStyle())
                    }
                }
                HStack(spacing: 10) {
                    ForEach(FanPreset.all) { p in PresetTile(preset: p) }
                }
                CurveEditor()
                Text(model.curveSentence).font(Theme.body).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ease in and out").font(Theme.bodyBold).foregroundStyle(Theme.ink)
                        Text(model.config.rampSeconds <= 0 ? "Fans follow the curve instantly."
                             : "Fans take about \(Int(model.config.rampSeconds)) s to go from stopped to full speed, so they never lurch.")
                            .font(Theme.small).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Slider(value: $model.config.rampSeconds, in: 0...60, step: 1) { editing in
                        if !editing { model.pushConfig() }
                    }
                    .tint(Theme.accent).frame(width: 130)
                    .accessibilityLabel("Ramp time in seconds")
                }
                Divider().overlay(Theme.hairline)
                HStack(spacing: 14) {
                    Toggle("", isOn: Binding(get: { model.config.enabled }, set: { model.setEnabled($0) }))
                        .toggleStyle(.switch).tint(Theme.accent).labelsHidden().controlSize(.large)
                        .accessibilityLabel("Use my fan curve")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use my fan curve").font(Theme.bodyBold).foregroundStyle(Theme.ink)
                        Text("Switch off any time and macOS takes the fans back. Above 95° they always run flat out.")
                            .font(Theme.small).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

struct PresetTile: View {
    @EnvironmentObject var model: AppModel
    let preset: FanPreset
    var body: some View {
        let selected = model.activePreset == preset
        Button { model.apply(preset: preset) } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name).font(Theme.bodyBold).foregroundStyle(Theme.ink)
                Text(preset.blurb).font(Theme.caption).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? Theme.accent.opacity(0.14) : Theme.well))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.name): \(preset.blurb)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: right, before the helper exists

struct HelperPanel: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Plate(padding: 28) {
            VStack(alignment: .leading, spacing: 18) {
                Text("One quick thing first").font(Theme.title).foregroundStyle(Theme.ink)
                Text("Fan Helper needs a small helper to change fan speeds. macOS will ask for your password once.")
                    .font(Theme.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 12) {
                    reassurance("fan", "It only ever controls fan speed.")
                    reassurance("arrow.uturn.backward", "macOS can take the fans back at any moment, and does if anything goes wrong.")
                    reassurance("lock", "Nothing leaves your Mac. There's no account and no network.")
                }
                Button { model.installHelper() } label: {
                    Label("Install helper…", systemImage: "lock.open")
                }
                .buttonStyle(RubberButtonStyle())
                .padding(.top, 4)
                Spacer(minLength: 0)
                // a preview of what comes next, so the panel isn't empty and the next step is visible
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next, you'll shape your own fan curve.").font(Theme.small).foregroundStyle(Theme.inkSoft)
                    CurveEditor().opacity(0.4).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func reassurance(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.well))
            Text(text).font(Theme.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: footer

struct FooterBar: View {
    @EnvironmentObject var model: AppModel
    @Binding var confirmRemove: Bool
    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 18) {
            Button { showSettings.toggle() } label: { Label("Settings", systemImage: "gearshape") }
                .buttonStyle(QuietButtonStyle())
                .popover(isPresented: $showSettings, arrowEdge: .top) { SettingsPopover(confirmRemove: $confirmRemove) }
            Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                .toggleStyle(.switch).tint(Theme.accent).font(Theme.small).foregroundStyle(Theme.ink)
            Spacer()
            Button { model.closeMainWindow() } label: {
                Label("Close to menu bar", systemImage: "menubar.arrow.up.rectangle")
            }
            .buttonStyle(RubberButtonStyle())
            .keyboardShortcut(.defaultAction)
            .help("Closes this window. Fan Helper keeps running from the icon in the menu bar.")
        }
        .padding(.horizontal, 28).padding(.bottom, 22).padding(.top, 6)
    }
}

struct SettingsPopover: View {
    @EnvironmentObject var model: AppModel
    @Binding var confirmRemove: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings").font(Theme.title).foregroundStyle(Theme.ink)
            Toggle("Show the temperature in the menu bar", isOn: $model.showReadout)
                .toggleStyle(.switch).tint(Theme.accent).font(Theme.body)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Helper").font(Theme.bodyBold)
                Text(model.reachable ? "Running (version \(model.status?.version ?? "?"))."
                                     : "Not running. macOS may have switched it off, or it was never installed.")
                    .font(Theme.small).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Reinstall helper…") { model.installHelper() }.buttonStyle(RubberButtonStyle(compact: true))
                    Button("Remove helper…") { confirmRemove = true }.buttonStyle(QuietButtonStyle())
                }
                Text("Reinstalling asks for your password again and gives the helper its permissions back.")
                    .font(Theme.caption).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                Text("Version \(appVersion)").font(Theme.caption).foregroundStyle(Theme.inkSoft)
                Spacer()
                Button("Quit Fan Helper") { NSApplication.shared.terminate(nil) }.buttonStyle(QuietButtonStyle())
            }
        }
        .padding(18).frame(width: 340)
        .background(Theme.panel)
    }
}
