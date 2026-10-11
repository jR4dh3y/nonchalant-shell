# Wallpaper colors

Select **Wallpaper** in the wallpaper picker's scheme menu, or run
`nonchalant run wallpaper-colors`. This clears a static preset and regenerates
the palette from the current global wallpaper. It is the default for new
wallpaper state; existing scheme selections are preserved.

The extractor samples visible pixels, quantizes them into 64 color clusters,
and ranks clusters using population and perceptual chroma. It selects up to six
hues separated by at least 30 degrees in OKLab, then fills available slots with
distinct shades sampled from the image. Primary, secondary, and tertiary
use the first three samples, with lightness adjusted for readable text.
A grayscale or single-hue image keeps a limited accent palette instead of
inventing unrelated accent colors.

Every accent comes from the wallpaper, including status and terminal colors.
Legacy names such as `red`, `green`, and `blue` identify palette slots, not
fixed hue families. Missing slots reuse sampled colors instead of inventing
unrelated colors. A blue wallpaper can therefore make all controls blue-toned;
a warm wallpaper changes the same controls to its own sampled colors.

## Element color assignments

Color assignment follows Impasto's component roles, rather than giving each
module an unrelated accent. Palette extraction and the selected preset are
unchanged by this assignment policy.

| Element | Role |
| --- | --- |
| Resting clock, normal bar icons, headphone badge, volume/brightness rings | Neutral foreground. Muted/empty controls use the subdued foreground. |
| Island capsule and expanded outer shell | Palette background; inner cards use the slightly lighter themed surface. |
| Enabled toggles, selected devices, selected dates, active media controls, focused actions | Primary accent, with its matching `overPrimary` foreground. Wi-Fi and Bluetooth do not get separate selection colors. |
| Ordinary titles, values, captions | Neutral foreground or subdued foreground. Calendar headings and weather readings are not selections. |
| Sound/microphone dashboard gauges | Neutral indicators. Their editable sliders and selected devices use primary. Mute is subdued, not an error. |
| Battery charge/progress, low battery, destructive actions | Existing status/error roles. Charging is green; the resting healthy battery icon is neutral. |
| CPU / disk usage | Primary normally, yellow at warning thresholds, red at critical thresholds. CPU uses 70/90 percent; disk uses 75/90 percent. |
| Memory, GPU, network metrics | Blue, yellow, green data roles, consistent between island and classic resource panels. GPU vendor branding does not determine the data color. |
| Disabled controls and meter tracks | Existing neutral surface/outline roles. |
| Native tray/application icons | Original artwork and existing tint preference. |

`Colors.accentRole()` centralizes selection assignment, and
`Colors.metricRole()` centralizes data and utilization thresholds. Nested device
and app-stream delegates, toggles, calendar cells, media controls and OSDs share
those rules. All role colors continue to come from the chosen palette, including
the wallpaper-generated palette. No fixed semantic colors were introduced.

Backgrounds have a small tint from the main image color. Surfaces have distinct
lightness levels. Accent foregrounds and container foregrounds are selected
for contrast in both modes. OLED overrides remain in `Colors.qml`.

Material schemes still use Matugen with Wallust as a fallback. Static presets
keep their existing palettes. Pillow is required for Wallpaper extraction and
is included in the Arch, Fedora, and Nix dependency lists.

All generated palettes are validated and atomically replace only the requested
output file. A failed extraction leaves the previous file intact. Temporary
Material templates prevent stale cache files from being mistaken for success.
The global wallpaper manager owns generation; secondary monitor instances do
not compete to publish a global palette.

## Coverage ledger

