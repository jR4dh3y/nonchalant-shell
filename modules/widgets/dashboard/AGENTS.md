# DASHBOARD KNOWLEDGE BASE

## OVERVIEW
Popup dashboard hosted inside the bar clock popup (`Clock.qml`). It provides a compact hub containing two views:
1. `WidgetsTab`: Media player (`FullPlayer`), calendar, quick controls, and notification history.
2. `WallpapersTab`: Wallpaper selection gallery with search and monitor targeting.

Note: Standalone configuration panels (`controls/`) are used by `modules/widgets/config/SettingsWindow.qml`. Hardware resource meters (`metrics/`) are used by `modules/bar/SystemMonitorButton.qml`.

## STRUCTURE
- **Root**: `Dashboard.qml` — Container for `WidgetsTab` (tab 0) and `WallpapersTab` (tab 1).
- **View Wrapper**: `DashboardView.qml` — Provides keyboard navigation and tab switching.
- **Widgets View**:
  - `widgets/WidgetsTab.qml`: Main grid: `FullPlayer`, `Calendar`, `NotificationHistory`, `QuickControls`.
  - `widgets/FullPlayer.qml`: MPRIS media player with cover art and seekbar.
  - `widgets/QuickControls.qml`: Wi-Fi, Bluetooth, Night Light, and GPU quick toggles with drawers.
  - `widgets/NotificationHistory.qml`: Notification history list with clear actions.
  - `widgets/calendar/`: Monthly calendar view.
- **Wallpapers View**:
  - `wallpapers/WallpapersTab.qml`: Wallpaper gallery with search and screen targeting.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Dashboard Host** | `modules/bar/clock/Clock.qml` | Instantiates `DashboardView` as a flyout popup |
| **Media Player** | `widgets/FullPlayer.qml` | MPRIS metadata, playback controls, seekbar |
| **Quick Toggles** | `widgets/QuickControls.qml` | Network, Bluetooth, Night Light, GPU drawers |
| **Wallpapers** | `wallpapers/WallpapersTab.qml` | Wallpaper gallery and picker |
| **System Settings** | `modules/widgets/config/SettingsWindow.qml` | Full-screen settings window |

## CONVENTIONS
- **UI primitives**: ALWAYS use `StyledRect` variants (`"pane"`, `"internalbg"`, `"focus"`) for themed containers. Never use raw `Rectangle`.
- **Layout containers**: Use `Item` (never `Rectangle { color: "transparent" }`) for layout wrappers.
- **Service bindings**: Connect directly to service singletons (`NetworkService`, `BluetoothService`, `MprisController`, `Audio`). No prop-drilling.
- **Strong Typing**: Strongly type properties (`int`, `real`, `string`, `bool`, `date`). Avoid untyped `property var`.

## ANTI-PATTERNS
- Using raw `Rectangle` instead of `StyledRect` for any visual container.
- Using `Rectangle { color: "transparent" }` where an `Item` belongs.
- Prop-drilling service state through parent components instead of importing singletons directly.
- Hardcoding animation durations or hex colors.
