pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

ColumnLayout {
    id: networkRow
    required property WifiAccessPoint modelData
    required property ScrollView viewport
    Layout.fillWidth: true
    onHeightChanged: if (modelData?.askingPassword) Qt.callLater(revealPassword)
    function revealPassword(): void {
        if (!password.visible || !modelData || modelData.active) return;
        password.forceActiveFocus();
        const viewport = networkRow.viewport.contentItem;
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
        accent: true
        enabled: !NetworkService.isUpdating && NetworkService.wifiEnabled
        maximumLabelWidth: networkRow.width
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
