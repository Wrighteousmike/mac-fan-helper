#!/bin/sh
# Run as root. Stopping the helper returns the fans to macOS automatic control.
LABEL=com.local.fanhelper.daemon
launchctl bootout system/$LABEL 2>/dev/null || true
rm -f /Library/LaunchDaemons/$LABEL.plist /Library/PrivilegedHelperTools/$LABEL /var/run/fanhelper.sock
rm -rf "/Library/Application Support/FanHelper"
exit 0
