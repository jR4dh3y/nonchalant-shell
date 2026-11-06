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
    label: modelData.name + (modelData.pairing ? " · Pairing…"
        : modelData.connecting ? " · Connecting…"
        : !modelData.paired && modelData.pairError !== "" ? " · Couldn't pair" : "")
    description: modelData.connected ? "Disconnect " + modelData.name
        : modelData.paired ? "Connect " + modelData.name
        : modelData.pairError !== "" ? modelData.pairError + " · Click to try again"
        : "Pair " + modelData.name
    maximumLabelWidth: width
    selected: modelData.connected
    accent: true
    enabled: BluetoothService.enabled && !modelData.connecting && !modelData.pairing
    onClicked: {
        if (modelData.connected) modelData.disconnect();
        else if (!modelData.paired) modelData.pair();
        else modelData.connect();
    }
}
