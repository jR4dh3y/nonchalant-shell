pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

ColumnLayout {
    id: root
    property bool bluetooth: false
    property bool ownsDiscovery: false
    signal settingsRequested(string page)
    signal tabRequested(string tab)
    spacing: Styling.fontSize(0) * 0.5

    function stopDiscovery(): void {
        if (root.ownsDiscovery) {
            BluetoothService.stopDiscovery();
            root.ownsDiscovery = false;
        }
    }
    onVisibleChanged: if (!visible) stopDiscovery()
    onBluetoothChanged: if (!bluetooth) stopDiscovery()
    Component.onDestruction: stopDiscovery()
    DeckCard {
        objectName: "deckConnectionToolbar"
        Layout.fillWidth: true
        order: 0
        padding: Styling.fontSize(0) * 0.4
        RowLayout {
            Layout.fillWidth: true
            spacing: Styling.fontSize(0) * 0.2
            DeckAction {
                objectName: "deckConnectionWifi"
                glyph: Icons.wifiHigh
                label: "Wi-Fi"
                accent: true
                selected: !root.bluetooth
                onClicked: if (root.bluetooth) root.tabRequested("wifi")
            }
            DeckAction {
                objectName: "deckConnectionBluetooth"
                glyph: Icons.bluetooth
                label: "Bluetooth"
                accent: true
                selected: root.bluetooth
                onClicked: if (!root.bluetooth) root.tabRequested("bluetooth")
            }
            Item { Layout.fillWidth: true }
            DeckAction {
                objectName: "deckRadioToggle"
                label: (root.bluetooth ? BluetoothService.enabled : NetworkService.wifiEnabled) ? "On" : "Off"
                selected: root.bluetooth ? BluetoothService.enabled : NetworkService.wifiEnabled
                accent: true
                description: "Turn " + (root.bluetooth ? "Bluetooth" : "Wi-Fi") + (selected ? " off" : " on")
                enabled: root.bluetooth ? !BluetoothService.isUpdating : !NetworkService.isUpdating
                onClicked: root.bluetooth ? BluetoothService.toggle() : NetworkService.toggleWifi()
            }
            DeckAction {
                objectName: "deckConnectionScan"
                kind: DeckAction.Icon
                glyph: Icons.sync
                description: "Scan for " + (root.bluetooth ? "Bluetooth devices" : "Wi-Fi networks")
                enabled: root.bluetooth ? BluetoothService.enabled && !BluetoothService.discovering
                    : NetworkService.wifiEnabled && !NetworkService.wifiScanning
                onClicked: {
                    if (root.bluetooth) {
                        root.ownsDiscovery = !BluetoothService.discovering;
                        BluetoothService.startDiscovery();
                    } else NetworkService.rescanWifi();
                }
            }
            DeckAction {
                objectName: "deckConnectionSettings"
                kind: DeckAction.Icon
                glyph: Icons.arrowSquareOut
                description: "Advanced " + (root.bluetooth ? "Bluetooth" : "network") + " settings"
                onClicked: root.settingsRequested(root.bluetooth ? "bluetooth" : "network")
            }
        }
    }
    DeckCard {
        objectName: "deckConnectionCurrent"
        Layout.fillWidth: true
        order: 1
        title: "Current"
        glyph: root.bluetooth ? Icons.bluetooth : NetworkService.ethernet ? Icons.ethernet : Icons.wifiHigh
        StyledText {
            Layout.fillWidth: true
            // Status only stands in for an empty connection; scans don't push it in.
            visible: root.bluetooth ? connectedDevices.devices.length === 0 : connectedNetworks.networks.length === 0
            text: root.bluetooth ? (BluetoothService.discovering ? "Looking for devices…" : BluetoothService.enabled ? "No device connected" : "Bluetooth is turned off")
                : NetworkService.ethernet ? "Ethernet connected"
                : NetworkService.wifiConnecting ? "Connecting…" : NetworkService.wifiScanning ? "Looking for networks…"
                : NetworkService.wifiEnabled ? "Not connected" : "Wi-Fi is turned off"
            wrapMode: Text.WordWrap
            color: Colors.overSurfaceVariant
            font.pixelSize: Styling.fontSize(-1)
        }
        DeckSection {
            id: connectedNetworks
            objectName: "deckConnectedNetworks"
            readonly property list<WifiAccessPoint> networks: NetworkService.wifiNetworks.filter(network => network.active)
            visible: !root.bluetooth && networks.length > 0
            Layout.fillWidth: true
            Repeater { model: connectedNetworks.networks; delegate: DeckNetworkRow { viewport: networkList } }
        }
        DeckSection {
            id: connectedDevices
            readonly property list<BluetoothDevice> devices: BluetoothService.devices.filter(device => device.connected)
            visible: root.bluetooth && devices.length > 0
            Layout.fillWidth: true
            Repeater { model: connectedDevices.devices; delegate: DeckBluetoothRow {} }
        }
    }
    DeckCard {
        objectName: "deckConnectionAvailable"
        Layout.fillWidth: true
        Layout.fillHeight: true
        order: 2
        title: root.bluetooth ? (BluetoothService.discovering ? "Devices · Scanning…" : "Devices")
            : NetworkService.wifiScanning ? "Available networks · Scanning…" : "Available networks"
        // The card heading stays fixed; only the list below it scrolls.
        ScrollView {
            id: networkList
            objectName: "deckNetworkList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ColumnLayout {
                width: networkList.availableWidth
                spacing: Styling.fontSize(0) * 0.6
                DeckSection {
                    id: availableNetworks
                    objectName: "deckAvailableNetworks"
                    readonly property list<WifiAccessPoint> networks: NetworkService.wifiNetworks.filter(network => !network.active)
                    visible: !root.bluetooth && networks.length > 0
                    Layout.fillWidth: true
                    Repeater { model: availableNetworks.networks; delegate: DeckNetworkRow { viewport: networkList } }
                }
                Repeater {
                    model: ["Paired", "Nearby"]
                    DeckSection {
                        id: deviceGroup
                        required property string modelData
                        readonly property list<BluetoothDevice> devices: BluetoothService.devices.filter(device =>
                            modelData === "Paired" ? device.paired && !device.connected : !device.paired && !device.connected)
                        title: modelData
                        Layout.fillWidth: true
                        visible: root.bluetooth && devices.length > 0
                        Repeater { model: deviceGroup.devices; delegate: DeckBluetoothRow {} }
                    }
                }
                StyledText {
                    visible: !root.bluetooth && NetworkService.wifiEnabled && availableNetworks.networks.length === 0 && !NetworkService.wifiScanning
                    text: "No other networks found. Try scanning again."
                    color: Colors.overSurfaceVariant
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                StyledText {
                    visible: root.bluetooth && BluetoothService.devices.filter(device => !device.connected).length === 0
                    text: BluetoothService.enabled ? "No other devices. Scan to discover nearby devices." : "Turn Bluetooth on to see devices."
                    color: Colors.overSurfaceVariant
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
