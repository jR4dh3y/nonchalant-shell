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

    property bool flat: false

    variant: flat ? "transparent" : "bg"
    visible: AudioFormat.connected

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    topLeftRadius: startRadius
    topRightRadius: endRadius
    bottomLeftRadius: startRadius
    bottomRightRadius: endRadius

    enableBorder: !flat
    enableShadow: !flat && root.enableShadow

    Layout.preferredWidth: visible ? (flat ? rowLayout.implicitWidth : rowLayout.implicitWidth + 16) : 0
    implicitWidth: Layout.preferredWidth
    implicitHeight: visible ? (flat ? rowLayout.implicitHeight : rowLayout.implicitHeight + 16) : 0

    property bool isHovered: false

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // Background highlight on hover
    Rectangle {
        anchors.fill: parent
        color: Styling.srItem("overprimary")
        opacity: (!root.flat && root.isHovered) ? 0.25 : 0
        topLeftRadius: parent.topLeftRadius
        topRightRadius: parent.topRightRadius
        bottomLeftRadius: parent.bottomLeftRadius
        bottomRightRadius: parent.bottomRightRadius

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
        anchors.margins: root.flat ? 0 : 8
        spacing: 6

        StyledText {
            text: AudioFormat.kindIcon
            font.family: Icons.font
            font.pixelSize: 14
            color: root.flat && root.isHovered ? Colors.primary : Colors.overBackground
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: AudioFormat.formatSummary
            color: root.flat && root.isHovered ? Colors.primary : Colors.overBackground
            Layout.alignment: Qt.AlignVCenter
        }
    }

    StyledToolTip {
        show: root.isHovered
        tooltipText: AudioFormat.tooltipTitle
        description: AudioFormat.tooltipDetail
    }
}