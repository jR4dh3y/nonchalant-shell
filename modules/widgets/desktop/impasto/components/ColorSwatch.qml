// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O L O U R   S W A T C H                                              │
// │   palette preview · four colours in a grid                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme

// A 2×2 palette preview.
Item {
    id: root

    property var colors: []
    property int swatchSize: 12
    property int swatchRadius: 3

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    Grid {
        id: grid
        columns: 2
        spacing: 3

        Repeater {
            model: root.colors ? root.colors.slice(0, 4) : []

            Rectangle {
                required property var modelData

                width: root.swatchSize
                height: root.swatchSize
                radius: root.swatchRadius
                color: modelData ?? Theme.surface
                border.color: Theme.hairline
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.paletteTransition } }
            }
        }
    }
}
