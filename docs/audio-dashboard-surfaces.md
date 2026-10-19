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
| Battery power profiles | Shared sliding track and selected state use the shell service, with qualified UPower imports | Component clicks across left/island/pills plus private CLI readback |
| Low-battery notification action | The same import collision no longer shadows the shell power-profile service | Real notification action dispatch to private CLI |
| Audio service and physical devices | No routing, volume policy, or persistence changes | Mock audio boundary; physical hardware changes not exercised |
| Multi-monitor output | Source mapping stays inside each clock's panel | Single-output runtime only |

Run the component checks with `python -m unittest tests.e2e.test_bar_text_runtime`
and the wider suite with `python tests/run_tests.py --all`. Native checks use the
private compositor runner documented in `tests/runtime/README.md`. Never restart
the user's shell or address their compositor sockets for tests.

The power-profile regression test exercises all three profiles through the real
service and a private `powerprofilesctl` executable, including readback and the
critical-battery notification action. Physical power-profile writes are not
performed. The tray screenshot check also converts logical bounds to physical
pixels; its crop is checked at output scales 1, 1.2, and 2. Native Hyprland
fractional-scale execution is unavailable on this host.

Power-profile labels keep a stable medium weight and centered icon/text groups.
Hover uses a light wash, keyboard focus uses an outline, and the selected pill
remains the strongest state. Tooltips appear only when a label is truncated.
Native captures cover hover, focus, selection, and enlarged text.
