# SCRIPTS KNOWLEDGE BASE

## OVERVIEW
Python and Bash backend utilities invoked by QML services via `Quickshell.Io.Process`. Handle system-level tasks that are impractical in pure QML/JS: hardware monitoring, clipboard persistence, and wallpaper processing.

## WHERE TO LOOK
| Script | Language | Called By | Role |
|--------|----------|-----------|------|
| `system_monitor.py` | Python | `SystemResources.qml` | CPU, RAM, GPU, disk, network polling. Emits JSON lines |
| `generate_wallpaper_colors.sh` | Bash | `Wallpaper.qml`, `Config.qml` | Matugen/Wallust color palette extraction |
| `thumbgen.py` | Python | `Wallpaper.qml` | Wallpaper thumbnail generation |
| `lockwall.py` | Python | `Wallpaper.qml` | Extracts first video/GIF frame for lockscreen |
| `brightness_list.sh` | Bash | `Brightness.qml` | Backlight & DDC/CI monitor brightness discovery |
| `weather.sh` | Bash | `WeatherService.qml` | GeoIP lookup + Open-Meteo weather fetch |
| `daemon_priority.sh` | Bash | `cli.sh` | Terminates competing notification daemons (dunst, mako, etc.) |
| `install-fonts.sh` | Bash | Setup / manual | Installs Phosphor, JetBrains Mono, League Gothic |
| `clipboard_watch.sh` | Bash | `ClipboardService.qml` | Watches clipboard events via `wl-paste --watch` |
| `clipboard_check.sh` | Bash | `ClipboardService.qml` | Validates clipboard state and deduplication |
| `clipboard_insert.sh` | Bash | `ClipboardService.qml` | Inserts or updates item in `clipboard.db` SQLite database |

## CONVENTIONS & SECURITY RULES
- **Bash Strict Mode**: Every Bash script MUST start with `set -euo pipefail`.
- **Pre-flight Checks**: Verify external dependencies (`curl`, `jq`, `ffmpeg`, `matugen`, `ddcutil`) before execution; output structured error on failure.
- **Error Format**: Scripts consumed by QML services MUST output valid JSON errors on failure (e.g. `{"error": "reason"}`).
- **Credential Safety**: NEVER pass API keys, passwords, or tokens via command-line arguments (`argv`). Pass secrets via stdin or secure files.
- **Safe Temp Paths**: Use `$XDG_RUNTIME_DIR` or user-owned `$TMPDIR` with `mktemp`. Never hardcode static paths in `/tmp`.
- **SQL Safety**: Always parameterize or safely escape variables before querying SQLite databases.
