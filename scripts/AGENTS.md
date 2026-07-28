# SCRIPTS KNOWLEDGE BASE

## OVERVIEW
Python and Bash backend utilities invoked by QML services via `Quickshell.Io.Process`. Handle system-level tasks that are impractical in pure QML/JS: hardware monitoring, clipboard persistence, and wallpaper processing.

## WHERE TO LOOK
| Script | Language | Called By | Role |
|--------|----------|-----------|------|
| `system_monitor.py` | Python | `SystemResources.qml` | CPU, RAM, GPU, disk, temperature polling. Outputs JSON to stdout |
| `clipboard_watch.sh` | Bash | `ClipboardService.qml` | Watches clipboard changes via `wl-paste --watch` |
| `clipboard_check.sh` | Bash | `ClipboardService.qml` | Validates clipboard state and deduplication |
| `clipboard_insert.sh` | Bash | `ClipboardService.qml` | Inserts items into clipboard via `wl-copy` |
| `thumbgen.py` | Python | `WallpapersTab` | Wallpaper thumbnail generation |
| `desktop_thumbgen.py` | Python | `DesktopService.qml` | Desktop icon thumbnail generation |
| `lockwall.py` | Python | `LockScreen.qml` | Lockscreen wallpaper blur preprocessing |
| `brightness_list.sh` | Bash | `Brightness.qml` | Enumerates available brightness devices |
| `weather.sh` | Bash | `WeatherService.qml` | Weather data fetching |
| `link_preview.py` | Python | Clipboard | URL metadata/preview extraction |
| `daemon_priority.sh` | Bash | Shell init | Process priority adjustment |

## CONVENTIONS
- **Communication**: Scripts output to stdout; QML reads via `Process` + `SplitParser` or `StdioCollector`.
- **Format**: Python scripts output JSON; Bash scripts output line-delimited text.
- **Dependencies**: Scripts assume tools are installed (`wl-paste`, `wl-copy`, `niri`, `brightnessctl`). Nix/install.sh handles dependencies.
- **Error handling**: Scripts should exit cleanly on missing tools; QML services provide fallback values.
