pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.bar.island
import qs.modules.theme

Item {
    id: root

    property string mode: "wifi"
    property real maximumSize: Infinity
    property bool lyricsActive: false
    signal backRequested()
    signal closeRequested()
    implicitWidth: mode === "media" ? Math.min(Styling.fontSize(0) * 28, maximumSize) : 400
    implicitHeight: panelLoader.item?.implicitHeight ?? 340

    function focusCurrentTab(): void {
        root.forceActiveFocus();
    }

    Keys.onEscapePressed: root.closeRequested()

    Loader {
        id: panelLoader
        anchors.fill: parent
        sourceComponent: {
            switch (root.mode) {
            case "sound": return soundPanel;
            case "mic": return micPanel;
            case "bluetooth": return bluetoothPanel;
            case "battery": return batteryPanel;
            case "media": return mediaPanel;
            default: return wifiPanel;
            }
        }
    }

    Component { id: soundPanel; IslandSoundPanel { backTooltip: "Close menu"; onBackRequested: root.backRequested() } }
    Component { id: micPanel; IslandMicPanel { backTooltip: "Close menu"; onBackRequested: root.backRequested() } }
    Component { id: wifiPanel; IslandWifiPanel { backTooltip: "Close menu"; onBackRequested: root.backRequested() } }
    Component { id: bluetoothPanel; IslandBluetoothPanel { backTooltip: "Close menu"; onBackRequested: root.backRequested() } }
    Component { id: batteryPanel; IslandBatteryPanel { backTooltip: "Close menu"; onBackRequested: root.backRequested() } }
    Component {
        id: mediaPanel
        IslandMediaCenterPanel {
            objectName: "verticalMediaCenter"
            squareArtwork: true
            lyricsActive: root.lyricsActive
        }
    }
}
