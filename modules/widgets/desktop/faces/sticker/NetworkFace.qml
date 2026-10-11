// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N   E   T   W   O   R   K       F   A   C   E                          │
// │   the connection on a disc · sticker                                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// A disc with the connection's glyph, and its name on a tag.
Spread {
    id: face

    readonly property bool on: NetworkService.wifiConnected || NetworkService.wiredConnected
    readonly property color tint: face.on ? face.ink.accent : face.ink.muted

    line: NetworkService.connectionName
    hue: face.tint
    reading: NetworkService.connectionName
    note: NetworkService.stateLine

    Tone { id: tone; hue: face.tint }

    Cut {
        id: plate

        anchors.centerIn: parent
        width: parent.width * 0.96
        height: width
        shape: "circle"
        seed: face.seed
        fill: tone.fill

        Text {
            anchors.centerIn: parent
            text: NetworkService.icon
            font.family: Theme.fontMono
            font.pixelSize: Math.round(plate.side * 0.42)
            color: tone.deep
        }
    }
}
