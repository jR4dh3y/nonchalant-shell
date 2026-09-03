# CONFIG KNOWLEDGE BASE

## OVERVIEW
Reactive, file-backed configuration system built on `Quickshell.Io`. Source of truth for all shell modules. Stores JSON in `~/.config/nonchalant/config/`. Missing files are created from in-tree defaults.

## STRUCTURE
- **Config.qml**: Core singleton. `FileView` monitors disk; `JsonAdapter` creates bidirectional QML bindings. Each live module domain has its own `FileView`/`JsonAdapter` pair.
- **defaults/*.js**: JavaScript modules exporting a `data` object — the blueprint for initial file generation and validation baseline. Live domains are `theme`, `bar`, `performance`, `weather`, `lockscreen`, `system`, and `ai`.
- **ConfigValidator.js**: Recursive `validate()` function for deep-merging user settings with defaults. Handles type coercion and constraint enforcement (e.g., `gradientType` must be `"linear"`, `"radial"`, or `"halftone"`).
- **pam/**: PAM configuration for lockscreen authentication.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Add config key** | `defaults/<domain>.js` + `Config.qml` | BOTH must be updated |
| **Validation logic** | `ConfigValidator.js` | Recursive `validate()` with type constraints |
| **Bootstrapping** | `Config.qml` (`Process` + `onExited`) | Detects missing JSON, populates from `defaults/*.js` |
| **File sync** | `Config.qml` (`FileView`/`JsonAdapter` pairs) | Each domain has isolated persistence |
| **Load gating** | `Config.qml` (`initialLoadComplete`) | Guards components needing fully-initialized config |

## CONVENTIONS
- **Single Source of Truth**: `defaults/*.js` is the sole blueprint. Always include `.pragma library` at line 1 of every defaults file.
- **Atomic updates**: ALWAYS update BOTH `defaults/<domain>.js` and `Config.qml` when adding or modifying keys.
- **Strong Typing**: Expose domain adapters using `property alias <domain>: <domain>Loader.adapter` to preserve the `JsonAdapter` contract; never erase type fidelity with generic `QtObject`.
- **Bind to Config**: UI elements bind to `Config.<module>.<property>`. Never use local state for persistent settings.
- **Auto-save**: `JsonObject` property modifications auto-persist immediately via `FileView`.
- **Null Safety**: Always guard nested property access (`Config.<domain>?.<property> ?? fallback`).
- **Validation**: Enforce explicit valid sets for enums (e.g. `gradientType`, `position`, `sidebarPosition`, `unit`).

## ANTI-PATTERNS
- Adding a config key without a corresponding default in `defaults/*.js`.
- Erasing adapter types with `property QtObject`.
- Retaining dead keys or obsolete validator checks (e.g. Ambxst leftovers like `noMediaDisplay`).
- Reading config values before `initialLoadComplete` without a null guard.
- Direct disk mutations while the shell is running (write through reactive `Config` properties).
