// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P I L L   B U T T O N                                                  │
// │   capsule action · fills with the accent when active                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Layouts

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.components

// Capsule action button. `active` fills it with the accent, which is how the
// Quick Controls show a radio or profile that is currently on.
StyledRect {
    id: root
    variant: "transparent"
    backgroundOpacity: 1
    clip: false
    animateRadius: false
    enableBorder: true

    property string text: ""
    property string icon: ""
    property bool active: false
    property bool enabled: true
    property int horizontalPadding: 10

    signal clicked()

    readonly property bool filled: root.active
    readonly property color foreground: root.filled ? Theme.accentText : Theme.text

    implicitHeight: 28
    implicitWidth: layout.implicitWidth + root.horizontalPadding * 2
    radius: Theme.radiusPill
    opacity: root.enabled ? 1 : 0.4

    color: root.filled
        ? (mouse.containsMouse ? Theme.accentHover : Theme.accent)
        : (mouse.containsMouse ? Theme.surfaceHoverIn(QsWindow.window) : Theme.surfaceIn(QsWindow.window))
    border.color: root.filled ? Theme.accent
        : (mouse.containsMouse ? Theme.accent : Theme.borderIn(QsWindow.window))
    border.width: 1

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.fontMono
            font.pixelSize: 12
            color: root.filled ? Theme.accentText : Theme.accent
        }

        Text {
            visible: root.text !== ""
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: root.filled ? Font.DemiBold : Font.Normal
            color: root.foreground
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
