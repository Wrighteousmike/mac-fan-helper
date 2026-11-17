#!/bin/bash
# Builds "Fan Helper.app" into ./build (menu-bar app + bundled root helper), ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
BIN=$(swift build -c release --show-bin-path)
APP="build/Fan Helper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/FanHelper" "$APP/Contents/MacOS/FanHelper"
cp "$BIN/fanhelperd" "$APP/Contents/Resources/fanhelperd"
cp Resources/install_helper.sh Resources/uninstall_helper.sh "$APP/Contents/Resources/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns" || true
codesign --force --sign - "$APP/Contents/Resources/fanhelperd"
codesign --force --sign - "$APP"
echo "built: $APP"
