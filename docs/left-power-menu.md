# Left bar power menu

In the left layout, Super+X turns the dock's own controls into power actions.
There is no popup and no second shelf. The menu adds no configuration keys.

The previous variant, a horizontal shelf out of the dock's bottom corner, is
commit `f3a05d53`.

## Shape

`modules/bar/layouts/LeftBar.qml` draws the mode in place:

- The capsule's launcher, workspaces and media fade out. Lock, Sleep and
  Hibernate rise into the capsule's bottom slots. They share an
  `ElasticHighlight` like the workspace buttons.
- The tray droplet folds into the capsule, so the capsule grows down into its
  slot, while its top edge slides down onto the session actions. The open
  capsule wraps exactly Lock, Sleep and Hibernate; the dock contents fade out
  in the first third of the reveal, before that edge passes them.
- The audio, brightness and device droplets become Log out, Restart and
  Shut down, in the same circles. The Shut down glyph uses `Colors.red`. A
  selected droplet uses the focus variant.
- The clock keeps the time. It is inert, so clicking it dismisses the mode like
  any other click outside an action.
- Arming a droplet stretches it to the right into an error-variant capsule.
  The glyph becomes a check and the action name appears. That label is the only
  text. Selecting the same action again runs it.

There is no heading, close icon, tooltip, keyboard hint or footer.

Files:

- `LeftPowerMode.qml` holds the state: selection, arming, the confirmation
  timeout, keys and the reveal animation. `PowerMenuHost.qml` owns one per
  screen.
- `LeftPowerSlot.qml` wraps one droplet and grows its action out of it.
- `LeftPowerAction.qml` draws one action.

These are separate files instead of inline components. A running shell failed
to hot reload an inline component in an edited file ("is not a type").

## State and input

`PowerMenuHost.qml` is the only place that opens or closes the menu
(`openMenu`, `closeMenu`, `togglePopup`). It decides where to show it:

- `LeftBar` binds the host's `dockShown` to its own reveal while it exists.
  The host uses the dock when the style is `left` and `dockShown` is true.
  Otherwise it uses the popup.
- If the dock goes away while the menu is open, the menu closes and disarms.
  This covers overview, fullscreen, a layout change and the bar leaving the
  screen.
- `UnifiedShellPanel.qml` takes exclusive keyboard focus and full-screen input
  while `dockModeOpen` is true. Its backdrop click closes the menu.
- While the mode shows or animates, the normal controls are disabled. The
  actions only take input while the menu is open, so no hitbox is left over
  during or after the collapse.

## Motion

One `reveal` value drives every part. Opening uses the shared `Motion` spring
with overshoot. Closing uses the monotonic collapse curve and never swells.
A reversal continues from the current value. The capsule leads and the
droplets follow top to bottom with a short delay each. Each action sits under
its fading droplet, so the shared circle never dims during the crossfade. The
armed capsule expands on the spring and collapses monotonically. A pressed
action scales as a whole with `PressBehavior`.

## Surface ledger

| Entry or state | Behavior |
| --- | --- |
| Left layout with a revealed dock | The dock transforms in place. |
| Left layout while the dock is hidden | Uses the popup. |
| Default layout | Keeps `PowerMenuView.qml` in `MorphSurface` at the bottom. |
| Deck, Island and Pills | Routing in `Visibilities` is unchanged. |
| Super+X and IPC | Toggle the focused monitor's registered host. Registration follows late screen assignment. |
| Hover | Moves the selection to the hovered action. |
| Keyboard | Up, Down, Tab and Shift+Tab move in visual order. Enter or Space selects. Key repeat never selects. |
| Destructive confirmation | Log out, Restart and Shut down need a second selection of the same action. |
| Moving off an armed action | Disarms it. |
| Escape while armed | Disarms and keeps the menu open. |
| Confirmation timeout | Disarms after five seconds. |
| Outside click, clock click or unarmed Escape | Closes the menu. |
| Launcher, bar popup, focus on another monitor, screen change | Closes the menu. |
| Reopen | Starts with Lock selected and nothing armed. |

## Verification

`tests/e2e/test_left_power_mode_runtime.py` runs the full shell on a private
Niri nested in headless Weston. It uses private runtime, config, cache and
session bus, and a missing system bus. A small StatusNotifierItem shows the
tray droplet. A private copy of the power menu module replaces the action
runner with a logging stub. `systemctl` and `loginctl` on `PATH` only log, and
the test fails if they are called. `brightnessctl` and `ddcutil` on `PATH` fail,
so the host's real backlight never changes the dock mid-test. The test covers:

- The Super+X IPC path, focus, and full-screen input.
- The capsule and droplet slot geometry, and the hidden, disabled normal
  controls.
- The spring reveal with overshoot, the monotonic collapse, and reversal
  continuity.
- Keyboard selection, arming, the stretch, the accessible confirm name, Escape,
  held Enter, moving off an armed action, and the timeout.
- Click dispatch into the stub.
- Outside, clock and Escape dismissal.
- Pixel-identical restoration of the dock above the clock.
- Repeated toggling and replacement by the run menu.

It saves `left-power-{normal,open,selected,armed,restored}.png` to
`$LEFT_POWER_ARTIFACTS`, or to a new temporary directory.
Clicks are synthesized inside the panel window through Qt's input
delivery. They do not go through compositor pointer input.

`tests/e2e/test_bottom_flyout_runtime.py` covers the popup fallback for the
left style without a dock, and closing and disarming when the dock goes away.

No real lock, logout, sleep, hibernate, restart or shutdown was run.
Physical multi-monitor behavior was not tested.
