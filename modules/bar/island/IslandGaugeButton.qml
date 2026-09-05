pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

StyledRect {
    id: root

    implicitWidth: 52
    implicitHeight: 52
    Layout.preferredWidth: 52
    Layout.preferredHeight: 52
    radius: 26

    property string icon: ""
    property int iconSize: 22
    property bool active: false
    property color iconColor: active ? Colors.overPrimary : Colors.overBackground
    variant: active ? "primary" : (mouseArea.containsMouse ? "focus" : "internalbg")

    // Compatibility properties
    property real value: 0.0
    property color arcColor: Colors.primary
    property color trackColor: Qt.rgba(1, 1, 1, 0.15)
    property bool showArc: false
    property bool isMuted: false

    signal clicked(var mouse)
    signal wheelScrolled(int delta)

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
}
