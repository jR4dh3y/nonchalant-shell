// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G   A   M   E   S       F   A   C   E                                  │
// │   arcade as a joystick · best score and play                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services
import qs.modules.widgets.desktop.impasto.components

Instrument {
    id: face

    property var row: null
    readonly property var last: GamesService.entry(GamesService.lastPlayed)

    line: face.last ? `${face.last.name} · best ${GamesService.bestOf(face.last.id)}` : "Nothing played yet"
    reading: face.last ? `${GamesService.bestOf(face.last.id)}` : "—"
    note: face.last ? `${face.last.name} · best` : "nothing played yet"
    filled: true

    Joystick {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height)
    }

    extra: [
        PillButton {
            anchors.left: parent.left
            anchors.top: parent.top
            text: "Play"
            implicitHeight: 28
            onClicked: ModuleService.requestPanel("games", face.row)
        }
    ]
}
