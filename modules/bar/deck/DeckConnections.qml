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
    spacing: Styling.fontSize(0)

    function stopDiscovery(): void {
        if (root.ownsDiscovery) {
            BluetoothService.stopDiscovery();
            root.ownsDiscovery = false;
        }
    }
    onVisibleChanged: if (!visible) stopDiscovery()
    onBluetoothChanged: if (!bluetooth) stopDiscovery()
    Component.onDestruction: stopDiscovery()
    RowLayout {
        objectName: "deckConnectionToolbar"
        Layout.fillWidth: true
        Pane {
            padding: Styling.fontSize(0) * 0.25
            background: StyledRect { variant: "internalbg"; radius: Styling.radius(-6); enableBorder: false }
            contentItem: RowLayout {
                spacing: Styling.fontSize(0) * 0.2
                DeckAction {
                    objectName: "deckConnectionWifi"
                    glyph: Icons.wifiHigh
                    label: root.width < Styling.fontSize(0) * 24 ? "" : "Wi-Fi"
                    description: "Wi-Fi"
                    selected: !root.bluetooth
                    onClicked: if (root.bluetooth) root.tabRequested("wifi")
                }
                DeckAction {
                    objectName: "deckConnectionBluetooth"
                    glyph: Icons.bluetooth
                    label: root.width < Styling.fontSize(0) * 24 ? "" : "Bluetooth"
                    description: "Bluetooth"
                    selected: root.bluetooth
                    onClicked: if (!root.bluetooth) root.tabRequested("bluetooth")
                }
            }
        }
        Item { Layout.fillWidth: true }
        DeckAction {
            objectName: "deckRadioToggle"
            label: (root.bluetooth ? BluetoothService.enabled : NetworkService.wifiEnabled) ? "On" : "Off"
            selected: root.bluetooth ? BluetoothService.enabled : NetworkService.wifiEnabled
            description: "Toggle " + (root.bluetooth ? "Bluetooth" : "Wi-Fi")
            enabled: root.bluetooth ? !BluetoothService.isUpdating : !NetworkService.isUpdating
            onClicked: root.bluetooth ? BluetoothService.toggle() : NetworkService.toggleWifi()
        }
        DeckAction {
            objectName: "deckConnectionScan"
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
    }
    StyledText {
        Layout.fillWidth: true
        visible: root.bluetooth ? BluetoothService.discovering || connectedDevices.devices.length === 0
            : NetworkService.wifiConnecting || NetworkService.wifiScanning || connectedNetworks.networks.length === 0
        text: root.bluetooth ? (BluetoothService.discovering ? "Looking for devices…" : BluetoothService.firstConnectedDeviceName || "Choose a device below")
            : NetworkService.ethernet ? "Ethernet connected"
            : NetworkService.wifiConnecting ? "Connecting…" : NetworkService.wifiScanning ? "Looking for networks…"
            : NetworkService.wifiConnected ? "Connected to " + NetworkService.activeSsid
            : NetworkService.wifiEnabled ? "Choose a network below" : "Wi-Fi is turned off"
        wrapMode: Text.WordWrap
        color: Colors.overSurfaceVariant
        font.pixelSize: Styling.fontSize(-1)
    }
    DeckSection {
        id: connectedNetworks
        objectName: "deckConnectedNetworks"
        title: "Connected"
        readonly property list<WifiAccessPoint> networks: NetworkService.wifiNetworks.filter(network => network.active)
        visible: !root.bluetooth && networks.length > 0
        Layout.fillWidth: true
        Repeater { model: connectedNetworks.networks; delegate: NetworkRow {} }
    }
    DeckSection {
        id: connectedDevices
        title: "Connected"
        readonly property list<BluetoothDevice> devices: BluetoothService.devices.filter(device => device.connected)
        visible: root.bluetooth && devices.length > 0
        Layout.fillWidth: true
        Repeater { model: connectedDevices.devices; delegate: DeviceRow {} }
    }
    ScrollView {
        id: list
        objectName: "deckNetworkList"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
            width: list.availableWidth
            spacing: Styling.fontSize(0)
            DeckSection {
                id: availableNetworks
                objectName: "deckAvailableNetworks"
                title: "Available networks"
                readonly property list<WifiAccessPoint> networks: NetworkService.wifiNetworks.filter(network => !network.active)
                visible: !root.bluetooth && networks.length > 0
                Layout.fillWidth: true
                Repeater { model: availableNetworks.networks; delegate: NetworkRow {} }
            }
            Repeater {
                model: ["Paired devices", "Available devices"]
                DeckSection {
                    id: deviceGroup
                    required property string modelData
                    readonly property list<BluetoothDevice> devices: BluetoothService.devices.filter(device =>
                        modelData === "Paired devices" ? device.paired && !device.connected : !device.paired && !device.connected)
                    title: modelData
                    Layout.fillWidth: true
                    visible: root.bluetooth && devices.length > 0
                    Repeater { model: deviceGroup.devices; delegate: DeviceRow {} }
                }
            }
            StyledText {
                visible: !root.bluetooth && NetworkService.wifiEnabled && NetworkService.wifiNetworks.length === 0 && !NetworkService.wifiScanning
                text: "No networks found. Try scanning again."
                color: Colors.overSurfaceVariant
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            StyledText {
                visible: root.bluetooth && BluetoothService.devices.length === 0
                text: BluetoothService.enabled ? "No devices found. Start a scan to discover devices." : "Bluetooth is turned off"
                color: Colors.overSurfaceVariant
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
    }
    DeckAction {
        objectName: "deckConnectionSettings"
        Layout.fillWidth: true
        maximumLabelWidth: root.width
        glyph: Icons.arrowSquareOut
        label: "Advanced " + (root.bluetooth ? "Bluetooth" : "network") + " settings"
        onClicked: root.settingsRequested(root.bluetooth ? "bluetooth" : "network")
    }
    component NetworkRow: ColumnLayout {
        id: networkRow
        required property WifiAccessPoint modelData
        Layout.fillWidth: true
        onHeightChanged: if (modelData?.askingPassword) Qt.callLater(revealPassword)
        function revealPassword(): void {
            if (!password.visible || !modelData || modelData.active) return;
            password.forceActiveFocus();
            const viewport = list.contentItem;
            const bottom = password.mapToItem(viewport.contentItem, 0, password.height).y;
            if (bottom > viewport.contentY + viewport.height)
                viewport.contentY = Math.max(0, Math.min(bottom - viewport.height, viewport.contentHeight - viewport.height));
        }
        function connectWithPassword(): void {
            if (password.text.length === 0 || NetworkService.isUpdating) return;
            let secret = password.text;
            password.clear();
            NetworkService.changePassword(modelData, secret);
            secret = "";
        }
        DeckAction {
            Layout.fillWidth: true
            objectName: "deckNetwork-" + networkRow.modelData.ssid
            glyph: NetworkService.wifiIconForStrength(networkRow.modelData.strength)
            label: networkRow.modelData.ssid
            selected: networkRow.modelData.active
            enabled: !NetworkService.isUpdating && NetworkService.wifiEnabled
            maximumLabelWidth: root.width
            onClicked: {
                if (networkRow.modelData.active) NetworkService.disconnectWifiNetwork();
                else NetworkService.connectToWifiNetwork(networkRow.modelData);
            }
        }
        RowLayout {
            visible: networkRow.modelData.askingPassword
            Layout.fillWidth: true
            TextField {
                id: password
                objectName: "deckPassword-" + networkRow.modelData.ssid
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Network password"
                placeholderTextColor: Colors.overSurfaceVariant
                Accessible.name: "Password for " + networkRow.modelData.ssid
                color: Colors.overBackground
                font.family: Config.theme.font
                background: StyledRect { variant: "internalbg"; radius: Styling.radius(-8) }
                onVisibleChanged: {
                    if (visible) Qt.callLater(networkRow.revealPassword);
                    else clear();
                }
                Component.onDestruction: clear()
                onAccepted: networkRow.connectWithPassword()
                Keys.onEscapePressed: { clear(); networkRow.modelData.askingPassword = false; }
            }
            DeckAction {
                label: "Connect"
                enabled: password.text.length > 0 && !NetworkService.isUpdating
                onClicked: networkRow.connectWithPassword()
            }
        }
    }

    component DeviceRow: DeckAction {
        required property BluetoothDevice modelData
        Layout.fillWidth: true
        glyph: Icons.bluetooth
        label: modelData.name + (modelData.connecting ? " · Connecting…" : "")
        maximumLabelWidth: root.width
        selected: modelData.connected
        enabled: BluetoothService.enabled && !modelData.connecting
        onClicked: {
            if (modelData.connected) modelData.disconnect();
            else if (!modelData.paired) modelData.pair();
            else modelData.connect();
        }
    }
}
