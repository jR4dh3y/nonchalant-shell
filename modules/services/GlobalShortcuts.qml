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
            case "system-monitor": Visibilities.toggleSystemMonitorForActive(); break;
            case "powermenu": Visibilities.setActiveModule("powermenu"); break;
            case "lockscreen": LockscreenService.lock(); break;
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
        const isActive = Visibilities.currentActiveModule === "launcher";
        if (isActive) {
            Visibilities.setActiveModule("");
        } else {
            GlobalStates.clearLauncherState();
            Visibilities.setActiveModule("launcher");
        }
    }
}
