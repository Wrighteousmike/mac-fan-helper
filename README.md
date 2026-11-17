# Fan Helper

A small macOS menu-bar app that replaces the standard fan curve: pick a temperature sensor, set a **min temp** and **max temp**, and the fans ramp between their own minimum and maximum speed across that range. Works on every fan the Mac reports.

* **Setup window** (opens on first run and whenever you launch the app): live fan dial, sensor chips, three feels (Quiet / Balanced / Cool) and a curve plate with two draggable handles. *Close to menu bar* hides it.
* **Menu-bar app** (`FanHelper`): no Dock icon while only the icon is showing, optional open-at-login (silent), small popover, settings with *Reinstall helper* / *Remove helper*.
* **Root helper** (`fanhelperd`): a launchd daemon that owns the curve (so it keeps working with the app closed) and talks to the app over a local socket restricted to the logged-in user.
* **Safety:** fans go back to macOS control when the curve is switched off, the helper stops, or the sensor disappears; above 95 °C fans are forced to full speed; targets are clamped to each fan's own min–max.

## Build

    ./build.sh          # -> build/Fan Helper.app (ad-hoc signed)

Open the app, click **Install helper…** (asks for your password once). If macOS ever revokes the helper, Settings › **Reinstall helper…**.

`probe/smcprobe` is a stand-alone SMC reader/write tester (`sudo ./smcprobe set 3000`).

## Status

Apple Silicon first. Tested on an M4 Mac mini (macOS 27): fan writes through the root helper work. Intel Macs and older SMC key layouts are untested.
