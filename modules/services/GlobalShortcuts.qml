pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.globals
import qs.modules.services
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
            case "system-monitor": Visibilities.toggleSystemMonitorForActive(); break;
            case "powermenu": Visibilities.togglePowerMenuForActive(); break;
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
        GlobalStates.toggleAssistant();
    }
}
