import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.modules.components
import qs.config

StyledRect {
    id: root

    variant: "bg"
    visible: trayRepeater.count > 0

    property bool vertical: false
    readonly property int padding: vertical ? 0 : 8
    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    topLeftRadius: startRadius
    topRightRadius: endRadius
    bottomLeftRadius: startRadius
    bottomRightRadius: endRadius

    Layout.preferredWidth: visible ? trayGrid.implicitWidth + root.padding * 2 : 0
    implicitWidth: Layout.preferredWidth
    implicitHeight: visible ? trayGrid.implicitHeight + root.padding * 2 : 0

    // One row for horizontal bars; a single column when the dock is vertical.
    GridLayout {
        id: trayGrid
        anchors.fill: parent
        anchors.margins: root.padding
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        columns: root.vertical ? 1 : -1
        rows: root.vertical ? -1 : 1
        columnSpacing: 8
        rowSpacing: root.vertical ? 4 : 8

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            SysTrayItem {
                required property SystemTrayItem modelData
                item: modelData
                vertical: root.vertical
                hitboxSize: root.vertical ? Math.max(36, Config.theme.fontSize + 20) : trayItemSize
            }
        }
    }
}
