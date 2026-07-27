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
- Derive spacing and radius from `Styling`; do not hardcode popup geometry.
- Load `LauncherView` only while the run menu is open.
- Use `Qt.callLater()` when transferring focus after the loader becomes ready.
- Record usage before closing after an app launch.

## ANTI-PATTERNS

- Reintroducing notch, cutout, screen-edge, or notification-host behavior.
- Adding dashboard tabs or prefix routing back into the run menu.
- Executing apps without updating `UsageTracker`.
