pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.config

// Bar pill showing the connected headphone's sample rate and bit depth.
// Falls back to zero width (fully removed) while no headphone-class sink is
// the default output, mirroring how SysTray collapses when empty.
StyledRect {
    id: root

    variant: "bg"
    visible: AudioFormat.connected

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

    property bool isHovered: false

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // Background highlight on hover
    Rectangle {
        anchors.fill: parent
        color: Styling.srItem("overprimary")
        opacity: root.isHovered ? 0.25 : 0
        radius: parent.radius ?? 0

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        Text {
            text: AudioFormat.kindIcon
            font.family: Icons.font
            font.pixelSize: 14
            color: Colors.overBackground
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: AudioFormat.formatSummary
            Layout.alignment: Qt.AlignVCenter
        }
    }

    StyledToolTip {
        visible: root.isHovered
        tooltipText: AudioFormat.tooltipTitle
        desciription: AudioFormat.tooltipDetail
    }
}