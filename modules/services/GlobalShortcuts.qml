pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.globals
import qs.modules.services
import qs.config
import Quickshell.Io

Singleton {
    id: root

    readonly property string appId: "nonchalant"
    readonly property string ipcPipe: {
        const runtime = Quickshell.env("XDG_RUNTIME_DIR");
        if (runtime)
            return runtime + "/nonchalant_ipc.pipe";
        const cache = Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache";
        const display = (Quickshell.env("WAYLAND_DISPLAY") || "default").split("/").pop();
        return cache + "/nonchalant/ipc/" + display + ".pipe";
    }

    // High-performance Pipe Listener (Daemon mode)
    Process {
        id: pipeListener
        command: ["bash", "-c", "umask 077; mkdir -p -- \"$(dirname -- \"$1\")\" && rm -f -- \"$1\" && mkfifo -m 600 -- \"$1\" && exec tail -f -- \"$1\"", "nonchalant-ipc-listener", root.ipcPipe]
        running: true
        
        stdout: SplitParser {
            onRead: data => {
                const cmd = data.trim();
                if (cmd !== "") {
                    root.run(cmd);
                }
            }
        }
    }

    function run(command) {
        console.log("IPC run command received:", command);
        if (Config.bar?.style === "left") {
            const mode = ({ "system-monitor": "stats", resources: "stats", audio: "sound", microphone: "mic", network: "wifi", powerprofile: "battery", music: "media", player: "media" })[command] ?? command;
            if (["wifi", "bluetooth", "sound", "mic", "battery", "media", "stats"].indexOf(mode) !== -1) {
                const controller = Visibilities.getDashboardControllerForActive();
                if (controller)
                    controller.openControlMenu(mode);
                else
                    console.warn("GlobalShortcuts: no dashboard controller registered for the focused monitor");
                return;
            }
        }
        switch (command) {
            case "launcher": toggleLauncher(); break;
            case "projects":
            case "project-picker":
            case "projectpicker":
                toggleProjects();
                break;
            case "assistant":
            case "dashboard-assistant":
                toggleAssistant();
                break;
            case "system-monitor":
            case "stats":
            case "resources":
                Visibilities.toggleSystemMonitorForActive();
                break;
            case "wallpaper":
            case "wallpapers":
                toggleWallpapers();
                break;
            case "wallpaper-colors":
                GlobalStates.wallpaperManager?.setMatugenScheme("scheme-wallpaper");
                break;
            case "powermenu":
            case "power":
                Visibilities.togglePowerMenuForActive();
                break;
            case "alerts":
            case "notifications":
                toggleAlerts();
                break;
            case "dashboard": toggleDashboard(); break;
            case "bar-pin":
                Config.bar.pinned = !(Config.bar?.pinned ?? false);
                break;
            case "sound":
            case "audio":
                Visibilities.setActiveModule("sound");
                break;
            case "mic":
            case "microphone":
                Visibilities.setActiveModule("mic");
                break;
            case "wifi":
            case "network":
                Visibilities.setActiveModule("wifi");
                break;
            case "bluetooth":
                Visibilities.setActiveModule("bluetooth");
                break;
            case "battery":
            case "powerprofile":
                Visibilities.setActiveModule("battery");
                break;
            case "weather":
                Visibilities.setActiveModule("weather");
                break;
            case "calendar":
            case "datetime":
                Visibilities.setActiveModule("calendar");
                break;
            case "media":
            case "music":
            case "player":
                Visibilities.setActiveModule("media");
                break;
            case "lockscreen": LockscreenService.lock(); break;
            case "config":
            case "settings":
            case "dashboard-controls":
                toggleSettings();
                break;
            default: console.warn("Unknown IPC command:", command);
        }
    }

    property IpcHandler ipcHandler: IpcHandler {
        target: "nonchalant"

        function run(command: string) {
            root.run(command);
        }
    }

    // Launcher and project picker share one island page. Decide open/close
    // before touching launcherMode: changing it switches the island's mode.
    function toggleIslandLauncher(mode: string, clearState): bool {
        const island = Visibilities.isIslandStyle() ? Visibilities.getIslandForActive() : null;
        if (!island)
            return false;
        if (island.isExpanded && island.currentMode === mode) {
            island.collapse();
            return true;
        }
        Visibilities.collapseOtherIslands(island);
        GlobalStates.launcherMode = mode;
        clearState();
        // Switching apps <-> projects on an open launcher already expands
        // through IslandBar's launcherMode sync.
        if (island.currentMode !== mode)
            island.expand(mode);
        return true;
    }

    function toggleLauncher() {
        if (toggleIslandLauncher("apps", GlobalStates.clearLauncherState))
            return;

        const isActive = Visibilities.currentActiveModule === "launcher"
            && GlobalStates.launcherMode === "apps";
        if (isActive) {
            Visibilities.setActiveModule("");
        } else {
            GlobalStates.launcherMode = "apps";
            GlobalStates.clearLauncherState();
            Visibilities.setActiveModule("launcher");
        }
    }

    function toggleProjects() {
        if (toggleIslandLauncher("projects", GlobalStates.clearProjectPickerState))
            return;

        const isActive = Visibilities.currentActiveModule === "launcher"
            && GlobalStates.launcherMode === "projects";
        if (isActive) {
            Visibilities.setActiveModule("");
        } else {
            GlobalStates.launcherMode = "projects";
            GlobalStates.clearProjectPickerState();
            Visibilities.setActiveModule("launcher");
        }
    }

    function toggleWallpapers() {
        if (Visibilities.toggleIslandMode("wallpapers"))
            return;

        const controller = Visibilities.getDashboardControllerForActive();
        if (!controller) {
            console.warn("GlobalShortcuts: no dashboard controller registered for the focused monitor");
            return;
        }
        controller.toggleWallpapers();
    }

    function toggleAlerts() {
        if (Visibilities.toggleIslandMode("alerts"))
            return;
        Visibilities.setActiveModule("alerts");
    }

    function toggleDashboard() {
        if (Visibilities.toggleIslandMode("dashboard"))
            return;

        const controller = Visibilities.getDashboardControllerForActive();
        if (!controller) {
            console.warn("GlobalShortcuts: no dashboard controller registered for the focused monitor");
            return;
        }
        controller.toggleCenterMenu();
    }

    function toggleSettings(screenName) {
        const willOpen = !GlobalStates.settingsWindowVisible;
        if (willOpen) {
            FocusGrabManager.clearTopGrab();
            const targetMonitor = screenName
                ? CompositorService.monitorFor(screenName)
                : CompositorService.focusedMonitor;
            GlobalStates.settingsTargetWorkspaceId =
                targetMonitor?.activeWorkspace?.id
                || CompositorService.focusedMonitor?.activeWorkspace?.id
                || CompositorService.focusedWorkspace?.id
                || "";
            GlobalStates.settingsTargetScreenName =
                targetMonitor?.name || CompositorService.focusedMonitor?.name || "";
            // Close bar popups / run menu under the settings window.
            Visibilities.closeActiveBarPopup();
            Visibilities.setActiveModule("");
        }
        GlobalStates.settingsWindowVisible = willOpen;
    }

    function toggleAssistant() {
        if (!GlobalStates.assistantAvailable) {
            GlobalStates.hideAssistant();
            return;
        }
        GlobalStates.toggleAssistant();
    }
}
