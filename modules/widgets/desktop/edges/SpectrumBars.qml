pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.services.desktop
import qs.modules.theme

ShaderEffect {
    id: root

    required property string edge
    required property var row
    required property bool listening

    readonly property string style: root.looks.indexOf(root.row?.look) >= 0 ? root.row.look : "rounded"
    readonly property string fillStyle: root.fills.indexOf(root.row?.fill) >= 0 ? root.row.fill : "fade"
    readonly property string lowsAt: root.row?.lows === "along" ? "along" : "corners"
    readonly property color color: root.resolveColor(root.row?.color ?? "palette", Colors.primary)
    readonly property color color2: root.resolveColor(root.row?.color2 ?? "", Colors.overSurface)
    readonly property real barWidth: Math.max(2, Math.min(24,
        Number.isFinite(root.row?.bar) ? Math.round(root.row.bar) : Styling.fontSize(0) * 0.72))
    readonly property real gap: Math.max(1, Math.min(16,
        Number.isFinite(root.row?.gap) ? Math.round(root.row.gap) : Styling.fontSize(0) * 0.43))
    readonly property real floorLength: Math.max(1, Styling.fontSize(-4))
    readonly property bool peaks: root.row?.peaks === true
    readonly property real base: root.opacityPercent
    readonly property real tip: root.opacityPercent * 0.25
    readonly property real curve: 0.55
    readonly property real opacityPercent: root.row?.opacity === undefined ? 1
        : Math.max(0.2, Math.min(1, Number(root.row.opacity) / 100))
    readonly property vector2d area: Qt.vector2d(root.width, root.height)
    readonly property real side: root.edge === "left" ? 1 : root.edge === "right" ? 2 : 0
    readonly property var looks: ["rounded", "square", "segments", "dots", "wave"]
    readonly property var fills: ["fade", "solid", "blend"]
    readonly property real look: Math.max(0, root.looks.indexOf(root.style))
    readonly property real fill: Math.max(0, root.fills.indexOf(root.fillStyle))
    readonly property real lows: root.lowsAt === "along" ? 1 : 0
    readonly property real peaksOn: root.peaks ? 1 : 0
    readonly property real pitch: root.barWidth + root.gap

    readonly property var levels: root.hearing ? CavaService.bands : root.nothing
    readonly property var highs: root.hearing && root.peaks ? CavaService.peaks : root.nothing
    readonly property var nothing: new Array(CavaService.bandCount).fill(0)

    readonly property vector4d b0: root.four(root.levels, 0)
    readonly property vector4d b1: root.four(root.levels, 4)
    readonly property vector4d b2: root.four(root.levels, 8)
    readonly property vector4d b3: root.four(root.levels, 12)
    readonly property vector4d b4: root.four(root.levels, 16)
    readonly property vector4d b5: root.four(root.levels, 20)
    readonly property vector4d b6: root.four(root.levels, 24)
    readonly property vector4d b7: root.four(root.levels, 28)
    readonly property vector4d b8: root.four(root.levels, 32)
    readonly property vector4d b9: root.four(root.levels, 36)
    readonly property vector4d b10: root.four(root.levels, 40)
    readonly property vector4d b11: root.four(root.levels, 44)
    readonly property vector4d b12: root.four(root.levels, 48)
    readonly property vector4d b13: root.four(root.levels, 52)
    readonly property vector4d b14: root.four(root.levels, 56)
    readonly property vector4d b15: root.four(root.levels, 60)

    readonly property vector4d p0: root.four(root.highs, 0)
    readonly property vector4d p1: root.four(root.highs, 4)
    readonly property vector4d p2: root.four(root.highs, 8)
    readonly property vector4d p3: root.four(root.highs, 12)
    readonly property vector4d p4: root.four(root.highs, 16)
    readonly property vector4d p5: root.four(root.highs, 20)
    readonly property vector4d p6: root.four(root.highs, 24)
    readonly property vector4d p7: root.four(root.highs, 28)
    readonly property vector4d p8: root.four(root.highs, 32)
    readonly property vector4d p9: root.four(root.highs, 36)
    readonly property vector4d p10: root.four(root.highs, 40)
    readonly property vector4d p11: root.four(root.highs, 44)
    readonly property vector4d p12: root.four(root.highs, 48)
    readonly property vector4d p13: root.four(root.highs, 52)
    readonly property vector4d p14: root.four(root.highs, 56)
    readonly property vector4d p15: root.four(root.highs, 60)

    readonly property int revision: 3
    fragmentShader: `${Qt.resolvedUrl("spectrum.frag.qsb")}?r=${root.revision}`
    property bool subscribed: false
    readonly property bool hearing: root.listening

    function resolveColor(value: string, fallback: color): color {
        if (value === "palette" || value === "")
            return fallback
        const resolved = Config.resolveColor(value)
        return resolved === "transparent" ? fallback : resolved
    }

    function four(list: var, first: int): vector4d {
        return Qt.vector4d(list[first], list[first + 1], list[first + 2], list[first + 3])
    }

    function listen(on: bool): void {
        if (on === root.subscribed)
            return
        root.subscribed = on
        if (on)
            CavaService.subscribe()
        else
            CavaService.release()
    }

    onHearingChanged: root.listen(root.hearing)
    Component.onCompleted: root.listen(root.hearing)
    Component.onDestruction: root.listen(false)
}