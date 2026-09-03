# BAR MODULE KNOWLEDGE BASE

## OVERVIEW
Fixed top system panel rendered inside `UnifiedShellPanel`. The bar is always
pinned and reserves space through `ReservationWindows`.

## STRUCTURE
- **Core Layout**:
  - `BarContent.qml`: Orchestrates the top-bar widget groups.
  - `BarBg.qml`: Background and content padding.
- **Widgets**:
  - `clock/`: Time, date, weather integration (`Clock.qml`).
  - `media/`: `MediaPill.qml` — auto-hiding media info section of the center pill.
  - `systray/`: SNI-based system tray.
  - `workspaces/`: Compositor workspace visualization and navigation.
  - `IntegratedDock.qml`: Taskbar-style dock embedded directly into bar layout.
- **System Indicators**: Volume, brightness, battery, power profile sliders/buttons.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Space reservation** | Parent: `shell.qml` → `ReservationWindows` | `exclusiveZone` calculation |
| **Adding widgets** | `BarContent.qml` | Update the top-bar layout |
| **Clock/Weather** | `clock/Clock.qml` | Complex: 672 lines, multiple display modes |

## CONVENTIONS
- **Adaptive styling**: Widgets use `startRadius`/`endRadius` for "pill" continuity based on group position.
- **Visibility registration**: Panels must register with `Visibilities` in `Component.onCompleted`.
- **Orientation**: Bar components only need to support the fixed top layout.
- **Config binding**: Use `Config.bar.*` properties for all layout-related state.
- **Screen filtering**: Respects `Config.bar.screenList` for multi-monitor control.
