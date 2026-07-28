import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.modules.components

StyledRect {
    id: root

    variant: "bg"
    visible: rowRepeater.count > 0

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    topLeftRadius: startRadius
    topRightRadius: endRadius
    bottomLeftRadius: startRadius
    bottomRightRadius: endRadius

    Layout.preferredWidth: visible ? rowLayout.implicitWidth + 16 : 0
    implicitWidth: Layout.preferredWidth
    implicitHeight: visible ? rowLayout.implicitHeight + 16 : 0

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Repeater {
            id: rowRepeater
            model: SystemTray.items

            SysTrayItem {
                required property SystemTrayItem modelData
                item: modelData
            }
        }
    }
}
