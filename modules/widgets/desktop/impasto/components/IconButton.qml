// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I C O N   B U T T O N                                                  │
// │   square icon action                                                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import Quickshell
import qs.modules.widgets.desktop.impasto.theme
import qs.modules.components

// Square icon button, transparent until hovered.
StyledRect {
    id: root
    variant: "transparent"
    backgroundOpacity: 1
    clip: false
    animateRadius: false
    enableBorder: true

    property string icon: ""
    property int iconSize: 13
    property color iconColor: Theme.text
    property bool active: false

    signal clicked()

    implicitWidth: 32
    implicitHeight: 28
    radius: Theme.radiusSmall

    color: root.active ? Theme.accent
        : (mouse.containsMouse ? Theme.surfaceHoverIn(QsWindow.window) : "transparent")
    border.color: root.active ? Theme.accent
        : (mouse.containsMouse ? Theme.borderIn(QsWindow.window) : "transparent")
    border.width: 1

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Theme.fontMono
        font.pixelSize: root.iconSize
        color: root.active ? Theme.accentText
            : (mouse.containsMouse ? Theme.accent : root.iconColor)

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
