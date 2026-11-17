// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FanHelper",
    platforms: [.macOS(.v13)],
    targets: [
        // SMC access + the wire protocol shared by the app and the root helper
        .target(name: "FanShared"),
        // the privileged background helper (runs as root via launchd, owns the fan curve)
        .executableTarget(name: "fanhelperd", dependencies: ["FanShared"]),
        // the menu-bar app (no Dock icon)
        .executableTarget(name: "FanHelper", dependencies: ["FanShared"]),
    ]
)
