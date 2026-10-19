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
    readonly property list<string> audioModes: ["sound", "mic"]
    readonly property bool audioMenu: root.audioModes.indexOf(root.mode) !== -1
    readonly property list<string> tabModes: root.audioMenu ? root.audioModes : root.deviceModes
    property Item selectedTab: null
    signal closeRequested()
    signal modeRequested(string mode)
    implicitWidth: mode === "media" ? Math.min(Styling.fontSize(0) * 28, maximumSize) : 400
    implicitHeight: panelLoader.item?.implicitHeight ?? 340

    function focusCurrentTab(): void {
        root.forceActiveFocus();
    }

    function updateSelectedTab(): void {
        root.selectedTab = tabRepeater?.itemAt(root.tabModes.indexOf(root.mode)) ?? null;
    }

    onModeChanged: root.updateSelectedTab()

    Keys.onEscapePressed: root.closeRequested()
    function changeTab(offset: int): bool {
        const current = root.tabModes.indexOf(root.mode);
        if (current === -1)
            return false;
        const next = Math.max(0, Math.min(root.tabModes.length - 1, current + offset));
        if (next !== current)
            root.modeRequested(root.tabModes[next]);
        return true;
    }

    Keys.onLeftPressed: event => { event.accepted = root.changeTab(-1); }
    Keys.onRightPressed: event => { event.accepted = root.changeTab(1); }

    Component {
        id: selectorTitle
        Item {
            implicitWidth: selector.implicitWidth
            implicitHeight: selector.implicitHeight
        }
    }

    // Keep the selector alive while the panel loader swaps its content.
    StyledRect {
        id: selector
        objectName: root.audioMenu ? "audioStatusSelector" : "deviceStatusSelector"
        visible: root.tabModes.indexOf(root.mode) !== -1
        x: 14
        y: 14
        z: 1
        variant: "focus"
        radius: height / 2
        readonly property real inset: Styling.fontSize(0) * 0.5
        implicitWidth: tabs.implicitWidth + inset * 2
        implicitHeight: tabs.implicitHeight + inset * 2
        width: implicitWidth
        height: implicitHeight

        ElasticHighlight {
            id: tabHighlight
            objectName: root.audioMenu ? "audioStatusHighlight" : "deviceStatusHighlight"
            targetItem: root.selectedTab
            originX: tabs.x
            originY: tabs.y
            radius: height / 2
            scale: targetItem?.scale ?? 1
        }

        Row {
            id: tabs
            anchors.centerIn: parent
            Repeater {
                id: tabRepeater
                model: root.tabModes
                onItemAdded: root.updateSelectedTab()
                onItemRemoved: root.updateSelectedTab()

                Button {
                    id: tab
                    required property string modelData
                    readonly property bool selected: root.mode === tab.modelData
                    objectName: (root.audioMenu ? "audioStatusTab-" : "deviceStatusTab-") + tab.modelData
                    implicitWidth: Styling.fontSize(0) * 2.2
                    implicitHeight: implicitWidth
                    padding: 0
                    Accessible.name: root.audioMenu
                        ? (tab.modelData === "sound" ? "Volume" : "Microphone")
                        : (tab.modelData === "wifi" ? "Wi-Fi" : (tab.modelData === "bluetooth" ? "Bluetooth" : "Battery and power"))
                    Accessible.role: Accessible.PageTab
                    Accessible.selected: tab.selected
                    scale: tab.pressed ? 0.92 : 1
                    PressBehavior on scale { pressed: tab.pressed }
                    background: StyledRect {
                        variant: "focus"
                        backgroundOpacity: tab.visualFocus ? 1 : 0
                        radius: width / 2
                        HoverTint { hovered: tab.hovered; pressed: tab.pressed }
                    }
                    contentItem: StyledText {
                        text: root.audioMenu
                            ? (tab.modelData === "sound" ? Icons.speakerHigh : Icons.mic)
                            : (tab.modelData === "wifi" ? Icons.wifiHigh : (tab.modelData === "bluetooth" ? Icons.bluetooth : Icons.batteryHigh))
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(5)
                        color: tab.selected ? tabHighlight.item : Colors.overBackground
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

    Component { id: soundPanel; IslandSoundPanel { showBackButton: false; titleComponent: selectorTitle } }
    Component { id: micPanel; IslandMicPanel { showBackButton: false; titleComponent: selectorTitle } }
    Component { id: wifiPanel; IslandWifiPanel { showBackButton: false; titleComponent: selectorTitle } }
    Component { id: bluetoothPanel; IslandBluetoothPanel { showBackButton: false; titleComponent: selectorTitle } }
    Component { id: batteryPanel; IslandBatteryPanel { showBackButton: false; titleComponent: selectorTitle } }
    Component {
        id: mediaPanel
        IslandMediaCenterPanel {
            objectName: "verticalMediaCenter"
            squareArtwork: true
            lyricsActive: root.lyricsActive
        }
    }
}
