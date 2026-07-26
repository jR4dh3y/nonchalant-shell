# CONFIG KNOWLEDGE BASE

## OVERVIEW
Reactive, file-backed configuration system built on `Quickshell.Io`. Source of truth for all shell modules. Stores JSON in `~/.config/nonchalant/config/`. Missing files are created from in-tree defaults.

## STRUCTURE
- **Config.qml**: Core singleton. `FileView` monitors disk; `JsonAdapter` creates bidirectional QML bindings. Each live module domain has its own `FileView`/`JsonAdapter` pair.
- **defaults/*.js**: JavaScript modules exporting a `data` object — the blueprint for initial file generation and validation baseline. Live domains are `theme`, `bar`, `workspaces`, `performance`, `weather`, `lockscreen`, `system`, and `ai`.
- **ConfigValidator.js**: Recursive `validate()` function for deep-merging user settings with defaults. Handles type coercion and constraint enforcement (e.g., `gradientType` must be `"linear"`, `"radial"`, or `"halftone"`).
- **pam/**: PAM configuration for lockscreen authentication.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Add config key** | `defaults/<domain>.js` + `Config.qml` | BOTH must be updated |
| **Validation logic** | `ConfigValidator.js` | Recursive `validate()` with type constraints |
| **Bootstrapping** | `Config.qml` (`Process` + `StdioCollector`) | Detects missing JSON, populates from defaults |
| **File sync** | `Config.qml` (`FileView`/`JsonAdapter` pairs) | Each domain has isolated persistence |
| **Load gating** | `Config.qml` (`initialLoadComplete`) | Guards components needing fully-initialized config |

## CONVENTIONS
- **Atomic defaults**: ALWAYS update `defaults/*.js` when adding new config keys.
- **Bind to Config**: UI elements bind to `Config.<module>.<property>`. Never use local state for persistent settings.
- **Auto-save**: `JsonObject` changes auto-persist immediately via `FileView`.
- **Reactive defaults**: Config access may occur during load/reload. Gate with `initialLoadComplete` if needed.
- **JSON formatting**: 4-space indent for human readability.

## ANTI-PATTERNS
- Adding a config key without a corresponding default in `defaults/*.js`.
- Modifying `Config` properties directly outside the `JsonAdapter` binding system.
- Reading config values before `initialLoadComplete` without a null guard.
