pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string driver: "unknown"
    property string vmState: "unknown"
    property string lastError: ""
    readonly property bool nvidiaActive: driver === "nvidia"
    readonly property bool vfioActive: driver === "vfio-pci"
    readonly property bool vmRunning: vmState === "running" || vmState === "paused"
    readonly property bool switching: switchProcess.running || actionProcess.running
    readonly property string modeLabel: switching ? "Switching…" : (nvidiaActive ? "PRIME / NVIDIA" : (vfioActive ? "VFIO" : (driver === "amdgpu" ? "AMD integrated" : driver)))
    readonly property string vmStateLabel: {
        if (vmState === "shut off")
            return "Off";
        if (vmState === "running")
            return "Running";
        if (vmState === "paused")
            return "Paused";
        return vmState;
    }
    property bool hasVirsh: false
    readonly property string gpuSwitchScript: Quickshell.env("HOME") + "/.config/scripts/waybar-gpu-switch.sh"

    function refresh() {
        if (!statusProcess.running)
            statusProcess.running = true;
        if (root.hasVirsh && !vmStatusProcess.running)
            vmStatusProcess.running = true;
    }

    function switchTo(mode) {
        if (root.switching)
            return;
        root.lastError = "";
        switchProcess.command = ["pkexec", mode === "nvidia" ? "/usr/local/sbin/gpu-to-nvidia" : "/usr/local/sbin/gpu-to-vfio"];
        switchProcess.running = true;
    }

    function toggle() {
        switchTo(nvidiaActive ? "vfio" : "nvidia");
    }

    function runWaybarAction(action) {
        if (root.switching)
            return;
        root.lastError = "";
        actionProcess.command = [root.gpuSwitchScript, action];
        actionProcess.running = true;
    }

    function switchToLinux() {
        runWaybarAction("to-linux");
    }

    function toggleVm() {
        runWaybarAction("toggle-vm");
    }

    function openLookingGlass() {
        if (!root.vmRunning || lookingGlassDisplayProcess.running)
            return;
        lookingGlassDisplayProcess.running = true;
    }

    function openVirtManager() {
        Quickshell.execDetached(["virt-manager"]);
    }

    function openStatus() {
        Quickshell.execDetached([
            "kitty",
            "--app-id=sysadmin",
            "--title=GPU switch status",
            "sh",
            "-lc",
            "gpu-status; printf '\\nPress Enter to close...'; read -r _"
        ]);
    }

    Process {
        id: statusProcess
        command: ["bash", "-c", "basename \"$(readlink -f /sys/bus/pci/devices/0000:01:00.0/driver 2>/dev/null)\" 2>/dev/null || echo none"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim();
                root.driver = value.length > 0 ? value : "none";
            }
        }
    }

    Process {
        id: vmStatusProcess
        command: ["virsh", "-c", "qemu:///system", "domstate", "win10-rtx3050"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim();
                root.vmState = value.length > 0 ? value : "unknown";
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.vmState = "unavailable";
        }
    }

    Process {
        id: switchProcess
        command: []
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.warn("GPU switch:", text.trim());
            }
        }
        onExited: refreshTimer.restart()
    }

    Process {
        id: actionProcess
        command: []
        stderr: StdioCollector {
            onStreamFinished: {
                const value = text.trim();
                if (value.length > 0) {
                    root.lastError = value;
                    console.warn("GPU action:", value);
                }
            }
        }
        onExited: refreshTimer.restart()
    }

    Process {
        id: lookingGlassDisplayProcess
        command: ["virsh", "-c", "qemu:///system", "domdisplay", "win10-rtx3050", "--type", "spice"]
        stdout: StdioCollector {
            onStreamFinished: {
                const display = text.trim();
                const match = display.match(/:([0-9]+)$/);
                const port = match ? match[1] : "5900";
                Quickshell.execDetached([
                    "looking-glass-client",
                    "-F",
                    "app:shmFile=/dev/shm/looking-glass",
                    "spice:host=127.0.0.1",
                    "spice:port=" + port,
                    "spice:input=yes",
                    "spice:clipboard=yes",
                    "spice:captureOnStart=yes",
                    "input:captureOnFocus=yes",
                    "input:escapeKey=KEY_RIGHTCTRL"
                ]);
            }
        }
    }

    Process {
        id: probeVirshProcess
        command: ["sh", "-c", "command -v virsh >/dev/null 2>&1"]
        onExited: exitCode => {
            root.hasVirsh = (exitCode === 0);
            if (root.hasVirsh) {
                if (!vmStatusProcess.running)
                    vmStatusProcess.running = true;
            } else {
                root.vmState = "unavailable";
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 1000
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        probeVirshProcess.running = true;
        root.refresh();
    }
}
