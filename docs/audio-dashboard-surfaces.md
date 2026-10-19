# Audio tabs and dashboard return

The left bar's volume and microphone halves open one popup with a persistent
horizontal selector. Switching tabs keeps the selector and popup ownership alive.
The track uses the same themed background and sliding highlight as the combined
device menu. The combined audio popup has no Back button. Standalone audio panels
keep their original titles and Back navigation.

The vertical dashboard now morphs toward the clock's full bounds. Previously,
left-edge reveals only changed width and retained the dashboard's entire height.
`MorphSurface.originItem` opts into a position and size morph, sampled at each
open or close. The clock's layout item supplies its resting bounds independently
of its press feedback. The dashboard's closing fade lasts through the return.
Content stays at its resting size and position, preserving native text rendering.

| Surface | Change or preserved contract | Verification |
| --- | --- | --- |
| Left bar volume/microphone halves | Keep direct selection, separate wheel volume, right-click mute, and selected-half state | Component pointer and audio fixtures |
| Shared audio popup | Persistent track, sliding selection, accessible tabs, arrow keys, Escape, no Back | Component and native Niri pointer/keyboard interactions |
| Wi-Fi/Bluetooth/battery selector | Same selector implementation and existing behavior | Existing component and native checks |
| Island/pills audio panels | Default title and Back navigation stay available | Component Back clicks in both layouts and wider runtime suite |
| Dashboard return into clock | Collapse width, height, and position together; reverse a partial close | Component geometry assertions and native Niri captures |
| Notifications/wallpapers/stats/weather | Same close path; animations disabled closes immediately | Component checks for all four sections |
| Horizontal dashboard, launcher, OSD, power menu, other bar popups | No origin item, so existing reveal geometry and fade timings remain | Source audit and wider runtime suite |
| Audio service and physical devices | No routing, volume policy, or persistence changes | Mock audio boundary; physical hardware changes not exercised |
| Multi-monitor output | Source mapping stays inside each clock's panel | Single-output runtime only |

Run the component checks with `python -m unittest tests.e2e.test_bar_text_runtime`
and the wider suite with `python tests/run_tests.py --all`. Native checks use the
private compositor runner documented in `tests/runtime/README.md`. Never restart
the user's shell or address their compositor sockets for tests.
