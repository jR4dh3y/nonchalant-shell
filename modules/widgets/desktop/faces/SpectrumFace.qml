pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme

import "../visual"

Item {
    id: root

    property string family: "4x2"
    property var ink
    property var row: null
    property bool active: false

    readonly property var look: DesktopWidgetService.spectrumOf(root.row)
    readonly property bool away: root.row !== null && !DesktopWidgetService.editing
        && DesktopWidgetService.spectrumAwayOn(DesktopWidgetService.nameOf(root.row))

    SpectrumBars {
        anchors.fill: parent
        anchors.margins: root.row === null ? Styling.fontSize(0) : 0
        active: root.active
        listening: !root.away
        style: root.look?.look ?? "rounded"
        fillStyle: root.look?.fill ?? "fade"
        fillColor: root.look?.color ?? root.ink?.accent ?? Colors.primary
        peakColor: root.look?.color2 ?? root.ink?.text ?? Colors.overBackground
        barWidth: root.look?.bar ?? Styling.fontSize(1)
        gap: root.look?.gap ?? Styling.fontSize(-4)
        lowsAt: root.look?.lows ?? "corners"
        showPeaks: root.look?.peaks ?? false
        opacity: (root.look?.opacity ?? 100) / 100
        visible: !root.away
    }
}