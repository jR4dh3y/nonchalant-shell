# Left dock surface motion

Every bar-attached surface on the left dock is a `MorphSurface`, either inside
the bar panel (dashboard and control menus, run menu) or inside a `BarPopup`
window (tray flyout, clock time tools). Motion rules live in those two shared
primitives; hosts only describe where the body rests.

## Rules

- **Rest position, not current position.** A host gives `restY` for the
  content it wants (dashboard: bottom on the 8 px screen gap; media: centred on
  the media pill; popups: centred on their control, clamped to the gap). The
  body's position and size follow on one curve and retarget together, so the
  anchored edge never moves and the other edge eases monotonically.
- **Stable popup windows.** A left-dock `BarPopup` window spans the dock's full
  height and only grows while it is up (`reservedWidth/Height` pre-size the
  tray for its app menu). Navigation never resizes or re-anchors the window
  under an animating body, and a shrinking body is never clipped.
- **Rounded from the first visible frame.** Dock surfaces mask their content to
  the body's rounded corners while the body moves (`maskContent`, default on
  for `fromLeft`). At rest the mask is off and text renders directly in the
  window scene graph. The frame's inner pane is concentric on every frame.
- **Dashboard switches crossfade in place.** Opening springs (OutBack);
  closing is monotonic (InCubic). Switching between the dashboard and a
  control menu freezes the outgoing page into a texture (one frame of
  latency), pins it where it rested under the rounded mask, and fades it out
  while the incoming page fades in at its own rest position and the frame
  morphs and its chrome fades. A contracting edge therefore conceals the
  outgoing panel exactly as a growing edge reveals the incoming one, so
  dashboard → menu mirrors menu → dashboard. Content never slides with an
  edge and is never scaled. Device and audio tabs switch immediately. The
  tray retains its outgoing and incoming fades.

## Surface ledger

| Surface | Source | Entry points | Defect before | Fix | Runtime check |
| --- | --- | --- | --- | --- | --- |
| Dashboard open/close | `Clock.qml`, `MorphSurface.qml` | Clock click, `notifications`/`stats`/`weather` IPC | Frameless body clipped the cards with a square rectangle while growing out of the clock | Rounded content mask while moving | Frames frozen mid-open: corners show only the empty screen |
| Dashboard ↔ Wi-Fi/Bluetooth/battery, sound/mic, media | `Clock.qml`, `MorphSurface.qml` | Device and audio droplets, media pill, IPC | Content faded completely out before the frame began to move; then the dashboard vanished on the first frame and the menu slid down with the contracting top edge | Anchored crossfade from a frozen copy of the outgoing page; `restY` glides with the size; chrome fades | Combined content opacity stays above 0.85, outgoing copy and incoming page hold still, bottom edge fixed, top edge monotonic |
| Wi-Fi ↔ Bluetooth ↔ battery tabs, sound ↔ mic | `VerticalControlMenu.qml` | Selector tabs, Left/Right keys, droplets | Panel faded completely out between modes | Immediate panel switch | Content stays opaque; bottom edge fixed during each switch |
| Dashboard sections | `Clock.qml` | `stats`, `weather` IPC | Same as dashboard switches when the size changes | `restY` | Bottom edge fixed |
| Tray grid → app menu → back | `TrayFlyout.qml`, `BarPopup.qml` | Tray droplet, right-click, menu-only apps, back button | Window re-centred and resized instantly; body top jumped ~80 px; shrink clipped by the already-small window | Full-height, grow-only window; body centred on the trigger; content fade | Window geometry constant; body centre fixed; fast reversal |
| Tray item count / async menus | `TrayFlyout.qml` | StatusNotifierItem registration, DBusMenu layout | Same jumps on every size change | Same | Live add/remove of three items |
| Clock time tools | `Clock.qml`, `BarPopup.qml` | Clock right-click | Centred window relied on compositor sliding near the screen bottom | Body clamped to the 8 px gap | Centred on the clock, clamped, 8 px from the dock |
| Another trigger while open | `Visibilities.claimBarPopup`, hosts | Tray ↔ dashboard, device → tray, time tools → dashboard | — | Unchanged ownership; each surface follows the rules above | Replacement scenarios in the trace run |

The rounded mask renders the content page at its resting dimensions, rather
than reallocating a texture for the changing frame dimensions on every tick.
It is disabled at rest so text renders directly in the window scene graph.
Top and bottom bar surfaces keep `maskContent: false` and share the chrome and
inner-radius fixes.

## Verification

`tests/e2e/test_left_motion_runtime.py` runs the full shell on a private Niri
inside headless Weston with private runtime, config, cache and session bus,
real StatusNotifierItems with DBusMenus, and no system bus.

- `test_frame_traces` samples every animation tick of the dashboard, tray and
  time-tools surfaces across the scenarios above and asserts the ledger's
  invariants. Continuity checks are normalised by elapsed time, so a loaded
  software renderer does not pass for a snap.
- `test_rounded_corners_in_composited_frames` pauses each surface's own reveal
  animation mid-open, lets the content reach full opacity, takes a real
  screenshot and checks the pixels just inside all four corners.

`LEFT_MOTION_BASELINE=<git ref>` runs the covered files from that revision for
comparison; `LEFT_MOTION_ARTIFACTS=<dir>` keeps traces and screenshots.

The frame trace covers both dashboard/device directions and rapid reversals;
the pixel check captures nine composited corner frames. The schema, QML
syntax, and Tiers 1–3 runner covers 304 checks. These private-compositor
checks do not establish physical-display performance.

A matched software-renderer timing run measured first-open tick gaps of
42 ms for the dashboard and 17 ms for device and tray menus, compared with
36 ms, 17 ms, and 17 ms from HEAD. These are observations from one run,
not hardware-GPU performance claims or a timing gate. No startup warmup
window or artificial delay is used.
