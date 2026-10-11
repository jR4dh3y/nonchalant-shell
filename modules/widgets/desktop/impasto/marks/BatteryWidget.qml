// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A T T E R Y   W I D G E T                                            │
// │   charge as a ring · the level is the outline                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services
import qs.modules.widgets.desktop.impasto.components

// The outline is the charge level; the exact figure is in the island detail.
// No background of its own: whatever hosts the ring supplies it.
RingIndicator {
    id: root

    // Smaller inside the island, where the capsule's edge would clip it.
    property real size: Theme.capsuleHeight

    // A desktop face passes its own ink so the ring reads on its background.
    property color glyphColor: Theme.indicator
    property color track: Theme.indicatorDim

    implicitWidth: root.size
    implicitHeight: root.size

    visible: BatteryService.available
    progress: BatteryService.percent / 100
    thickness: 2.5

    trackColor: root.track
    fillColor: BatteryService.tint

    Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

    Text {
        anchors.centerIn: parent
        text: BatteryService.icon
        font.family: Theme.fontMono
        font.pixelSize: Math.round(root.size * 0.38)
        // The ring carries the level; the glyph only says what is measured.
        color: root.glyphColor
    }
}
