#!/bin/bash
# Builds "Fan Helper.app" into ./build (menu-bar app + bundled root helper), ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")"
# Universal (Apple Silicon + Intel): build each architecture, then join them with lipo.
# (`swift build --arch a --arch b` needs full Xcode; this works with just the Command Line Tools.)
UNI=build/universal
rm -rf "$UNI"; mkdir -p "$UNI"
for arch in arm64 x86_64; do
  swift build -c release --triple "$arch-apple-macosx13.0" --scratch-path ".build-$arch"
  cp ".build-$arch/$arch-apple-macosx/release/FanHelper" "$UNI/FanHelper-$arch"
  cp ".build-$arch/$arch-apple-macosx/release/fanhelperd" "$UNI/fanhelperd-$arch"
done
lipo -create "$UNI"/FanHelper-arm64 "$UNI"/FanHelper-x86_64 -output "$UNI/FanHelper"
lipo -create "$UNI"/fanhelperd-arm64 "$UNI"/fanhelperd-x86_64 -output "$UNI/fanhelperd"
BIN="$UNI"
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
