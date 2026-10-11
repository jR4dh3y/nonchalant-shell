// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   U   P   D   A   T   E   S       F   A   C   E                          │
// │   pending updates on a soft square · sticker                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// The count on a soft square; up to date, a tick on green.
Spread {
    id: face

    readonly property bool none: UpdatesService.count === 0
    readonly property color tint: face.none ? face.ink.green : face.ink.yellow

    hue: face.tint
    reading: UpdatesService.checking ? "Checking"
        : !UpdatesService.available ? "Cannot check"
        : (face.none ? "Up to date" : `${UpdatesService.count} pending`)
    note: UpdatesService.age !== "" ? `checked ${UpdatesService.age}` : "updates"

    Tone { id: tone; hue: face.tint }

    Cut {
        id: plate

        anchors.centerIn: parent
        width: parent.width * 0.94
        height: width
        shape: "soft"
        seed: face.seed
        fill: tone.fill

        Column {
            anchors.centerIn: parent

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.none ? "󰄬" : `${UpdatesService.count}`
                font.family: face.none ? Theme.fontMono : Theme.fontFamily
                font.pixelSize: Math.round(plate.side * 0.4)
                font.weight: Font.Bold
                color: tone.deep
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.none ? "UP TO DATE" : "UPDATES"
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(plate.side * 0.075)
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: tone.deep
            }
        }
    }
}
