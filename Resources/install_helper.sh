#!/bin/sh
# Run as root (the app asks for the admin password). $1 = path to the fanhelperd binary inside the app.
set -e
SRC="$1"
LABEL=com.local.fanhelper.daemon
DEST=/Library/PrivilegedHelperTools/$LABEL
PLIST=/Library/LaunchDaemons/$LABEL.plist

[ -x "$SRC" ] || { echo "helper binary not found: $SRC" >&2; exit 1; }

# stopping the old helper makes it hand the fans back to macOS first
launchctl bootout system/$LABEL 2>/dev/null || true

mkdir -p /Library/PrivilegedHelperTools "/Library/Application Support/FanHelper"
cp "$SRC" "$DEST"
chown root:wheel "$DEST"
chmod 755 "$DEST"
xattr -cr "$DEST" 2>/dev/null || true

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$DEST</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>/var/log/fanhelper.log</string>
  <key>StandardOutPath</key><string>/var/log/fanhelper.log</string>
</dict>
</plist>
PL
chown root:wheel "$PLIST"
chmod 644 "$PLIST"

launchctl bootstrap system "$PLIST"
launchctl kickstart -k system/$LABEL
