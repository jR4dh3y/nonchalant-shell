pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // wl-gammarelay-rs is already part of this system and works with Niri's
    // Wayland session. wlsunset cannot acquire gamma-control here.
    readonly property int minTemperature: 2500
    readonly property int maxTemperature: 6500
    property int temperature: 4500
    property int currentTemperature: maxTemperature
    property bool active: false
    property int pendingTemperature: -1
    readonly property real normalizedTemperature: (temperature - minTemperature) / (maxTemperature - minTemperature)

    function setTemperature(value) {
        const next = Math.max(minTemperature, Math.min(maxTemperature, Math.round(value / 100) * 100));
        root.temperature = next;
        if (StateService.initialized)
            StateService.set("nightLightTemperature", next);
        if (root.active)
            applyTemperature(next);
    }

    function setTemperatureFromNormalized(value) {
        setTemperature(minTemperature + Math.max(0, Math.min(1, value)) * (maxTemperature - minTemperature));
    }

    function applyTemperature(value) {
        const next = Math.max(minTemperature, Math.min(maxTemperature, Math.round(value / 100) * 100));
        if (setTemperatureProcess.running) {
            root.pendingTemperature = next;
            return;
        }
        root.pendingTemperature = -1;
        setTemperatureProcess.command = ["busctl", "--user", "set-property", "rs.wl-gammarelay", "/", "rs.wl.gammarelay", "Temperature", "q", String(next)];
        setTemperatureProcess.running = true;
        root.currentTemperature = next;
    }

    function toggle() {
        root.active = !root.active;
        if (root.active)
            applyTemperature(root.temperature);
        else
            applyTemperature(maxTemperature);
        if (StateService.initialized)
            StateService.set("nightLight", root.active);
    }

    function syncState() {
        if (!queryTemperatureProcess.running)
            queryTemperatureProcess.running = true;
    }

    Process {
        id: queryTemperatureProcess
        command: ["busctl", "--user", "get-property", "rs.wl-gammarelay", "/", "rs.wl.gammarelay", "Temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/(\d+)\s*$/);
                if (!match)
                    return;
                root.currentTemperature = Number(match[1]);
                root.active = root.currentTemperature < root.maxTemperature - 50;
            }
        }
    }

    Process {
        id: setTemperatureProcess
        command: []
        onExited: {
            if (root.pendingTemperature >= 0) {
                const next = root.pendingTemperature;
                root.pendingTemperature = -1;
                Qt.callLater(() => root.applyTemperature(next));
            } else {
                root.syncState();
            }
        }
    }

    onActiveChanged: {
        if (StateService.initialized) {
            StateService.set("nightLight", active);
        }
    }

    Connections {
        target: StateService
        function onStateLoaded() {
            root.active = StateService.get("nightLight", false);
            root.temperature = StateService.get("nightLightTemperature", root.temperature);
            root.syncState();
        }
    }

    // Auto-initialize on creation
    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            if (StateService.initialized) {
                root.temperature = StateService.get("nightLightTemperature", root.temperature);
                root.active = StateService.get("nightLight", false);
                root.syncState();
            }
        }
    }
}
