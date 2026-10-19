# Device menus and tray hover corners

The left bar keeps the clock selection separate from the control menus hosted
in its dashboard popup. Wi-Fi, Bluetooth, and battery share a persistent
horizontal selector. Their normal flyout height is 340 pixels; the battery panel
can grow when its content needs more space.

The selector uses ordinary repeater delegates so it also loads during a live
Quickshell reload. Its selected item updates as delegates appear and tabs change.
Tray icons and their tint render in a foreground layer inside the flyout;
transparent icon pixels otherwise disappear when the hover background becomes
opaque, even with a negative background z value.

The battery details row shows the display battery's energy rate in watts and
the first laptop battery with a supported health reading. Quickshell 0.3.2 exposes
`healthPercentage` directly on the 0–100 scale. Missing readings show
"Unavailable". Back remains available in standalone island and pills panels;
the combined device menu closes through Escape, its bar trigger, or dismissal.

## Surface ledger

| Surface | Applies | Change or audit | Verification |
| --- | --- | --- | --- |
| Clock and combined device trigger | Yes | `Clock.clockSelected` excludes vertical control modes while `menuOpen` retains popup ownership | Runtime clicks, close/reopen, dashboard replacement |
| Wi-Fi, Bluetooth, battery tabs | Yes | Persistent selector and moving `ElasticHighlight`; hide redundant Back buttons | Runtime pointer, left/right keys, repeated selection, Escape, equal heights |
| Sound, microphone, media menus | Yes | Opening them also leaves the clock unselected | Runtime open and reverse toggle |
| Battery telemetry | Yes | UPower display-device rate and supported physical-battery health, above power profiles | Native rendering; hardware readings remain dependent on UPower |
| Island and pills panels | Yes | Keep their Back navigation; receive the shared battery details | Source review and wider runtime suite |
| Horizontal tray popups | Yes | Shared `SystrayMenuItem` uses the corrected explicit hover radius | Dark/light tray-row corner pixels |
| Vertical tray flyout | Yes | Same row delegate and hover helper | Native tray fixture and screenshots |
| Nested tray entries, separators, disabled entries | Yes | Same row delegate; submenu expansion and dispatch unchanged | Native tray fixture; corner rendering uses the same delegate |
| Other `HoverTint` callers | Yes | Keep inherited asymmetric corners; no other explicit-radius override found | Source audit; existing hover contrast tests |
| Tray icon hover frames | Yes | Isolate icons from hover-background batching | Transparent D-Bus icon fixture, repeated pointer transitions, rendered pixel counts |
| `OptionsMenu` and Wi-Fi/Bluetooth/audio list delegates | Yes | Audited independent backgrounds; they do not use the broken explicit-radius path | Source review |
| Configuration and compositor adapters | No | No configuration keys or compositor actions change | Source review |
| Remote connections, authentication, persistence | No | No related contract changes | Source review |

## Constraints

- Edit the tracked checkout and preserve unrelated parent-repository changes.
- Do not restart Quickshell or Niri; both hot-reload configuration.
- Run compositor tests with private displays, runtime paths, and D-Bus sessions.
  Never address the user's compositor sockets.
- Keep state changes behind the existing menu transition methods.
- Preserve foreground text rendering; do not mask an entire text-containing
  menu to repair its background corners.
- Do not commit or push without the user's instruction.

## Checks

Focused checks run with:

```sh
python -m unittest tests.e2e.test_button_hover_runtime tests.e2e.test_bar_text_runtime
python tests/run_tests.py --all
```

The native tray and flyout runner is documented in
[`tests/runtime/README.md`](../tests/runtime/README.md). The final full suite
reports 335 checks with zero failures; one GPU lyrics case is skipped without
an X display. All 21 native Niri scenarios pass, with no QML binding or type
warnings. A separate native capture confirms all three final device panels.
The tray hover pixel check fails on the original revision at the second icon's
first hover frame and passes after layer isolation. The running desktop also
accepts the selector and tray edits through hot reload without a restart.

Hardware radio changes,
power-profile writes, physical multi-monitor output, and battery charge/discharge
transitions are outside this verification pass.
