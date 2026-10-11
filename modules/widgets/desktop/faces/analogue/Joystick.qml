// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   J   O   Y   S   T   I   C   K                                          │
// │   joystick drawing                                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// An arcade stick with an accent ball and two buttons. Static: it is the
// arcade's mark.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property real size: 120

    width: root.size
    height: root.size

    Rectangle {
        x: root.size * 0.08
        y: root.size * 0.6
        width: root.size * 0.84
        height: root.size * 0.28
        radius: 8
        color: root.ink.raised
        border.color: root.ink.border
        border.width: 1
    }

    Rectangle {
        x: root.size * 0.34 - 3
        y: root.size * 0.28
        width: 6
        height: root.size * 0.36
        radius: 3
        color: root.ink.text
        transformOrigin: Item.Bottom
        rotation: -10
    }

    Rectangle {
        x: root.size * 0.34 - root.size * 0.1 - root.size * 0.06
        y: root.size * 0.16
        width: root.size * 0.2
        height: root.size * 0.2
        radius: root.size * 0.1
        color: root.ink.accent
    }

    Repeater {
        model: [0.6, 0.75]

        Rectangle {
            required property int index
            required property real modelData

            x: root.size * modelData
            y: root.size * 0.67
            width: root.size * 0.1
            height: root.size * 0.1
            radius: root.size * 0.05
            color: index === 0 ? root.ink.text : root.ink.muted
        }
    }
}
