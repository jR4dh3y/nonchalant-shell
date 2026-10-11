// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   R   I   N   G                                                          │
// │   a round-capped arc over its track                                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

// A round-capped arc over its track, `fraction` of `sweep` degrees from
// `start` (0 is three o'clock, clockwise).
Shape {
    id: root

    property real fraction: 0
    property real thickness: 8
    property real start: -90
    property real sweep: 360
    property color color: "white"
    property color track: "transparent"

    readonly property real reach: Math.min(root.width, root.height) / 2 - root.thickness / 2

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "transparent"
        strokeColor: root.track
        strokeWidth: root.thickness
        capStyle: ShapePath.RoundCap

        PathAngleArc {
            centerX: root.width / 2
            centerY: root.height / 2
            radiusX: root.reach
            radiusY: root.reach
            startAngle: root.start
            sweepAngle: root.sweep
        }
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: root.fraction > 0.004 ? root.color : "transparent"
        strokeWidth: root.thickness
        capStyle: ShapePath.RoundCap

        PathAngleArc {
            centerX: root.width / 2
            centerY: root.height / 2
            radiusX: root.reach
            radiusY: root.reach
            startAngle: root.start
            sweepAngle: root.sweep * Math.max(0, Math.min(1, root.fraction))
        }
    }
}
