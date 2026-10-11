// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B   R   I   G   H   T   N   E   S   S       F   A   C   E              │
// │   the backlight as a fader · pushed up to the level                      │
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

    line: BrightnessService.available ? `${BrightnessService.percent}%` : "No backlight"
    reading: BrightnessService.available ? `${BrightnessService.percent}%` : "—"
    note: BrightnessService.available ? "backlight" : "no backlight"
    filled: true

    Fader {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.height, parent.width * 2)
        fraction: BrightnessService.percent / 100
    }

    extra: [
        UsageBar {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            progress: BrightnessService.percent / 100
            fillColor: face.ink.accent
            trackColor: face.ink.raised
        }
    ]
}
