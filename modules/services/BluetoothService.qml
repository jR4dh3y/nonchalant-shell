pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

Singleton {
    id: root

    property bool enabled: false
    property bool discovering: false
    property bool connected: false
    property int connectedDevices: 0
    property string firstConnectedDeviceName: ""
    
    readonly property list<BluetoothDevice> devices: []
    
    // Cached sorted device list - only updates when devices change
    property list<var> friendlyDeviceList: []
    
    // Queue for batching updateInfo calls
    property var pendingInfoUpdates: []
    property bool isProcessingInfoQueue: false
    property bool isUpdating: false
    property bool wasEnabledBeforeSleep: false

    Connections {
        id: suspendConnections
        target: SuspendManager
        function onPreparingForSleep() {
            root.wasEnabledBeforeSleep = root.enabled;
            if (discovering) {
                root.stopDiscovery();
            }
            scanTimer.stop();
            infoQueueTimer.stop();
        }
        function onWakingUp() {
            // Re-sync status after wake
            wakeSyncTimer.restart();

            // Restore state if it was enabled
            if (root.wasEnabledBeforeSleep) {
                root.setEnabled(true);
            }
        }
    }

    Timer {
        id: wakeSyncTimer
        interval: 3000
        repeat: false
        onTriggered: {
            root.updateStatus();
            if (root.enabled) {
                root.updateDevices();
            }
        }
    }

    function updateFriendlyList() {
        friendlyDeviceList = [...devices].sort((a, b) => {
            // Connected devices first
            if (a.connected && !b.connected) return -1;
            if (!a.connected && b.connected) return 1;
            // Then paired devices
            if (a.paired && !b.paired) return -1;
            if (!a.paired && b.paired) return 1;
            // Then by name
            return (a.name || "").localeCompare(b.name || "");
        });

        // Also cross-check connected status from devices list
        let connectedCount = 0;
        let firstName = "";
        for (let i = 0; i < devices.length; i++) {
            const d = devices[i];
            if (d && d.connected) {
                connectedCount++;
                if (!firstName && d.name) {
                    firstName = d.name;
                }
            }
        }
        if (connectedCount > 0) {
            root.connected = true;
            root.connectedDevices = Math.max(root.connectedDevices, connectedCount);
            if (firstName) {
                root.firstConnectedDeviceName = firstName;
            }
        }
    }

    function onDeviceInfoUpdated(): void {
        updateFriendlyList();
    }

    // Batch process info updates with delay between each
    function queueInfoUpdate(device: BluetoothDevice) {
        if (pendingInfoUpdates.indexOf(device) === -1) {
            pendingInfoUpdates.push(device);
        }
        if (!isProcessingInfoQueue) {
            processNextInfoUpdate();
        }
    }

    function processNextInfoUpdate() {
        if (pendingInfoUpdates.length === 0) {
            isProcessingInfoQueue = false;
            updateFriendlyList();
            return;
        }
        
        isProcessingInfoQueue = true;
        const device = pendingInfoUpdates.shift();
        if (device) {
            device.updateInfo();
        }
        // Process next after a small delay
        infoQueueTimer.restart();
    }

    Timer {
        id: infoQueueTimer
        interval: 50  // 50ms between each info request
        running: false
        repeat: false
        onTriggered: {
            if (!SuspendManager.isSuspending) {
                root.processNextInfoUpdate();
            }
        }
    }

    Component {
        id: asyncProcessComp
        Process {
            id: internalProc
            property var resolve
            property var reject
            property string buffer: ""
            property string errorBuffer: ""
            
            stdout: SplitParser {
                onRead: data => internalProc.buffer += data + "\n"
            }
            
            stderr: SplitParser {
                onRead: data => internalProc.errorBuffer += data + "\n"
            }
            
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) resolve(buffer.trim());
                else reject(errorBuffer.trim() || `Process exited with code ${exitCode}`);
                destroy();
            }
        }
    }

    function runAsync(command, environment = {}) {
        return new Promise((resolve, reject) => {
            const proc = asyncProcessComp.createObject(root, {
                command: command,
                environment: environment,
                resolve: resolve,
                reject: reject
            });
            proc.running = true;
        });
    }

    // Control functions
    function setEnabled(value: bool): void {
        if (SuspendManager.isSuspending) return;
        isUpdating = true;
        runAsync(["bluetoothctl", "power", value ? "on" : "off"]).then(() => {
            updateStatus();
            if (value) updateDevices();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function toggle(): void {
        setEnabled(!enabled);
    }

    function startDiscovery(): void {
        if (enabled && !SuspendManager.isSuspending) {
            discovering = true;
            runAsync(["bluetoothctl", "scan", "on"]).then(() => {
                scanTimer.restart();
            }).catch(e => {
                discovering = false;
            });
        }
    }

    function stopDiscovery(): void {
        discovering = false;
        runAsync(["bluetoothctl", "scan", "off"]).then(() => {
            scanTimer.stop();
        }).catch(e => {});
    }

    function connectDevice(address: string): void {
        isUpdating = true;
        runAsync(["bluetoothctl", "connect", address]).then(() => {
            updateDevices();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function disconnectDevice(address: string): void {
        isUpdating = true;
        runAsync(["bluetoothctl", "disconnect", address]).then(() => {
            updateDevices();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function pairDevice(address: string): void {
        isUpdating = true;
        runAsync(["bluetoothctl", "pair", address]).then(() => {
            updateDevices();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function trustDevice(address: string): void {
        runAsync(["bluetoothctl", "trust", address]).catch(e => {});
    }

    function removeDevice(address: string): void {
        isUpdating = true;
        runAsync(["bluetoothctl", "remove", address]).then(() => {
            updateDevices();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    Timer {
        id: updateDebouncer
        interval: 150
        repeat: false
        onTriggered: root.performUpdate()
    }

    Timer {
        id: devicesDebouncer
        interval: 300
        repeat: false
        onTriggered: {
            if (root.enabled)
                root.updateDevices();
        }
    }

    function updateStatus() {
        updateDebouncer.restart();
    }

    function performUpdate() {
        if (isUpdating) return;
        isUpdating = true;
        checkStatusProcess.buffer = "";
        checkStatusProcess.running = true;
    }

    // Live DBus signal monitor: instant response when devices connect/disconnect or adapter power changes
    Process {
        id: dbusMonitorProcess
        command: ["stdbuf", "-oL", "gdbus", "monitor", "--system", "-d", "org.bluez"]
        running: !SuspendManager.isSuspending
        stdout: SplitParser {
            onRead: (data) => {
                if (data && (data.includes("Connected") || data.includes("Powered") || data.includes("PropertiesChanged") || data.includes("InterfacesAdded") || data.includes("InterfacesRemoved"))) {
                    updateDebouncer.restart();
                    devicesDebouncer.restart();
                }
            }
        }
    }

    // Periodic poll every 3 seconds
    Timer {
        id: updateTimer
        interval: 3000
        running: !SuspendManager.isSuspending
        repeat: true
        onTriggered: {
            root.updateStatus();
            if (root.enabled) {
                root.updateDevices();
            }
        }
    }

    Timer {
        id: scanTimer
        interval: 15000
        running: false
        repeat: false
        onTriggered: root.stopDiscovery()
    }

    // Unified single-process status and connected device extraction
    Process {
        id: checkStatusProcess
        command: ["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'powered' || echo 'off'; echo '---'; bluetoothctl devices Connected"]
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: (data) => {
                checkStatusProcess.buffer += data + "\n";
            }
        }
        onExited: (code) => {
            const text = checkStatusProcess.buffer.trim();
            checkStatusProcess.buffer = "";
            root.isUpdating = false;
            if (code !== 0 || !text)
                return;
            const parts = text.split("---");
            const powerPart = parts[0].trim();
            root.enabled = (powerPart === "powered");
            if (!root.enabled) {
                root.connected = false;
                root.connectedDevices = 0;
                root.firstConnectedDeviceName = "";
                root.discovering = false;
                return;
            }
            const connectedLines = parts.length > 1
                ? parts[1].trim().split("\n").filter(l => l.startsWith("Device "))
                : [];
            root.connectedDevices = connectedLines.length;
            root.connected = connectedLines.length > 0;
            if (connectedLines.length > 0) {
                const devParts = connectedLines[0].split(" ");
                root.firstConnectedDeviceName = devParts.slice(2).join(" ") || "Connected";
            } else {
                root.firstConnectedDeviceName = "";
            }
            root.updateFriendlyList();
        }
    }


    function updateDevices() {
        getDevicesProcess.running = true;
    }

    Process {
        id: getDevicesProcess
        command: ["bash", "-c", "bluetoothctl devices"]
        running: false
        property string buffer: ""
        environment: ({
            LANG: "C.UTF-8",
            LC_ALL: "C.UTF-8"
        })
        stdout: SplitParser {
            onRead: data => {
                getDevicesProcess.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            const text = getDevicesProcess.buffer;
            getDevicesProcess.buffer = "";
            
            Qt.callLater(() => {
                const deviceLines = text.trim().split("\n").filter(l => l.startsWith("Device "));
                const deviceDataList = [];
                for (let i = 0; i < deviceLines.length; i++) {
                    const line = deviceLines[i];
                    const parts = line.split(" ");
                    if (parts.length < 2) continue;
                    deviceDataList.push({
                        address: parts[1],
                        name: parts.slice(2).join(" ") || "Unknown"
                    });
                }

                const rDevices = root.devices;
                
                // 1. Remove gone devices
                for (let i = rDevices.length - 1; i >= 0; i--) {
                    const rd = rDevices[i];
                    if (!deviceDataList.find(d => d.address === rd.address)) {
                        rDevices.splice(i, 1);
                        rd.destroy();
                    }
                }
                
                // 2. Add or update devices
                for (let i = 0; i < deviceDataList.length; i++) {
                    const data = deviceDataList[i];
                    const existing = rDevices.find(d => d.address === data.address);
                    if (existing) {
                        if (existing.name !== data.name) {
                            existing.name = data.name;
                        }
                        root.queueInfoUpdate(existing);
                    } else {
                        const newDevice = deviceComp.createObject(root, {
                            address: data.address,
                            name: data.name
                        });
                        newDevice.infoUpdated.connect(root.onDeviceInfoUpdated);
                        rDevices.push(newDevice);
                        root.queueInfoUpdate(newDevice);
                    }
                }
                
                if (deviceDataList.length === 0) {
                    root.updateFriendlyList();
                }
            });
        }
    }

    Component {
        id: deviceComp
        BluetoothDevice {}
    }

    property bool _initialized: false

    function initialize() {
        if (_initialized) return;
        _initialized = true;
        updateStatus();
    }
}
