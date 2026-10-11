// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F   A   D   E   R                                                      │
// │   fader drawing for levels                                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// A fader: a track with marks, lit below the cap, and an accent line across the
// cap. A slider, so it is not the same drawing as the volume knob.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property real size: 120
    property real fraction: 0

    readonly property real clamped: Math.max(0, Math.min(1, root.fraction))
    readonly property real travel: root.size - 24
    readonly property real capY: 12 + root.travel * (1 - root.clamped)

    width: 48
    height: root.size

    Rectangle {
        x: root.width / 2 - 2
        y: 12
        width: 4
        height: root.travel
        radius: 2
        color: root.ink.dim
    }

    Rectangle {
        x: root.width / 2 - 2
        y: root.capY
        width: 4
        height: 12 + root.travel - root.capY
        radius: 2
        color: root.ink.text
    }

    Repeater {
        model: 11

        Item {
            required property int index

            readonly property bool major: index % 5 === 0

            y: 12 + root.travel * index / 10

            Rectangle {
                x: root.width / 2 - 8 - width
                y: -0.75
                width: parent.major ? 7 : 4
                height: 1.5
                color: root.ink.muted
            }

            Rectangle {
                x: root.width / 2 + 8
                y: -0.75
                width: parent.major ? 7 : 4
                height: 1.5
                color: root.ink.muted
            }
        }
    }

    Rectangle {
        x: root.width / 2 - 17
        y: root.capY - 8
        width: 34
        height: 16
        radius: 4
        color: root.ink.raised
        border.color: root.ink.border
        border.width: 1

        Behavior on y { NumberAnimation { duration: Theme.durationMedium } }

        Rectangle {
            anchors.centerIn: parent
            width: 24
            height: 2
            radius: 1
            color: root.ink.accent
        }
    }
}
