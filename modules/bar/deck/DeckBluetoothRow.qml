pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

DeckAction {
    required property BluetoothDevice modelData
    Layout.fillWidth: true
    glyph: Icons.bluetooth
    label: modelData.name + (modelData.connecting ? " · Connecting…" : "")
    maximumLabelWidth: width
    selected: modelData.connected
    accent: true
    enabled: BluetoothService.enabled && !modelData.connecting
    onClicked: {
        if (modelData.connected) modelData.disconnect();
        else if (!modelData.paired) modelData.pair();
        else modelData.connect();
    }
}
