# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS desktop (native SwiftUI window plus menu-bar extra; not web, iOS or Android)

## Stack

SwiftUI / AppKit via SwiftPM, no external UI dependencies, ad-hoc signed `.app` built by `build.sh`. A root launchd helper (`fanhelperd`) does the fan control; the app window and menu-bar popover are clients of it.

## Users

An everyday Mac owner who is not technical. Their Mac runs loud or hot, they want it quieter or cooler, and they want to set it up once without learning what an SMC, rpm curve or sensor key is. Power users may exist but the simple path leads. Anyone can download it: it is a free download distributed like ChartWright.

## Product Purpose

Replace the standard macOS fan curve. The person picks a temperature sensor and a minimum and maximum temperature; the fans ramp between their own minimum and maximum speed across that range, for every fan the Mac reports. Success: someone who has never opened a fan utility sets up a curve in a couple of minutes, trusts it, closes the window, and the menu-bar icon quietly keeps working from then on.

## Positioning

A calm, first-run-friendly fan curve tool with a proper setup window (not a dense engineering utility), with safety stated in plain words: macOS can always take the fans back.

## Operating Context

- First launch opens a large setup window. After setup the person presses the exit/close button and the menu-bar icon takes over; the big window only returns on demand ("Open Fan Helper" from the icon) or on first run.
- The app starts at login quietly as the menu-bar icon, with no Dock icon while it is only in the menu bar.
- A password-protected root helper must be installed once; macOS can revoke it, so a "Reinstall helper" action lives in Settings.
- The curve lives in the helper, so it keeps working when the app is closed.

## Capabilities and Constraints

- Reads every fan (actual, min, max rpm) and temperature groups: CPU, GPU, SSD, Memory, hottest sensor.
- Curve = sensor, min temp, max temp, fan power at min, fan power at max (as % of each fan's own range).
- Safety: fans return to macOS when the curve is off, the helper stops or the sensor vanishes; above 95 °C fans are forced to full speed.
- Whether the M4 / macOS 27 accepts fan writes with root has not been proven on real hardware yet (undecided).
- Apple Silicon first; Intel and older SMC layouts untested.

## Brand Commitments

Name: Fan Helper (working name, may change). No existing logo or palette. The user wants it soft, friendly and "not generic app design".

## Evidence on Hand

No screenshots, testimonials or benchmarks. Live sensor and fan data come from the real Mac; anything else shown in the UI must be real readings, never invented figures.

## Product Principles

1. Setup first: the big window teaches the idea in plain language and the app is usable in one pass.
2. Never frighten: safety and "macOS can always take over" are visible, calm and true.
3. Show the real thing: live rpm, live temperature, the actual curve, with no decorative fake data.
4. Hand off gracefully: after setup the menu-bar icon is the product; the window is a room you can leave.
