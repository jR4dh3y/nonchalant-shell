Run disposable compositor checks with the Nix test environment:

```bash
nix develop .#compositor-test --command python3 tests/runtime/run_compositor.py --compositor niri --shell --style default
nix develop .#compositor-test --command python3 tests/runtime/run_compositor.py --compositor niri --shell --style left
nix develop .#compositor-test --command python3 tests/runtime/run_compositor.py --compositor hyprland --shell --style island
```

The runner starts a private D-Bus session and assigns a private HOME, XDG directories and compositor sockets to its children. Both compositors run inside Weston on a separate headless display. Quickshell uses OpenGL RHI through Mesa llvmpipe so its shader-backed containers render correctly. Niri also uses software rendering. Hyprland requires a GPU render node for its DMA-BUF allocator; its headless parent has no physical display attached. IPC targets only Quickshell PIDs created by the runner; cleanup terminates only its owned process groups.

The test environment applies `nix/headless-aquamarine.patch` to Aquamarine 0.15.1 and loads it only in its Hyprland test wrapper. The patch negotiates the advertised `wl_seat`, `xdg_wm_base` and `wl_compositor` versions. Unpatched Aquamarine requests `wl_compositor` and `xdg_wm_base` version 6 from Weston, which advertises version 5, then disconnects. Production Hyprland packaging remains unchanged.

Each run leaves logs, screenshots, a JSON result, and final normalized state in the printed artifact directory. Supply `--artifacts /absolute/path` for a chosen directory. Use a new directory for each run. `--source /path/to/checkout` selects the shell under test. `--baseline --shell --source /path/to/old/checkout` captures empty and occupied screenshots without requiring the new compositor service. Baseline copies receive the same private FIFO isolation as the changed source. `--quickshell /absolute/path/to/qs` selects a previous Quickshell build for upgrade comparisons. `--style default` and `--style island` select both bar layouts through private configuration files. AI is disabled in the private configuration.

For `--style left`, the runner also opens the Wi-Fi, sound, microphone, Bluetooth, battery, and media panels through shell IPC. It checks replacement of the dashboard, switching between sound and microphone, and reverse-toggle dismissal. System Monitor and Wallpapers replace only the dashboard's right pane. The runner checks that the calendar keeps its geometry and state, the active wallpaper pane receives focus, rapid switches settle, a repeated command restores notifications, and closing the popup stops system-monitor sampling. Each panel has a screenshot. The active vertical workspace stacks the shared app icons inside its moving highlight; empty and inactive workspaces keep their labels. On Niri, the runner also checks the pinned assistant against a maximized native tiled client: the left dock offset is reserved, stale top/bottom gaps are absent, and unpinning, moving the assistant to the right, or disabling the bar updates the reserved space.

The left-bar run registers real StatusNotifierItems and DBusMenu services on its private D-Bus session using `tray_fixture.py` and the test-only `dbus-next` package. It clicks the tray trigger and app icons with a virtual pointer, checks activation and menu dispatch, menu-only apps, disabled actions, nested menus and back navigation. It also checks Escape, outside-click and reverse-toggle dismissal, replacement by another popup, live item registration/removal, and that opening or growing the flyout leaves the bar controls in place. Tray grid and menu screenshots are saved with the other artifacts.

The tray fixture has transparent icon pixels. The runner compares their visible
pixels before hover and during the first rendered hover frames across repeated
pointer transitions. Opaque square fixtures do not expose the batching regression
where a hover background briefly covers an icon.

The integration checks click the shared workspace app icons in left and island layouts using a virtual pointer, verify that their highlight travels and settles in both directions, and check updates after a window moves. They also exercise actual window mapping, focus, adjacent workspace navigation, moving a specific window without following focus, fullscreen entry and exit, safe failure for an invalid close target, and closing a particular window while preserving another. `--shell` also launches the complete shell, verifies launcher/dashboard/power-menu opening and reverse dismissal, opens settings through its real IPC entry point, and captures screenshots. A read-only test IPC component is added only to the private copy to inspect actual island and overlay state.

Use `--power-cycle` to check the standalone monitor-power fallback before starting Quickshell. Its environment selects only the disposable compositor. The runner restores its test outputs before cleanup. Result JSON includes separate counts for QML errors, binding/type warnings, and unavailable optional helper tools; compare those counts with a baseline run rather than treating every unavailable hardware helper as a compositor regression.

Passing these checks does not prove mixed-scale output behavior, monitor hotplug, every overlay and animation, named/special Hyprland workspace policy, Lua dispatch, PAM authentication, suspend/resume, or hardware brightness. Those require additional acceptance scenarios. Hardware power and brightness actions are deliberately excluded from this runner.


Fractional-scale text rendering can be checked without touching the desktop:

```bash
nix develop .#compositor-test --command python3 tests/runtime/run_compositor.py --compositor hyprland --text-rendering --scale 1.2
```

Repeat with `--scale 1`, `1.5`, and `2`. The test captures a 1920×1200 private output and compares actual glyph pixels inside three nested `StyledRect` containers with directly rendered text. Reference `ClippingRectangle` containers reproduce the old texture-resampling blur at 1.2×. Sample origins align to physical pixels at these scales so incidental half-pixel glyph placement cannot masquerade as texture filtering. The test also checks rounded linear, radial and halftone backgrounds, asymmetric hover corners, and translucent border pixels against a single-painted solid reference. `--scale` can be combined with `--shell --style left` to inspect the full bar. These options currently require Hyprland.

`StyledRect` paints its rounded background directly and clips children to rectangular bounds. Keep text and controls outside offscreen masks. Artwork and other backgrounds that fill rounded corners need their own `ClippingRectangle`; mask only those visual items. `HoverTint` copies the parent’s radius and all four corner overrides.

Rendering change coverage:

| Surface | Applies | Source | Required change | Check | State |
| --- | --- | --- | --- | --- | --- |
| Bar labels, workspace numbers, nested buttons | Yes | `StyledRect.qml`, all bar layouts | Render foreground directly | Glyph pixel comparison at integer and fractional scales; full shell screenshots | Passed at 1×, 1.2×, 1.5× and 2×; old container fails at 1.2× |
| Gradients and hover states | Yes | `StyledRect.qml`, `HoverTint.qml` | Mask backgrounds only; copy asymmetric radii | Rendered corner and fill pixel assertions | Passed at 1×, 1.2×, 1.5× and 2× |
| Media cards and sidebar player | Yes | `IslandMediaCard.qml`, `IslandMediaCenterPanel.qml`, `FullPlayer.qml` | Keep artwork rounded independently of controls | Private MPRIS fixture, playback, timed lyrics, popup placement and screenshots | Passed on Niri |
| Wallpaper and attachment thumbnails | Yes | `IslandWallpaperPanel.qml`, `AssistantSidebar.qml` | Explicit image masks | Source audit and wallpaper screenshots | Masks retained; attachment interaction not exercised |
| Opening, closing and workspace transitions | Yes | `MorphSurface.qml`, shared controls | Preserve bounds clipping and existing transitions | Private Niri full-shell suite | Passed |
| Hyprland provider and fractional buffer negotiation | Yes | Native Wayland layer shell | Preserve compositor scaling | Private Hyprland at 1.2× | Native buffer dimensions verified; unrelated dispatcher and keyboard-tab checks remain failing |
| Mixed-scale monitors and physical GPU output | Yes | Per-screen shell instances | No shared scale override | Hardware acceptance | Not tested |
| Remote providers and persisted configuration | No | No change | None | Source review | Not applicable |
