import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string address: ""
    property string name: "Unknown"
    property string icon: "bluetooth"
    property bool paired: false
    property bool connected: false
    property bool trusted: false
    property int battery: -1
    property bool batteryAvailable: battery >= 0
    property bool connecting: false
    property bool pairing: false
    // bluetoothctl's error from the last failed pair; cleared on the next try.
    property string pairError: ""

    signal infoUpdated()

    // Connect a paired device, trusting it first so it can reconnect alone.
    function connect() {
        connecting = true;
        const p = trusted
            ? BluetoothService.connectDevice(address)
            : BluetoothService.trustDevice(address).then(() => BluetoothService.connectDevice(address));

        return p.catch(e => {
            console.error(`Failed to connect to ${address}: ${e}`);
        }).finally(() => {
            connecting = false;
            updateInfo();
        });
    }

    function updateInfo() {
        return BluetoothService.runAsync(["bluetoothctl", "info", address]).then(text => {
            Qt.callLater(() => {
                const lines = text.split("\n");
                for (const line of lines) {
                    const trimmed = line.trim();
                    if (trimmed.startsWith("Paired:")) {
                        root.paired = trimmed.includes("yes");
                    } else if (trimmed.startsWith("Connected:")) {
                        root.connected = trimmed.includes("yes");
                        if (root.connected) root.connecting = false;
                    } else if (trimmed.startsWith("Trusted:")) {
                        root.trusted = trimmed.includes("yes");
                    } else if (trimmed.startsWith("Icon:")) {
                        root.icon = trimmed.split(":")[1]?.trim() || "bluetooth";
                    } else if (trimmed.startsWith("Battery Percentage:")) {
                        const match = trimmed.match(/\((\d+)\)/);
                        if (match) {
                            root.battery = parseInt(match[1]) || -1;
                        }
                    }
                }
                root.infoUpdated();
            });
        }).catch(e => {
            console.error(`Failed to get info for ${address}: ${e}`);
        });
    }

    function disconnect() {
        BluetoothService.disconnectDevice(address);
    }

    // Pair, trust and connect a device found by discovery.
    function pair() {
        if (pairing)
            return;
        pairing = true;
        pairError = "";
        BluetoothService.pairDevice(address).catch(e => {
            const lines = String(e).split("\n").filter(line => line.trim() !== "");
            root.pairError = lines.length > 0 ? lines[lines.length - 1].trim() : "Pairing failed";
            console.warn(`Failed to pair ${address}: ${e}`);
        }).finally(() => {
            root.pairing = false;
            root.updateInfo();
        });
    }

    function trust() {
        BluetoothService.trustDevice(address).catch(e => console.warn(`Failed to trust ${address}: ${e}`));
    }

    function forget() {
        BluetoothService.removeDevice(address);
    }
}
