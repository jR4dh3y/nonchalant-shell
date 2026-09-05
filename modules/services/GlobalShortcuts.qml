pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.globals
import qs.modules.services
import qs.config
import Quickshell.Io

QtObject {
    id: root

    readonly property string appId: "nonchalant"
    readonly property string ipcPipe: "/tmp/nonchalant_ipc.pipe"

    // High-performance Pipe Listener (Daemon mode)
    property Process pipeListener: Process {
        command: ["bash", "-c", "rm -f " + root.ipcPipe + "; mkfifo " + root.ipcPipe + "; tail -f " + root.ipcPipe]
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
            case "powermenu":
            case "power":
                Visibilities.togglePowerMenuForActive();
                break;
            case "alerts":
            case "notifications":
                toggleAlerts();
                break;
            case "dashboard": toggleDashboard(); break;
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

    function toggleLauncher() {
        if ((Config.bar?.style ?? "default") === "island") {
            const island = Visibilities.getIslandForActive();
            if (island) {
                if (island.isExpanded && island.currentMode === "apps") {
                    island.collapse();
                } else {
                    GlobalStates.launcherMode = "apps";
                    GlobalStates.clearLauncherState();
                    island.expand("apps");
                }
                return;
            }
        }

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
        if ((Config.bar?.style ?? "default") === "island") {
            const island = Visibilities.getIslandForActive();
            if (island) {
                if (island.isExpanded && island.currentMode === "projects") {
                    island.collapse();
                } else {
                    GlobalStates.launcherMode = "projects";
                    GlobalStates.clearProjectPickerState();
                    island.expand("projects");
                }
                return;
            }
        }

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
        if ((Config.bar?.style ?? "default") === "island") {
            const island = Visibilities.getIslandForActive();
            if (island) {
                if (island.isExpanded && island.currentMode === "wallpapers") {
                    island.collapse();
                } else {
                    Visibilities.clearAll();
                    Visibilities.currentActiveModule = "wallpapers";
                    island.expand("wallpapers");
                }
                return;
            }
        }

        const controller = Visibilities.getDashboardControllerForActive();
        if (!controller) {
            console.warn("GlobalShortcuts: no dashboard controller registered for the focused monitor");
            return;
        }
        controller.toggleWallpapers();
    }

    function toggleAlerts() {
        if ((Config.bar?.style ?? "default") === "island") {
            const island = Visibilities.getIslandForActive();
            if (island) {
                if (island.isExpanded && island.currentMode === "alerts") {
                    island.collapse();
                } else {
                    Visibilities.clearAll();
                    Visibilities.currentActiveModule = "alerts";
                    island.expand("alerts");
                }
                return;
            }
        }
        Visibilities.setActiveModule("alerts");
    }

    function toggleDashboard() {
        if ((Config.bar?.style ?? "default") === "island") {
            const island = Visibilities.getIslandForActive();
            if (island) {
                if (island.isExpanded && island.currentMode === "dashboard") {
                    island.collapse();
                } else {
                    Visibilities.clearAll();
                    Visibilities.currentActiveModule = "dashboard";
                    island.expand("dashboard");
                }
                return;
            }
        }

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
            const targetMonitor = screenName
                ? NiriService.monitorFor(screenName)
                : NiriService.focusedMonitor;
            GlobalStates.settingsTargetWorkspaceId =
                targetMonitor?.activeWorkspace?.id
                || NiriService.focusedMonitor?.activeWorkspace?.id
                || NiriService.focusedWorkspace?.id
                || 0;
            GlobalStates.settingsTargetScreenName =
                targetMonitor?.name || NiriService.focusedMonitor?.name || "";
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
