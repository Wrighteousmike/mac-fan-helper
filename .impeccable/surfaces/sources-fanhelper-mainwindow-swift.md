---
version: 1
slug: "sources-fanhelper-mainwindow-swift"
primary_target: "Sources/FanHelper/MainWindow.swift"
related_targets: []
---

# Surface brief: setup window + menu-bar popover

Mode: Operate (task: choose a sensor, shape a fan curve, switch it on, then leave).

Audience/job: everyday Mac owner, non-technical, first run of a free downloadable app. Needs to install the helper, pick a feel, adjust the ramp, switch on, close to the menu bar.

## Direction contract

THESIS: A calm appliance, not an engineering tool: setup is one soft panel pair where the curve is drawn and dragged directly. Refuses the dense utility look (four sliders, tiny gauges, grey chrome).
OWN-WORLD: Warm putty ground, lighter putty panels with large soft radii, warm charcoal ink, rubber-button orange used only on things you can press (primary button, selected tile, drag handles, switch). Rounded system face, tabular numerals. Elevation by one soft shadow, never border plus shadow. Dark mode: warm charcoal ground, same orange.
STORY: "Your Mac, right now" on the left (live dial, temperatures); "Your fan curve" on the right (feel presets, drag the two orange dots, switch on). Safety is stated plainly: macOS can always take the fans back.
FIRST VIEWPORT: ~940x680 window, hidden title bar. Left panel 330pt: live fan dial (ticks, pointer, big rpm) and sensor chips. Right panel: status pill, three feel tiles, curve editor with two orange handles, one-sentence plain-English summary, the switch. Footer: Settings, Open at login, orange "Close to menu bar" button at bottom right. If the helper is missing, the right panel becomes "One quick thing first" with the orange Install helper button.
FORM: assigned candidate 4 of 7, the soft domestic-appliance manual (putty body, one signal colour, printed dial); seed:50e88fc8a163dbed. Signature move: the printed dial and ruler-ticked curve editor with draggable rubber-orange handles.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
