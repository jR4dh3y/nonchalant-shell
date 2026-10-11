// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B   A   T   T   E   R   Y       F   A   C   E                          │
// │   the charge as a cell that fills · red when it is running low           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services
import qs.modules.widgets.desktop.impasto.components

// A battery cell filled to the charge, with a bolt while charging. The fill
// takes the fixed battery red when the charge is low.
Instrument {
    id: face

    line: BatteryService.available ? `${BatteryService.percent}% · ${BatteryService.estimate}` : "No battery"
    reading: BatteryService.available ? `${BatteryService.percent}%` : "—"
    note: BatteryService.available
        ? `${BatteryService.stateWord} · ${BatteryService.estimate}` : "no battery"

    BatteryCell {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height / 0.48)
        fraction: BatteryService.percent / 100
        charging: BatteryService.charging || BatteryService.full
        fill: BatteryService.low ? BatteryService.tint : face.ink.text
    }
}
