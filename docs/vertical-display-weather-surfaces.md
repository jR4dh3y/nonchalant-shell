# Vertical display and Weather surfaces

| Surface | Behavior | Verification |
| --- | --- | --- |
| Brightness dial, Night Light off | One sun dial; click enables Night Light; scroll changes this screen's brightness | Bar runtime with hardware commands replaced |
| Display dial, Night Light on | Upper half adjusts brightness; lower half adjusts temperature; either half toggles Night Light | Pointer and keyboard interaction tests |
| Display transitions | Ring geometry, icons, and hit areas morph together; the lower half retracts before disappearing | Intermediate progress and settled geometry assertions |
| Display highlights | Hover and press are transient; temperature and keyboard focus do not select a filled half | Pointer exit after keyboard focus |
| Brightness monitor policy | Unsynced changes target this screen; synced changes reach ready monitors | Two private monitor fixtures, including an unavailable monitor |
| Night Light endpoints | Temperature clamps at both ends; enabling from neutral requests a warmer value; re-enabling preserves the saved value | Private gamma command recorder |
| Dashboard Weather | Fourth tab after System Monitor; shared selection highlight; Ctrl+Tab and Ctrl+Shift+Tab cycle all four sections | Mouse, keyboard, dismissal, and `weather` command tests |
| Vertical Weather presentation | Animated sky fills spare height; forecast stays below it; island navigation header is hidden | Layout assertions and native Wayland day/night captures |
| Weather animation | Celestial glow breathes while visible; sun position updates while the popup is open | Glow progress assertion; popup visibility included in the service timer condition |
| Dashboard media and lyrics | Absent or stopped media hides the row and stops lyrics demand; playing and paused tracks retain the row | Private MPRIS player plus no-player settings fixture |
| Power menu and OSD | Open from the screen edge and settle at their existing gap; close toward the edge | Disposable Niri session, including reversal and disabled animation |

The horizontal brightness slider uses the same monitor policy. Horizontal
dashboard Night Light controls and island Weather headers remain available.
The launcher stays attached to its bar edge; it does not use the independent
bottom offset shared by the power menu and OSD.

The existing weather effects for clouds, rain, snow, fog, and lightning are
retained. Day/night rendering and celestial animation were checked; individual
weather effects and physical GPU behavior were not checked. Brightness and
gamma hardware writes were simulated. No desktop compositor was restarted.

Run the coverage with:

```bash
python tests/run_tests.py --all
```

The runner includes the private MPRIS, bar, hover, and bottom-flyout tests.
