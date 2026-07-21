pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string driver: "unknown"
    readonly property bool nvidiaActive: driver === "nvidia"
    readonly property bool vfioActive: driver === "vfio-pci"
    readonly property bool switching: switchProcess.running
    readonly property string modeLabel: switching ? "Switching…" : (nvidiaActive ? "PRIME / NVIDIA" : (vfioActive ? "VFIO" : (driver === "amdgpu" ? "AMD integrated" : driver)))

    function refresh() {
        if (!statusProcess.running)
            statusProcess.running = true;
    }

    function switchTo(mode) {
        if (switchProcess.running)
            return;
        switchProcess.command = ["pkexec", mode === "nvidia" ? "/usr/local/sbin/gpu-to-nvidia" : "/usr/local/sbin/gpu-to-vfio"];
        switchProcess.running = true;
    }

    function toggle() {
        switchTo(nvidiaActive ? "vfio" : "nvidia");
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
        id: switchProcess
        command: []
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.warn("GPU switch:", text.trim());
            }
        }
        onExited: root.refresh()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
