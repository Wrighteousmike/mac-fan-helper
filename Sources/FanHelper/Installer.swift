import Foundation
import ServiceManagement
import FanShared

/// Installs / removes the root helper (asks for the admin password via the standard macOS prompt)
/// and registers the app itself as a login item.
enum Installer {
    private static func resource(_ name: String) -> String? { Bundle.main.path(forResource: name, ofType: nil) }

    private static func shQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    /// Runs a shell command as root through the system admin prompt. Returns (ok, message).
    private static func runAsAdmin(_ command: String) -> (Bool, String) {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
        let pipe = Pipe()
        p.standardError = pipe
        p.standardOutput = pipe
        do { try p.run() } catch { return (false, error.localizedDescription) }
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if p.terminationStatus == 0 { return (true, "") }
        if out.contains("-128") || out.lowercased().contains("user canceled") { return (false, "Cancelled") }
        return (false, out.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func installHelper() -> (Bool, String) {
        guard let script = resource("install_helper.sh"), let helper = resource("fanhelperd") else {
            return (false, "The app bundle is missing the helper files.")
        }
        return runAsAdmin("/bin/sh \(shQuote(script)) \(shQuote(helper))")
    }

    static func removeHelper() -> (Bool, String) {
        guard let script = resource("uninstall_helper.sh") else { return (false, "The app bundle is missing the uninstaller.") }
        return runAsAdmin("/bin/sh \(shQuote(script))")
    }

    // MARK: login item
    private static var agentPath: String {
        NSHomeDirectory() + "/Library/LaunchAgents/com.local.fanhelper.app.plist"
    }

    static var loginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled || FileManager.default.fileExists(atPath: agentPath)
    }

    /// Prefers the system's own login-item API; falls back to a LaunchAgent if macOS refuses (e.g. unsigned build).
    static func setLoginItem(_ on: Bool) -> String? {
        if on {
            do { try SMAppService.mainApp.register(); try? FileManager.default.removeItem(atPath: agentPath); return nil }
            catch {
                let plist: [String: Any] = [
                    "Label": "com.local.fanhelper.app",
                    "ProgramArguments": ["/usr/bin/open", "-g", Bundle.main.bundlePath, "--args", "--background"],
                    "RunAtLoad": true,
                ]
                do {
                    try FileManager.default.createDirectory(atPath: (agentPath as NSString).deletingLastPathComponent,
                                                            withIntermediateDirectories: true)
                    (plist as NSDictionary).write(toFile: agentPath, atomically: true)
                    return nil
                } catch { return "Could not enable start at login: \(error.localizedDescription)" }
            }
        } else {
            try? SMAppService.mainApp.unregister()
            try? FileManager.default.removeItem(atPath: agentPath)
            return nil
        }
    }
}
