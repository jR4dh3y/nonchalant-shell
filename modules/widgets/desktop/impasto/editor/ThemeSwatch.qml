// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T   H   E   M   E       S   W   A   T   C   H                          │
// │   widget theme preview · a live clock in that theme                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import Quickshell
import qs.modules.widgets.desktop
import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// A desktop theme at tile size: the live clock face on the island's black.
// Shared by the settings page and the inspector so both previews match.
Item {
    id: root

    property string theme: "modern"

    // Drawn at the 2×2 size and scaled down.
    property real factor: 0.2

    readonly property real side: DesktopService.sizeFor("2x2").width

    implicitWidth: Math.round(root.side * root.factor)
    implicitHeight: implicitWidth

    Item {
        width: root.side
        height: root.side
        scale: root.factor
        transformOrigin: Item.TopLeft

        Rectangle {
            anchors.fill: parent
            radius: Theme.desktopRadius
            color: Theme.island
            border.color: Theme.borderIn(QsWindow.window)
            border.width: 2
        }

        Face {
            anchors.fill: parent
            moduleId: "clock"
            family: "2x2"
            theme: root.theme
            enabled: false
        }
    }
}
