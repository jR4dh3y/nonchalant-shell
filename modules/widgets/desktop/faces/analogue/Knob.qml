// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   K   N   O   B                                                          │
// │   rotary knob drawing for levels                                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// A rotary knob: 21 marks over three quarters of a turn, lit up to the level,
// with an accent pointer. Muted, a bar crosses it in the muted colour rather
// than red: silence is not a warning.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property real size: 120
    property real fraction: 0
    property bool muted: false

    readonly property real clamped: Math.max(0, Math.min(1, root.fraction))
    readonly property real r: root.size * 0.34
    readonly property real cx: root.size / 2
    readonly property real cy: root.size / 2

    width: root.size
    height: root.size

    Repeater {
        model: 21

        Item {
            id: mark

            required property int index

            readonly property bool major: mark.index % 5 === 0
            readonly property bool lit: mark.index / 20 <= root.clamped + 0.001

            anchors.fill: parent
            rotation: 135 + 270 * mark.index / 20 + 90

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.cy - root.size * 0.48
                width: mark.major ? 2.5 : 1.5
                height: mark.major ? 8 : 5
                radius: width / 2
                color: mark.lit && !root.muted ? root.ink.text : root.ink.dim
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 2 * root.r
        height: 2 * root.r
        radius: root.r
        color: root.ink.raised
        border.color: root.ink.border
        border.width: 2
    }

    Rectangle {
        anchors.centerIn: parent
        width: 2 * root.r - 16
        height: 2 * root.r - 16
        radius: width / 2
        color: "transparent"
        border.color: root.ink.dim
        border.width: 1
    }

    Item {
        anchors.fill: parent
        rotation: 135 + 270 * root.clamped + 90

        Behavior on rotation { NumberAnimation { duration: Theme.durationMedium } }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.cy - (root.r - 10)
            width: 4
            height: root.r * 0.55
            radius: 2
            color: root.muted ? root.ink.muted : root.ink.accent
        }
    }

    Rectangle {
        visible: root.muted
        anchors.centerIn: parent
        width: root.r * 2.3
        height: 4
        radius: 2
        rotation: -45
        color: root.ink.muted
    }
}
