# RUN MENU KNOWLEDGE BASE

## OVERVIEW
The launcher is a unified application and project run menu. It is rendered as a detached floating card inside `UnifiedShellPanel`; Tab switches between Apps and Projects modes without closing it. It must never attach to a screen edge or recreate the removed notch UI.

## STRUCTURE

- `RunMenuHost.qml`: Floating placement, popup styling, focus, and lazy loading.
- `LauncherView.qml`: Apps/Projects mode switching plus app search, keyboard navigation, execution, and actions.
- `../projects/ProjectPickerView.qml`: Project search, keyboard navigation, opening, and path copying.

## KEY SERVICES

| Service | Role |
|---------|------|
| `AppSearch` | Application indexing and fuzzy search |
| `ProjectPickerService` | Project indexing, fuzzy search, and opening |
| `UsageTracker` | Records launches for result ordering |
| `Visibilities` | Per-screen open/close state |

## CONVENTIONS

- Keep the host floating with `StyledRect` variant `"popup"` and rounded edges on every side.
- Use explicit spacing constants for layout padding and gaps (never misuse `Styling.radius()`, which zeroes out on square corner themes).
- **Keyboard & Reverse Action Flow**:
  - `Tab`: Toggles between Apps and Projects modes without closing the run menu.
  - `Shift+Enter` or `Right Click`: Expands application action menu.
  - `Escape`: Must collapse expanded action menu FIRST before dismissing the run menu.
  - `Backdrop click`: Clicking outside the card on `UnifiedShellPanel` must dismiss the run menu (`Visibilities.setActiveModule("")`).
- **Options Menu Bound Constraint**: The expanded options menu height and keyboard navigation bounds must dynamically match or strictly equal the actual item count (e.g. `count * 36`). Never hardcode a 3-item navigation limit when only 2 actions exist.
- Use `Qt.callLater()` when transferring focus after the loader becomes ready.
- Record usage (`UsageTracker.recordUsage(appId)`) before closing after an app launch.

## ANTI-PATTERNS

- Using raw `Rectangle` elements as containers instead of `Item`.
- Reintroducing notch, cutout, screen-edge, or notification-host behavior.
- Adding dashboard tabs or prefix routing back into the run menu.
- Executing apps without updating `UsageTracker`.
- Prematurely wiping search queries when the user presses Escape to close a sub-menu.
