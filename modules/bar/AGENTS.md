# BAR MODULE KNOWLEDGE BASE

## OVERVIEW
Fixed top system panel rendered inside `UnifiedShellPanel`. The bar is always
pinned and reserves space through `ReservationWindows`.

## STRUCTURE
- **Core Layout**:
  - `BarContent.qml`: Orchestrates the bar layout engine (`default`, `island`, `pills`, `left`, `deck`).
  - `BarBg.qml`: Background and content padding for default bar.
  - `layouts/DefaultBar.qml`: Fixed full-width top/bottom panel with taskbar, clock, and sliders.
  - `layouts/IslandBar.qml`: Dynamic island pinned to top edge with concave ears and morphing panels.
  - `layouts/PillsBar.qml`: Floating modular pills layout with fluid spring morphing for all panels.
  - `layouts/DeckBar.qml`: Compact three-zone bar with dedicated workspace, task, and system controls. Supports top and bottom placement.
  - `deck/`: Deck-specific controls, window/workspace strips, and task-specific flyouts. No dependency on incumbent bar widgets or island panels.
- **Widgets**:
  - `clock/`: Time, date, weather integration (`Clock.qml`).
  - `systray/`: SNI-based system tray (`SysTray.qml`, `SysTrayItem.qml`).
  - `workspaces/`: Compositor workspace visualization and `NonchalantTaskbar.qml`.
  - `audioformat/`: DAC format and bit depth indicator (`AudioFormatBadge.qml`).
- **System Indicators**:
  - `BatteryIndicator.qml`: Circular gauge with charge animations.
  - `BrightnessSlider.qml`: Backlight control.
  - `CircularBarMeter.qml`: Reusable circular bar widget.
  - `MicSlider.qml` & `VolumeSlider.qml`: PipeWire input/output controls.
  - `SystemMonitorButton.qml`: Hardware metrics trigger.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Space reservation** | Parent: `shell.qml` → `ReservationWindows` | `exclusiveZone` calculation |
| **Adding widgets** | `BarContent.qml` | Top/bottom bar layout orchestration |
| **Clock/Weather** | `clock/Clock.qml` | Time, calendar popup trigger, weather details |
| **Taskbar & Apps** | `workspaces/NonchalantTaskbar.qml` | Active app windows and workspace switching |
| **Headphone Audio** | `audioformat/AudioFormatBadge.qml` | Sample rate & bit depth pill |

## CONVENTIONS
- **Strong Typing**: Pass bar references as `required property Item bar` (never `property var bar`).
- **Corner Continuity on Hover**: In pill highlights, never use `radius: parent.radius ?? 0` (evaluates to 0 on asymmetric pills). Bind `topLeftRadius`, `topRightRadius`, `bottomLeftRadius`, `bottomRightRadius` from parent.
- **Adaptive styling**: Widgets use `startRadius`/`endRadius` for "pill" continuity based on group position.
- **Typography**: Always use `StyledText` instead of bare `Text` to ensure native rendering and full hinting.
- **Tooltips**: Use `StyledToolTip` with `show: root.isHovered` and `description: ...` (not `visible` or misspelled props).
- **Positioning**: Respect `Config.bar.position` (`"top"` or `"bottom"`).
- **Screen filtering**: Respects `Config.bar.screenList` for multi-monitor control.

## ANTI-PATTERNS
- Declaring `property var bar` instead of `property Item bar`.
- Using raw `Rectangle` for hover highlights that break asymmetric corner rounding.
- Hardcoding bar height (use `Config.bar.height` / bar panel dimensions).
- Using bare `Text` primitives instead of `StyledText`.
