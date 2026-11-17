import SwiftUI
import AppKit
import FanShared

@main
struct FanHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // No scenes of its own: the menu-bar item and the big window are owned by AppKit (see AppDelegate).
    var body: some Scene { Settings { EmptyView() } }
}

/// The menu-bar item: fan icon plus, beside it, the chosen sensor's temperature over the fan rpm.
/// Owned directly through NSStatusItem because SwiftUI's MenuBarExtra label can't draw a two-line readout.
@MainActor
final class StatusBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let model: AppModel
    private var timer: Timer?

    init(model: AppModel) {
        self.model = model
        super.init()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView().environmentObject(model))
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.setAccessibilityLabel("Fan Helper")
        redraw()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.redraw() }
        }
    }

    @objc private func toggle() {
        guard let button = item.button else { return }
        if popover.isShown { popover.performClose(nil); return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func closePopover() { popover.performClose(nil) }

    private func redraw() {
        guard let button = item.button else { return }
        let fan = NSImage(systemSymbolName: "fan", accessibilityDescription: "Fan Helper")?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
        var top = "", bottom = ""
        if model.showReadout {
            top = model.currentTemp.map { "\(Int($0.rounded()))°" } ?? "–"
            let f = model.fans
            bottom = f.isEmpty ? "– rpm" : "\(Int((f.map(\.actual).reduce(0, +) / Double(f.count)).rounded())) rpm"
        }
        let para = NSMutableParagraphStyle(); para.alignment = .left
        func attr(_ t: String, _ size: CGFloat, _ w: NSFont.Weight) -> NSAttributedString {
            NSAttributedString(string: t, attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: w),
                                                      .foregroundColor: NSColor.black, .paragraphStyle: para])
        }
        let l1 = attr(top, 10.5, .semibold), l2 = attr(bottom, 9, .regular)
        let iconW = ceil(fan?.size.width ?? 16)
        let textW = model.showReadout ? ceil(max(l1.size().width, l2.size().width)) + 1 : 0
        let gap: CGFloat = model.showReadout ? 4 : 0
        let size = NSSize(width: iconW + gap + textW, height: 22)
        let img = NSImage(size: size, flipped: false) { _ in
            if let fan = fan { fan.draw(in: NSRect(x: 0, y: (22 - fan.size.height) / 2, width: fan.size.width, height: fan.size.height)) }
            if self.model.showReadout {
                l1.draw(in: NSRect(x: iconW + gap, y: 10.5, width: textW + 4, height: 12))
                l2.draw(in: NSRect(x: iconW + gap, y: 0.5, width: textW + 4, height: 11))
            }
            return true
        }
        img.isTemplate = true
        button.image = img
        button.imagePosition = .imageOnly
    }
}

// MARK: - the big window (AppKit-owned so it can be shown, hidden and re-shown at will)

final class MainWindowController: NSWindowController, NSWindowDelegate {
    init(model: AppModel) {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 700),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.contentMinSize = NSSize(width: 900, height: 650)
        win.contentView = NSHostingView(rootView: MainWindowView().environmentObject(model))
        win.center()
        super.init(window: win)
        win.delegate = self
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.setActivationPolicy(.regular)               // a Dock icon only while this window is open
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)             // back to menu-bar only
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MainWindowController?
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel.shared
        // one copy only; a second launch just brings the first one's window forward
        let me = ProcessInfo.processInfo.processIdentifier
        if let id = Bundle.main.bundleIdentifier,
           let other = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != me }) {
            other.activate()
            NSApp.terminate(nil)
            return
        }
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            Snapshot.run(into: CommandLine.arguments[i + 1])       // design-review aid: renders the screens to PNGs and quits
            return
        }
        statusBar = StatusBarController(model: model)
        model.openMainWindow = { [weak self] in self?.statusBar?.closePopover(); self?.showMainWindow() }
        model.closeMainWindow = { [weak self] in self?.controller?.window?.close() }

        let firstRun = !UserDefaults.standard.bool(forKey: "didShowWelcome")
        UserDefaults.standard.set(true, forKey: "didShowWelcome")
        // Signing in launches silently into the menu bar; every other launch (and the first ever) opens the window.
        if firstRun || !Self.launchedInBackground() { showMainWindow() }
    }

    /// Reopening from Finder / Dock / Spotlight while we're already running brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func showMainWindow() {
        if controller == nil { controller = MainWindowController(model: AppModel.shared) }
        controller?.show()
    }

    private static func launchedInBackground() -> Bool {
        if CommandLine.arguments.contains("--background") { return true }
        let ev = NSAppleEventManager.shared().currentAppleEvent
        return ev?.eventID == AEEventID(kAEOpenApplication)
            && ev?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }
}

// MARK: - design-review snapshots (`FanHelper --snapshot <dir> [--dark] [--nohelper]`)

@MainActor
enum Snapshot {
    static func run(into dir: String) {
        let dark = CommandLine.arguments.contains("--dark")
        let noHelper = CommandLine.arguments.contains("--nohelper")
        let model = AppModel.shared
        if noHelper { model.status = nil; model.reachable = false }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let tag = (dark ? "dark" : "light") + (noHelper ? "-nohelper" : "")
        func shot<V: View>(_ v: V, size: NSSize, name: String) {
            let host = NSHostingView(rootView: v.environmentObject(model))
            host.frame = NSRect(origin: .zero, size: size)
            let win = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
            win.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            win.contentView = host
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name)-\(tag).png"))
        }
        // let the first live readings arrive
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if noHelper { model.status = nil; model.reachable = false }
            shot(MainWindowView(), size: NSSize(width: 960, height: 700), name: "window")
            shot(PopoverView(), size: NSSize(width: 304, height: 260), name: "popover")
            NSApp.terminate(nil)
        }
    }
}
