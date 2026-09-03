# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-01
**Framework:** QtQuick / Quickshell
**Language:** QML / JavaScript

## OVERVIEW
Nonchalant Shell is a Niri-first Wayland shell and hard fork of Ambxst, built with Quickshell. The lean runtime provides a wallpaper, one unified bar, a floating run menu, and a lockscreen, driven by a reactive JSON configuration system. Multi-monitor support uses `Variants` on `Quickshell.screens`.

## STRUCTURE
```
./
├── config/               # Config singleton + JSON defaults (see config/AGENTS.md)
│   └── defaults/*.js     # Blueprint for each config domain (bar, theme, ai, etc.)
├── modules/
│   ├── bar/              # Panel widgets: clock, systray, workspaces, indicators
│   ├── components/       # Reusable UI primitives + GLSL shaders (55 files)
│   ├── globals/          # GlobalStates.qml — transient runtime state
│   ├── lockscreen/       # WlSessionLock + PAM authentication
│   ├── notifications/    # Notification popup system + history
│   ├── services/         # Backend singletons (30+): Battery, AI, Network, etc.
│   ├── shell/            # UnifiedShellPanel + ReservationWindows + OSD
│   ├── theme/            # Colors, Icons, Styling singletons + app generators
│   └── widgets/          # Complex overlays: dashboard, launcher, overview, etc.
│       ├── config/       # Standalone settings window
│       ├── dashboard/    # Main hub: controls, metrics, assistant, clipboard, notes
│       ├── launcher/     # App search + multi-tab launcher
│       ├── powermenu/    # Lock, logout, shutdown actions
│       └── tools/        # Quick utility access (OCR, recording, etc.)
├── assets/               # Wallpapers, color presets, AI provider configs, sounds
├── scripts/              # Python/Bash backends (system monitor, clipboard, OCR)
├── nix/                  # Nix flake, packages, and module definitions
├── shell.qml             # Entry point: ShellRoot, Variants, service init
└── cli.sh                # Launch wrapper and IPC controller
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Entry Point** | `shell.qml` | `ShellRoot` → `Variants` per screen for each layer |
| **Config Logic** | `config/Config.qml` | Per-domain `FileView` + `JsonAdapter` persistence |
| **Transient State** | `modules/globals/GlobalStates.qml` | Window visibility, active modes, runtime flags |
| **Services** | `modules/services/*.qml` | 30+ singletons. System integration layer |
| **Theme/Colors** | `modules/theme/Colors.qml` | Watches `~/.cache/nonchalant/colors.json` reactively |
| **Styling** | `modules/theme/Styling.qml` | `radius()`, `fontSize()`, `getStyledRectConfig()` |
| **UI Primitives** | `modules/components/` | `StyledRect`, `BarPopup`, `SearchInput`, shaders |
| **Dashboard** | `modules/widgets/dashboard/` | Tabbed hub with LRU lazy-loading |
| **Launcher** | `modules/widgets/launcher/LauncherView.qml` | Unified search: apps, clipboard, emoji |
| **Bar Layout** | `modules/bar/BarContent.qml` | Fixed top bar and widget groups |
| **Headphone Info** | `modules/services/AudioFormat.qml` + `modules/bar/audioformat/` | Sample rate/bit depth pill for bt/usb/wired headphones |
| **Run Menu** | `modules/widgets/launcher/RunMenuHost.qml` | Floating launcher host inside the unified panel |
| **Lockscreen** | `modules/lockscreen/LockScreen.qml` | PAM auth + `WlSessionLockSurface` |
| **Notifications** | `modules/notifications/` | Popup system + delegate + history |
| **Adding Config** | `config/defaults/*.js` + `Config.qml` | Always update both when adding keys |

## CODE MAP

| Symbol | Type | Location | Role |
|--------|------|----------|------|
| `Config` | Singleton | `config/Config.qml` | Central config store. Reactive to JSON file changes |
| `GlobalStates` | Singleton | `modules/globals/GlobalStates.qml` | Shared runtime state (non-persistent) |
| `Visibilities` | Singleton | `modules/services/Visibilities.qml` | UI visibility/layering manager per screen |
| `Colors` | Singleton | `modules/theme/Colors.qml` | Dynamic color palette from JSON |
| `Styling` | Singleton | `modules/theme/Styling.qml` | Shared style utilities (radius, font, variants) |
| `Icons` | Singleton | `modules/theme/Icons.qml` | Phosphor-Bold icon font character map |
| `StyledRect` | Component | `modules/components/StyledRect.qml` | Base themed container (300+ usages) |
| `GradientCache` | Singleton | `modules/components/GradientCache.qml` | GPU texture sharing optimization |
| `UnifiedShellPanel` | Component | `modules/shell/UnifiedShellPanel.qml` | Full-screen input surface for the bar and floating run menu |
| `ShellRoot` | Component | `shell.qml` | Root window. `Variants` per screen |
| `NiriService` | Singleton | `modules/services/NiriService.qml` | Compositor abstraction (focus, dispatch) |
| `StateService` | Singleton | `modules/services/StateService.qml` | JSON persistence for session state |
| `FocusGrabManager` | Singleton | `modules/services/FocusGrabManager.qml` | Input focus coordination |
| `AudioFormat` | Singleton | `modules/services/AudioFormat.qml` | Headphone classification (bt/usb/wired) + negotiated sample rate/bit depth via pactl |
| `AudioFormatBadge` | Component | `modules/bar/audioformat/AudioFormatBadge.qml` | Bar pill: headphone sample rate + bit depth; collapses when nothing attached |

## CONVENTIONS
- **Singletons**: `pragma Singleton` + `Singleton { id: root }` for all services and global state.
- **Strong Typing**: Always declare explicit types (`int`, `real`, `string`, `bool`, `Item`, `color`, `list<T>`, `JsonAdapter`). Avoid untyped `property var` or generic `QtObject` where concrete types exist.
- **Imports**: `import qs.modules.*` namespace. Resolved by Quickshell's module system, not `qmldir` files.
- **Persistence**: `FileView` watches JSON on disk; `JsonAdapter` creates bidirectional QML bindings. `defaults/*.js` is the sole source of truth.
- **Formatting**: 4-space indent.
- **Defaults**: New config keys MUST have entries in `config/defaults/*.js`.
- **Multi-monitor**: `Variants { model: Quickshell.screens }` pattern for per-screen instances.
- **StyledRect containers**: Use `"pane"`, `"popup"`, `"common"`, `"internalbg"`, `"focus"` for containers. Never use raw `Rectangle` as a container.
- **Null safety**: Always null-check nested properties in QML (`object?.property ?? fallback`) to avoid `TypeError: Value is undefined`.
- **Service init**: Critical services init on next tick via `Qt.callLater`.
- **Async safety**: Use `Qt.callLater()` when modifying lists inside process handlers.
- **Process lifecycle**: Always clean up created processes; reset busy flags in `onExited` (including failure cases); use `StdioCollector` for multi-line JSON.

## ANTI-PATTERNS (THIS PROJECT)
- **Hardcoding**: NEVER hardcode colors/sizes. Use `Config.theme.*`, `Config.bar.*`, `Colors.*`, `Styling.*`.
- **Loose Typing**: NEVER use `property var` when a concrete type (`string`, `int`, `real`, `bool`, `Item`, `list<string>`) is known.
- **Raw Rectangle containers**: NEVER create raw `Rectangle` containers for styling. Use `StyledRect` with an appropriate variant, or `Item` for layout-only wrappers.
- **Global Pollution**: Do not add properties to `root` in `shell.qml`. Use `GlobalStates`.
- **Raw JS Objects in Connections**: `JSON.parse()` results have NO QML signals. Never use them in `Connections` blocks.
- **Missing Defaults**: NEVER add a config key without updating `config/defaults/*.js`.
- **Bypassing Reactive Config**: Do not modify JSON configuration files directly on disk while running; write through the reactive `Config.<domain>.<key>` properties.
- **Obsolete Shims**: NEVER retain legacy compatibility shims (e.g. Hyprland/axctl syntax or environment variables) in a Niri-first shell.

## RADHEY FLEET STANDARDS & QUALITY BAR
- **Simplicity**: Make complex systems as simple as possible. Remove complexity before adding new layers. Apply YAGNI.
- **Matt Pocock & Theo Browne Quality Bar**: Use strong types. Keep products useful, direct, and lean. Challenge weak ideas.
- **Hit Every Surface**: For any cross-cutting change, trace behavior through all entry points, clients, contracts, reverse actions (e.g. open/close, lock/unlock, undo), error states, and documents. Do not treat one repaired path as a complete feature.
- **Verify Real Behavior**: Test changed behavior at the nearest real boundary (syntax verification, IPC messaging, process execution). State each check that passed and each important flow not tested. Never assume a static check or build proves runtime behavior.
- **Protect Existing Work**: Preserve unrelated user changes. Stage only files that belong to the task.
- **Protect Private Data**: Never log, print, or pass credentials, tokens, or passwords via command-line arguments (`argv`), logs, or shell aliases. Always clear secret variables immediately after authentication.

## COMMANDS
```bash
# Syntax check QML files
qmllint shell.qml
# Run shell (requires Quickshell + Niri)
qs -p .
# Or via CLI wrapper:
./cli.sh
# IPC command testing
qs ipc call nonchalant run <cmd>
```

## NOTES
- Large files: Keep components modular and prune dead code aggressively.
- The `qs.` import prefix is a Quickshell VFS construct, not a physical directory.
- All compositor integration uses Niri IPC or native Quickshell/Wayland APIs. Hyprland and `axctl` dependencies are forbidden.
- AI assistant is integrated via local ACP agent protocols.
