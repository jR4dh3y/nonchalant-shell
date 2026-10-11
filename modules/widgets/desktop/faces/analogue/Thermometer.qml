// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T   H   E   R   M   O   M   E   T   E   R                              │
// │   thermometer drawing                                                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// A thermometer: a tube and bulb, accent mercury and five marks. Takes a
// fraction; the scale is the face's business.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property real size: 120
    property real fraction: 0.5

    readonly property real tube: 14
    readonly property real bulb: 12
    readonly property real stroke: 2.5
    readonly property real clamped: Math.max(0, Math.min(1, root.fraction))

    // The mercury runs from just inside the top of the tube to the bulb.
    readonly property real high: 8
    readonly property real low: root.size - 2 * root.bulb - 2
    readonly property real level: root.low - (root.low - root.high) * root.clamped

    width: 44
    height: root.size

    Rectangle {
        x: (root.width - root.tube) / 2
        y: 0
        width: root.tube
        height: root.size - 2 * root.bulb + 6
        radius: root.tube / 2
        color: "transparent"
        border.color: root.ink.text
        border.width: root.stroke
    }

    Rectangle {
        x: root.width / 2 - root.bulb
        y: root.size - 2 * root.bulb
        width: 2 * root.bulb
        height: 2 * root.bulb
        radius: root.bulb
        color: "transparent"
        border.color: root.ink.text
        border.width: root.stroke
    }

    Rectangle {
        x: root.width / 2 - 3
        y: root.level
        width: 6
        height: root.size - root.bulb - root.level
        color: root.ink.accent

        Behavior on y { NumberAnimation { duration: Theme.durationMedium } }
    }

    Rectangle {
        x: root.width / 2 - root.bulb + 4
        y: root.size - 2 * root.bulb + 4
        width: 2 * root.bulb - 8
        height: 2 * root.bulb - 8
        radius: width / 2
        color: root.ink.accent
    }

    Repeater {
        model: 5

        Rectangle {
            required property int index

            x: root.width / 2 + root.tube / 2 + 5
            y: root.high + (root.low - root.high) * index / 4
            width: index % 2 === 0 ? 8 : 5
            height: 1.5
            radius: 1
            color: root.ink.muted
        }
    }
}
