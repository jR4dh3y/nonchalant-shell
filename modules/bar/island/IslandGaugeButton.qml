pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config
import ".."

StyledRect {
    id: root

    property real buttonSize: 56

    implicitWidth: buttonSize
    implicitHeight: buttonSize
    Layout.preferredWidth: buttonSize
    Layout.preferredHeight: buttonSize
    radius: Styling.pillRadius(width)

    property string icon: ""
    property int iconSize: 22
    property bool active: false
    property color iconColor: active ? Colors.overPrimary : Colors.overBackground
    variant: active ? "primary" : (mouseArea.containsMouse ? "focus" : "internalbg")
    scale: mouseArea.pressed ? 0.92 : 1.0

    PressBehavior on scale {
        pressed: mouseArea.pressed
    }

    // Radial progress properties
    property real value: 0.0
    property color arcColor: Colors.primary
    property color trackColor: Qt.rgba(1, 1, 1, 0.14)
    property bool showArc: false
    property bool isMuted: false
    property string tooltipText: ""

    signal clicked(var mouse)
    signal wheelScrolled(int delta)

    // Radial progress, concentric with the button so both follow roundness.
    BarRadialMeter {
        id: progressMeter
        anchors.fill: parent
        visible: root.showArc
        controlSize: Math.min(root.width, root.height)
        lineWidth: 3.5
        // Inset from the edge, so a squared button's ring doesn't hug its border.
        meterRadius: (controlSize - lineWidth) / 2 - controlSize * 0.13
        cornerRadius: Math.max(0, root.radius - (controlSize / 2 - meterRadius))
        startAngle: 135
        spanAngle: 270
        value: root.value
        trackColor: root.trackColor
        progressColor: root.arcColor
    }

    // Centered icon
    Text {
        anchors.centerIn: parent
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        text: root.icon
        font.family: Icons.font
        font.pixelSize: root.iconSize
        color: root.iconColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => root.clicked(mouse)
        onWheel: (wheel) => root.wheelScrolled(wheel.angleDelta.y)
    }

    StyledToolTip {
        show: mouseArea.containsMouse && root.tooltipText !== ""
        tooltipText: root.tooltipText
    }
}
