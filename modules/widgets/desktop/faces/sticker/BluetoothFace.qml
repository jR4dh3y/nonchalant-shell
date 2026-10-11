// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B   L   U   E   T   O   O   T   H       F   A   C   E                  │
// │   the rune on a sticker, with the devices counted                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// The rune on a six-lobed sticker, with a small round one stuck on its
// shoulder saying how many devices are connected.
Spread {
    id: face

    readonly property int connected: BluetoothService.connectedDevices.length
    readonly property color tint: BluetoothService.enabled ? face.ink.blue : face.ink.muted

    hue: face.tint
    reading: BluetoothService.summary
    note: !BluetoothService.available ? "no adapter"
        : BluetoothService.enabled
        ? (face.connected > 0 ? `${face.connected} connected` : "nothing connected") : "off"

    Tone { id: tone; hue: face.tint }

    Cut {
        id: plate

        anchors.fill: parent
        shape: "cookie"
        lobes: 6
        depth: 0.08
        seed: face.seed
        fill: tone.fill

        Text {
            anchors.centerIn: parent
            text: "󰂯"
            font.family: Theme.fontMono
            font.pixelSize: Math.round(plate.side * 0.4)
            color: tone.deep
        }
    }

    Dot {
        visible: face.connected > 0
        live: false
        x: parent.width * 0.66
        y: parent.height * 0.02
        width: parent.width * 0.34
        height: width
        seed: face.seed + "count"
        hue: face.ink.accent
        glyph: `${face.connected}`
    }
}
