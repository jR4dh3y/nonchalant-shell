pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.theme

RowLayout {
    id: root

    required property string title
    signal backRequested()

    spacing: 8

    StyledRect {
        implicitWidth: 28
        implicitHeight: 28
        radius: width / 2
        variant: backMouse.containsMouse ? "focus" : "common"
        scale: backMouse.pressed ? 0.92 : 1.0

        PressBehavior on scale {
            pressed: backMouse.pressed
        }

        StyledText {
            anchors.centerIn: parent
            text: Icons.arrowLeft
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(0)
        }

        MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backRequested()
        }

        StyledToolTip {
            show: backMouse.containsMouse
            tooltipText: "Back to Dashboard"
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pixelSize: Styling.fontSize(1)
        font.bold: true
        elide: Text.ElideRight
    }
}
