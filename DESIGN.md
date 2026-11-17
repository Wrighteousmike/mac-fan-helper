# Design: Fan Helper

Direction: **soft appliance manual** (Operate mode). Source: a well-made 1960s domestic appliance, a putty body with printed dial markings and one signal-coloured rubber button. The world lends palette, type, density and one signature move (the printed dial and the drag-to-shape curve plate); navigation and controls stay standard macOS (switch, buttons, popover).

## Colour (light / dark), `Sources/FanHelper/Theme.swift`
- ground `#E6E1D6` / `#1E1C19` — the body
- panel `#F3EFE7` / `#2A2724` — raised plates
- well `#E9E4DA` / `#221F1C` — recessed areas (dial face, curve plate, chips, tiles)
- ink `#2B2824` / `#EDE7DC`; inkSoft `#6B6358` / `#A79E90` (≥4.5:1 on panel and well)
- hairline `#D6D0C3` / `#3A3631`
- accent (rubber orange) `#CC4A18` / `#F07A45`, with onAccent `#FFFFFF` / `#1E1C19`. **Only on things you can press or drag**: primary button, selected tile or chip, curve handles, switches.
- alert `#B3261E` / `#FF8A80`, used only for real errors.

## Type
System rounded (SF Pro Rounded), tabular numerals for live values. Fixed scale: 11 / 12 / 14 / 22, dial numerals scale with the dial.

## Shape and depth
Plates radius 18, tiles/chips/inputs 12, buttons 14 (compact 10). Elevation is a single soft shadow on plates (none in dark mode); never a border plus a shadow.

## Signature
- **Dial**: 41 printed ticks over a 270° sweep, a soft band marking the fan's own min–max range, an ink pointer that glides to the live rpm (spring, off with Reduce Motion).
- **Curve plate**: ruled grid (10° columns), the curve as a rounded ink line, two orange handles (drag; also adjustable by VoiceOver), a dashed "now" line with a dot riding on the curve.

## Behaviour
Big window on first run and on every manual launch; login launches stay silent. "Close to menu bar" closes the window, the Dock icon goes away, the menu-bar icon (optional temperature readout) keeps working. Reopening the app from Finder brings the window back.

## Review status
Built and checked in light and dark, with and without the helper installed, plus the menu-bar popover (rendered via `FanHelper --snapshot <dir> [--dark] [--nohelper]`). The automated finish-reviewer pass of the design skill was not run (native macOS is outside the web detector).
