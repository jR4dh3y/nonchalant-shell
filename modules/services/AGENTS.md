# SERVICES KNOWLEDGE BASE

## OVERVIEW
Backend singletons bridging Wayland protocols, CLI tools (nmcli, upower, wpctl, etc.), and AI providers to the QML UI layer. 30+ services following a "Reactive Singleton" pattern — internal state derived from async system calls, exposed as QML properties.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Audio/Volume** | `Audio.qml` | PipeWire/PulseAudio via `wpctl`. Sink/source management |
| **Headphone Format** | `AudioFormat.qml` | Headphone DAC format & sample rate monitor |
| **Network/WiFi** | `NetworkService.qml` | `nmcli` wrapper. WiFi scanning, connection, status |
| **Battery/Power** | `Battery.qml` | UPower integration. Percentage, charging state, time remaining |
| **Power Profiles** | `PowerProfile.qml` | Power profile switcher via `powerprofilesctl` / `tlp` |
| **Bluetooth** | `BluetoothService.qml` | Device listing, connect/disconnect via `bluetoothctl` |
| **Brightness** | `Brightness.qml` | Per-monitor brightness via `brightnessctl` and DDC/CI |
| **Night Light** | `NightLightService.qml` | Gamma temperature adjustment via `gammastep` / `wlsunset` |
| **AI Assistant** | `Ai.qml` | Local ACP agent integration (OpenCode, Grok Build, Codex) |
| **Clipboard** | `ClipboardService.qml` | Persistent clipboard via `clipboard.db` SQLite + helper scripts |
| **Media** | `MprisController.qml` | MPRIS D-Bus player control |
| **Notifications** | `Notifications.qml` | D-Bus notification server with persistence |
| **System Monitor** | `SystemResources.qml` | CPU, RAM, GPU, temps via Python script |
| **GPU / VFIO** | `GpuService.qml` | VFIO / PRIME GPU management |
| **Compositor** | `NiriService.qml` | Native Niri IPC abstraction (windows, workspaces, focus) |
| **Visibility** | `Visibilities.qml` | Per-screen UI visibility/layering orchestration |
| **State** | `StateService.qml` | JSON persistence for session state (tab positions, etc.) |
| **Focus** | `FocusGrabManager.qml` | Input focus coordination across overlays |
| **App Search** | `AppSearch.qml` | Application indexing for launcher |
| **Project Picker** | `ProjectPickerService.qml` | Code repository indexer & launcher |
| **Usage Tracker** | `UsageTracker.qml` | App launch frequency and recency tracking |
| **Weather** | `WeatherService.qml` | Forecast, sunrise/sunset, day/night detection |
| **Suspend Manager** | `SuspendManager.qml` | Sleep/resume lifecycle coordinator |
| **Lockscreen Service** | `LockscreenService.qml` | Wayland `ext_session_lock` lifecycle coordinator |
| **Shell IPC** | `GlobalShortcuts.qml` | CLI/IPC command routing |

## CONVENTIONS
- **Singleton pattern**: `pragma Singleton` + `Singleton { id: root }` root component (never `QtObject`).
- **Strong Typing**: Always declare explicit types (`list<string>`, `list<PwNode>`, `list<MprisPlayer>`, `list<BluetoothDevice>`, `list<WifiAccessPoint>`). Never declare untyped `property var` for collections or known objects.
- **Process Safety**:
  - Use `StdioCollector` for multi-line JSON or structured text.
  - Reset busy flags (`isUpdating = false`) in `onExited` handlers (including error codes).
  - Never dynamically create uncollected `Process` instances via `Qt.createQmlObject()`.
- **System access**: Prefer `Quickshell.Io.Process` with structured argument lists. Avoid `sh -c` string interpolation.
- **Async safety**: `Qt.callLater()` when modifying lists/models inside process handlers.
- **Self-init**: Services handle own lifecycle via `Component.onCompleted: update()`.
- **Safe Fallbacks**: Always provide safe fallback values (`available: device !== null`).

## ANTI-PATTERNS
- Overusing untyped `property var` when concrete types or typed lists are available.
- Wrapping internal child objects (`Connections`, `Timer`, `Process`) in `property var` declarations.
- Retaining obsolete compositor shims (e.g. Hyprland syntax in `dispatch()`, `HL_INITIAL_WORKSPACE_TOKEN`).
- Modifying list models synchronously inside `Process.onStdout` handlers.
- Leaving `isUpdating` flags stuck true when a process fails or exits with non-zero status.
