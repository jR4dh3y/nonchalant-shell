pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.theme

Singleton {
    id: root

    property bool wifi: true
    property bool ethernet: false

    property bool wifiEnabled: false
    property bool wifiScanning: false
    property real lastScanTime: 0
    property bool wifiConnecting: isUpdating && wifiStatus === "connecting"
    property bool isUpdating: false
    property bool wasEnabledBeforeSleep: false

    Connections {
        id: suspendConnections
        target: SuspendManager
        function onPreparingForSleep() {
            root.wasEnabledBeforeSleep = root.wifiEnabled;
        }
        function onWakingUp() {
            if (root.wasEnabledBeforeSleep) {
                root.enableWifi(true);
            }
        }
    }

    property WifiAccessPoint wifiConnectTarget: null
    readonly property list<WifiAccessPoint> wifiNetworks: []
    property WifiAccessPoint active: null

    function updateActive() {
        for (let i = 0; i < wifiNetworks.length; i++) {
            if (wifiNetworks[i].active) {
                active = wifiNetworks[i];
                return;
            }
        }
        active = null;
    }

    property string wifiStatus: "disconnected"

    property string activeSsid: ""
    property string networkName: ""
    readonly property bool wifiConnected: wifiEnabled && (wifiStatus === "connected" || wifiStatus === "limited") && activeSsid !== ""
    property int networkStrength: 0

    property list<var> friendlyWifiNetworks: []

    function updateFriendlyList() {
        friendlyWifiNetworks = [...wifiNetworks].sort((a, b) => {
            if (a.active && !b.active)
                return -1;
            if (!a.active && b.active)
                return 1;
            return b.strength - a.strength;
        });
        updateActive();
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

    function enableWifi(enabled = true): void {
        isUpdating = true;
        const cmd = enabled ? "on" : "off";
        runAsync(["nmcli", "radio", "wifi", cmd]).then(() => {
            update();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function toggleWifi(): void {
        enableWifi(!wifiEnabled);
    }

    function rescanWifi(): void {
        const now = Date.now();
        if (now - lastScanTime < 3000) { // 3s throttle
            update();
            return;
        }
        
        lastScanTime = now;
        wifiScanning = true;
        runAsync(["nmcli", "dev", "wifi", "list", "--rescan", "yes"]).then(() => {
            wifiScanning = false;
            update();
        }).catch(e => {
            wifiScanning = false;
            update();
        });
    }

    function connectToWifiNetwork(accessPoint: WifiAccessPoint): void {
        accessPoint.askingPassword = false;
        root.wifiConnectTarget = accessPoint;
        isUpdating = true;
        runAsync(["nmcli", "dev", "wifi", "connect", accessPoint.ssid]).then(() => {
            getNetworks.running = true;
            root.wifiConnectTarget = null;
            isUpdating = false;
        }).catch(e => {
            if (e.includes("Secrets were required")) {
                accessPoint.askingPassword = true;
            }
            root.wifiConnectTarget = null;
            isUpdating = false;
        });
    }

    function disconnectWifiNetwork(): void {
        if (active) {
            isUpdating = true;
            runAsync(["nmcli", "connection", "down", active.ssid]).then(() => {
                getNetworks.running = true;
                isUpdating = false;
            }).catch(e => {
                isUpdating = false;
            });
        }
    }

    function changePassword(network: WifiAccessPoint, password: string): void {
        network.askingPassword = false;
        isUpdating = true;
        runAsync(["bash", "-c", `nmcli connection modify "${network.ssid}" wifi-sec.psk "$PASSWORD"`], { "PASSWORD": password }).then(() => {
            connectToWifiNetwork(network);
        }).then(() => {
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"]);
    }

    // WiFi icon by strength
    function wifiIconForStrength(strength: int): string {
        if (strength > 80) return Icons.wifiHigh;
        if (strength > 55) return Icons.wifiMedium;
        if (strength > 30) return Icons.wifiLow;
        if (strength > 0) return Icons.wifiNone;
        return Icons.wifiOff;
    }

    property bool _isUpdatingProcess: false
    property bool _hasPendingUpdate: false

    // Fast debounce for incoming events
    Timer {
        id: updateDebouncer
        interval: 100
        repeat: false
        onTriggered: root.performUpdate()
    }

    // Periodic sync timer to ensure bar data never stays stale
    Timer {
        id: periodicTimer
        interval: 2500
        running: !SuspendManager.isSuspending
        repeat: true
        onTriggered: root.update()
    }

    function update() {
        updateDebouncer.restart();
    }

    function performUpdate() {
        if (_isUpdatingProcess) {
            _hasPendingUpdate = true;
            return;
        }

        _isUpdatingProcess = true;
        _hasPendingUpdate = false;
        checkNetworkProcess.buffer = "";
        checkNetworkProcess.running = true;
    }

    // Live monitor for NetworkManager events
    Process {
        id: subscriber
        running: !SuspendManager.isSuspending
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.update()
        }
    }

    // Unified single-process network status and scan results reader
    Process {
        id: checkNetworkProcess
        command: ["bash", "-c", "nmcli radio wifi; echo '---'; nmcli -t -f TYPE,STATE,CONNECTION d status; echo '---'; nmcli -t -f CONNECTIVITY g; echo '---'; nmcli -g ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY d w || true"]
        running: false
        property string buffer: ""
        environment: ({
            LANG: "C.UTF-8",
            LC_ALL: "C.UTF-8"
        })

        stdout: SplitParser {
            onRead: data => {
                checkNetworkProcess.buffer += data + "\n";
            }
        }

        onExited: (exitCode, exitStatus) => {
            const text = checkNetworkProcess.buffer;
            checkNetworkProcess.buffer = "";

            try {
                if (exitCode !== 0 && text.length === 0) {
                    return;
                }

                const sections = text.split("---");
                if (sections.length < 3) {
                    return;
                }

                // Section 0: Radio status
                const radioText = (sections[0] || "").trim();
                const wifiEnabled = (radioText === "enabled");
                root.wifiEnabled = wifiEnabled;

                // Section 1: Device statuses
                const deviceLines = (sections[1] || "").trim().split("\n");
                let hasEthernet = false;
                let hasWifi = false;
                let rawWifiState = "disconnected";
                let wifiConnName = "";

                for (let i = 0; i < deviceLines.length; i++) {
                    const dLine = deviceLines[i].trim();
                    if (!dLine) continue;
                    const parts = dLine.split(":");
                    const devType = parts[0] || "";
                    const devState = parts[1] || "";
                    const devConn = parts.slice(2).join(":") || "";

                    if (devType === "ethernet" && devState.includes("connected")) {
                        hasEthernet = true;
                    } else if (devType === "wifi") {
                        rawWifiState = devState;
                        wifiConnName = devConn;
                        if (devState.includes("connected")) {
                            hasWifi = true;
                        }
                    }
                }

                // Section 2: Connectivity
                const connectivity = (sections[2] || "").trim();

                // Compute wifiStatus
                let computedWifiStatus = "disconnected";
                if (!wifiEnabled || rawWifiState.includes("unavailable")) {
                    computedWifiStatus = "disabled";
                } else if (rawWifiState.includes("connecting")) {
                    computedWifiStatus = "connecting";
                } else if (hasWifi) {
                    if (connectivity === "limited" || connectivity === "portal") {
                        computedWifiStatus = "limited";
                    } else {
                        computedWifiStatus = "connected";
                    }
                } else {
                    computedWifiStatus = "disconnected";
                }

                root.wifiStatus = computedWifiStatus;
                root.ethernet = hasEthernet;
                root.wifi = hasWifi;

                // Section 3: Cached Wi-Fi scan results (d w)
                const scanText = (sections[3] || "").trim();
                const networkMap = new Map();
                let activeFromScan = null;

                if (scanText.length > 0 && wifiEnabled) {
                    const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
                    const rep = /\\:/g;
                    const rep2 = new RegExp(PLACEHOLDER, "g");
                    const lines = scanText.split("\n");

                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i].replace(rep, PLACEHOLDER);
                        const net = line.split(":");
                        if (net.length < 6) continue;

                        const ssid = net[3] || "";
                        if (!ssid) continue;

                        const isActive = (net[0] === "yes");
                        const itemStrength = parseInt(net[1]) || 0;
                        const network = {
                            active: isActive,
                            strength: itemStrength,
                            frequency: parseInt(net[2]) || 0,
                            ssid: ssid,
                            bssid: (net[4] || "").replace(rep2, ":"),
                            security: net[5] || ""
                        };

                        if (isActive) {
                            activeFromScan = network;
                        }

                        const existing = networkMap.get(ssid);
                        if (!existing || (network.active && !existing.active) || (!network.active && !existing.active && network.strength > existing.strength)) {
                            networkMap.set(ssid, network);
                        }
                    }
                }

                // Determine active SSID and signal strength
                if (computedWifiStatus === "connected" || computedWifiStatus === "limited") {
                    const effectiveSsid = (activeFromScan && activeFromScan.ssid) ? activeFromScan.ssid : wifiConnName;
                    root.activeSsid = effectiveSsid;
                    root.networkName = effectiveSsid;
                    root.networkStrength = activeFromScan ? activeFromScan.strength : (root.networkStrength > 0 ? root.networkStrength : 100);
                } else {
                    root.activeSsid = "";
                    root.networkName = "";
                    root.networkStrength = 0;
                }

                // Sync wifiNetworks list
                const wifiNetworksData = Array.from(networkMap.values());
                const rNetworks = root.wifiNetworks;

                // 1. Remove gone networks
                for (let i = rNetworks.length - 1; i >= 0; i--) {
                    const rn = rNetworks[i];
                    const found = wifiNetworksData.find(n => n.frequency === rn.frequency && n.ssid === rn.ssid && n.bssid === rn.bssid);
                    if (!found) {
                        rNetworks.splice(i, 1);
                        rn.destroy();
                    }
                }

                // 2. Add or update networks
                for (let i = 0; i < wifiNetworksData.length; i++) {
                    const data = wifiNetworksData[i];
                    const existing = rNetworks.find(n => n.frequency === data.frequency && n.ssid === data.ssid && n.bssid === data.bssid);
                    if (existing) {
                        existing.lastIpcObject = data;
                    } else {
                        rNetworks.push(apComp.createObject(root, {
                            lastIpcObject: data
                        }));
                    }
                }

                root.updateFriendlyList();
            } catch (e) {
                console.warn("NetworkService: Error parsing network status:", e);
            } finally {
                root._isUpdatingProcess = false;
                if (root._hasPendingUpdate) {
                    root._hasPendingUpdate = false;
                    root.performUpdate();
                }
            }
        }
    }

    Component {
        id: apComp
        WifiAccessPoint {}
    }

    Component.onCompleted: {
        update();
    }
}
