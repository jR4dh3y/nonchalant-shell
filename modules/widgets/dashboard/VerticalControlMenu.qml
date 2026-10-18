pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.bar.island
import qs.modules.components
import qs.modules.theme

Item {
    id: root

    property string mode: "wifi"
    property real maximumSize: Infinity
    property bool lyricsActive: false
    readonly property list<string> deviceModes: ["wifi", "bluetooth", "battery"]
    signal backRequested()
    signal closeRequested()
    signal modeRequested(string mode)
    implicitWidth: mode === "media" ? Math.min(Styling.fontSize(0) * 28, maximumSize) : 400
    implicitHeight: panelLoader.item?.implicitHeight ?? 340

    function focusCurrentTab(): void {
        root.forceActiveFocus();
    }

    Keys.onEscapePressed: root.closeRequested()
    function changeDeviceTab(offset: int): bool {
        const current = root.deviceModes.indexOf(root.mode);
        if (current === -1)
            return false;
        const next = Math.max(0, Math.min(root.deviceModes.length - 1, current + offset));
        if (next !== current)
            root.modeRequested(root.deviceModes[next]);
        return true;
    }

    Keys.onLeftPressed: event => { event.accepted = root.changeDeviceTab(-1); }
    Keys.onRightPressed: event => { event.accepted = root.changeDeviceTab(1); }

    Component {
        id: deviceTitle
        RowLayout {
            spacing: Styling.fontSize(0) * 0.2
            Repeater {
                model: root.deviceModes
                Button {
                    id: tab
                    required property string modelData
                    readonly property bool selected: root.mode === tab.modelData
                    objectName: "deviceStatusTab-" + tab.modelData
                    implicitWidth: Styling.fontSize(0) * 2.4
                    implicitHeight: implicitWidth
                    padding: 0
                    Accessible.name: tab.modelData === "wifi" ? "Wi-Fi" : (tab.modelData === "bluetooth" ? "Bluetooth" : "Battery and power")
                    Accessible.role: Accessible.PageTab
                    Accessible.selected: tab.selected
                    scale: tab.pressed ? 0.92 : 1
                    PressBehavior on scale { pressed: tab.pressed }
                    background: StyledRect {
                        id: tabSurface
                        variant: tab.selected ? "focus" : "common"
                        backgroundOpacity: tab.selected || tab.visualFocus ? 1 : 0
                        radius: width / 2
                        HoverTint { hovered: tab.hovered; pressed: tab.pressed }
                    }
                    contentItem: StyledText {
                        text: tab.modelData === "wifi" ? Icons.wifiHigh : (tab.modelData === "bluetooth" ? Icons.bluetooth : Icons.batteryHigh)
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(5)
                        color: tab.selected ? tabSurface.item : Colors.overBackground
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: if (!tab.selected) root.modeRequested(tab.modelData)
                    StyledToolTip {
                        show: tab.hovered
                        tooltipText: tab.Accessible.name
                    }
                }
            }
        }
    }

    Loader {
        id: panelLoader
        anchors.fill: parent
        // A selected tab replaces its own panel, including the focused button.
        onLoaded: root.focusCurrentTab()
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
    Component { id: wifiPanel; IslandWifiPanel { backTooltip: "Close menu"; titleComponent: deviceTitle; onBackRequested: root.backRequested() } }
    Component { id: bluetoothPanel; IslandBluetoothPanel { backTooltip: "Close menu"; titleComponent: deviceTitle; onBackRequested: root.backRequested() } }
    Component { id: batteryPanel; IslandBatteryPanel { backTooltip: "Close menu"; titleComponent: deviceTitle; onBackRequested: root.backRequested() } }
    Component {
        id: mediaPanel
        IslandMediaCenterPanel {
            objectName: "verticalMediaCenter"
            squareArtwork: true
            lyricsActive: root.lyricsActive
        }
    }
}
