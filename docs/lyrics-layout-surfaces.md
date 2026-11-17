# Wrapped lyric layout

Detail lyrics request enough height for the current wrapped cue, with the existing
140-pixel minimum. Hosts still constrain their actual height. A cue that fits is
centered; a cue taller than its viewport starts at the top and permits scrolling.
Compact lyrics keep their 22-pixel height and horizontal word following.
Square media panels give their remaining vertical space to lyrics rather than an
empty spacer. Context cues fade out before crossing the viewport boundary, so
previous and next lyrics do not show sliced glyphs.

| Surface | Applies | Source | Check | State |
|---|---|---|---|---|
| Vertical media popup | Yes | `VerticalControlMenu.qml`, `IslandMediaCenterPanel.qml` | Six-line cue and three wrapped context cues fit; taller cues scroll; controls stay inside panel | Runtime and private OpenGL rendering regression tests |
| Island and Pills media panels | Yes | Shared `IslandMediaCenterPanel.qml` | Shared height calculation; bounded detail viewport scrolls | Shared component covered; full compositor transitions not exercised |
| Dashboard lyric pane and full player | Yes | `VerticalDashboard.qml`, `FullPlayer.qml` | Fixed-size hosts retain their bounds; oversized cues scroll | Bounded component covered |
| Compact card, lockscreen and bar lyrics | Yes | Shared `LyricsView.qml` compact mode | Height remains 22; playback, seeking and word following | Layout and existing media runtime suites |
| Reverse states | Yes | Shared `LyricsView.qml` | Short cues return to minimum height and centering; overflowing context disappears before clipping; plain lyrics remain scrollable; closing releases subscriptions | Runtime regression test |
| Cider and LRCLIB | Yes | Both supply the same lyric model | Existing provider runtime and lookup suites | No provider contract changes |
| Remote/offline modes | No | No transport or lookup changes | Layout consumes the existing model | Not applicable |
| Configuration | No | No new settings | Existing theme font and animation settings | Not applicable |

Run `python -m unittest tests.e2e.test_lyrics_layout_runtime -v`. It starts a
private D-Bus session, MPRIS player and offscreen Quickshell process with temporary
HOME/XDG paths. It checks sizing, real pointer dragging, reverse states and binding
warnings. When Weston is installed, it also renders on a private headless display
using OpenGL through Mesa llvmpipe and checks that the active lyric paints visible
pixels. Set `NONCHALANT_LYRICS_SNAPSHOTS` to an existing directory to save its
rendered context cases. It does not prove physical-display rendering or live music
playback.