| Path | Applicability and verification |
| --- | --- |
| Wallpaper picker and scheme selector | Applies. Wallpaper option uses the existing scheme transition and preset clearing. |
| Startup and persisted selection | Applies. New state defaults to Wallpaper; saved Material schemes and presets remain selected. |
| Next/previous, indexed selection, per-screen selection | Applies. All reach the shared generator; the established global/primary wallpaper drives one palette. |
| Dark/light switches | Applies. Both reach the shared generator and have contrast tests. |
| Images, GIFs, video | Applies. Images and GIF first frames reach Pillow. Video uses the existing thumbnail path. GIF equivalence is tested; live video selection is not tested. |
| Failure and canceled generation | Applies. Unique temporary output, validation, atomic rename, EXIT cleanup. Invalid-image and stale-output regression tests pass. |
| Shell widgets, island/classic bars, metrics, notifications, launcher, lockscreen | Applies. Existing `Colors` roles are unchanged; complete output matches the adapter contract. Island metrics now use the classic panel's CPU/red, RAM/cyan, vendor GPU, disk/yellow, network/cyan roles. The island panel is checked live. Other interactions are not all visually tested. |
| GTK, Qt, Kitty, NvChad, Discord | Applies. Consume the same watched palette with no contract change. App rendering is not individually tested. |
| Pywal text, JSON, shell exports | Applies. One ANSI list supplies all formats, preserving terminal role mapping. |
| Static presets and OLED | Applies. Existing preset branch and OLED adapter overrides are retained. |
| Remote providers, relay, mobile clients | Does not apply. Extraction is a local process for this Wayland shell. |

## Assignment coverage ledger

| Path | Applicability |
| --- | --- |
| Collapsed island and classic bar, clock, brightness, volume, microphone, headphone format | Applies. Neutral information, subdued mute states, primary focus. |
| Expanded dashboard, sound/mic gauges, weather and date headings | Applies. Neutral information; enabled controls retain primary selection. |
| Sound/mic selected devices and nested app-stream controls | Applies. Shared primary selection and subdued mute; no module-specific selection hues. |
| Wi-Fi/Bluetooth enabled switches, scan states, network/device delegates | Applies. Shared primary with matching foreground, including switch knobs. |
| Calendar cells, wallpaper selectors, media play/shuffle/repeat/seek | Applies. Existing shared role callers now select primary. Native artwork is preserved. |
| Battery profiles, power actions, notification urgency | Applies. Selection uses primary; status/error still uses existing palette roles. |
| CPU, memory, GPU, disk and network in both resource panels | Applies. Shared data roles and CPU/disk threshold policy. |
| Island/classic OSD | Applies. Primary progress and subdued mute. |
| Presets, wallpaper generation, dark/light, app exports | Palette contract unchanged. Existing extraction/contrast tests remain. |
| Other clients/providers | Does not apply. This is local QML element assignment. |

## Completion and constraints

Exit condition: a complete image-derived palette is selectable, all consumers
receive the existing role contract, failure preserves the old palette, and
focused extraction tests plus the shell's relevant checks pass.

Hard constraints followed: preserve unrelated changes; change tracked sources;
do not restart Quickshell or Niri; do not run `rice reload`; do not commit or
push; use typed QML properties and null-safe access; do not add configuration
keys without defaults; do not introduce compositor shims; use structured
process arguments; use safe temporary paths and structured errors; do not
weaken existing tests; retain state transition methods; verify process/runtime
behavior separately from syntax checks. No new persistent key was added.

Run focused checks with:

```bash
python3 -m unittest discover -s tests/unit -p test_wallpaper_palette.py -v
```

Previous extraction validation on 2026-10-08: all 208 suite checks and syntax checks on all 49 modified
QML files passed. Extraction was exercised on 11 real wallpapers in both
modes, with minimum accent text contrast of 4.56. Switching between the blue
`b1.jpg` and warm cat wallpaper through live shell IPC changed every accent
slot; generated JSON matched the extractor. The original wallpaper was restored.
The active cat wallpaper was selected through shell IPC; palette
readback matched the extractor, all three Pywal formats matched, and the live
island resource panel showed separate CPU, RAM, GPU, disk, and network colors.
The live full dashboard also showed distinct Wi-Fi, Bluetooth, microphone,
battery, calendar, and resource controls. Runtime
logs confirmed GTK, Qt, Kitty, NvChad, Discord, and Pywal generation. No manual
shell restart, commit, or push was performed. Multiple physical monitors,
live video selection, classic bar layout interaction, and each themed
application's rendering remain untested.

## Element-assignment validation

On 2026-10-08, the revised assignments passed all 209 suite checks. Focused
checks execute the actual selection and metric-role functions, including
CPU/disk threshold boundaries and foreground contrast in both palette modes.
Syntax checks passed on all 19 edited QML files. The running shell hot-reloaded
successfully; the dashboard and resource panel were inspected live, with no
new color-binding errors after the final reload. The selected palette and
wallpaper extractor were preserved. Classic-layout interactions, live OSD
interaction, multiple monitors, and warning-state transitions were not tested
visually. No manual restart, commit, or push was performed.
