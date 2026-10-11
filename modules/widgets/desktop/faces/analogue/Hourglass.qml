// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   H   O   U   R   G   L   A   S   S                                      │
// │   hourglass drawing for countdowns                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// An hourglass with the sand in the timer's blue: what is left in the top bulb,
// a heap below, and a thread while it runs. `fraction` is what is left.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property real size: 120
    property real fraction: 0
    property bool running: false

    readonly property real clamped: Math.max(0, Math.min(1, root.fraction))
    readonly property real w: root.width
    readonly property real h: root.height
    readonly property real topY: 8
    readonly property real bottomY: root.h - 8
    readonly property real cx: root.w / 2
    readonly property real cy: root.h / 2
    readonly property real neck: 3

    // Where the sand stands in the top bulb, and how wide the glass is there.
    readonly property real level: root.cy - 8 - (root.cy - root.topY - 12) * root.clamped
    function halfAt(y: real): real {
        const k = Math.max(0, Math.min(1, (y - root.topY) / (root.cy - root.topY)))
        return (root.w / 2 - 8) * (1 - Math.pow(k, 2.2)) + root.neck
    }
    readonly property real heap: (root.cy - root.topY - 12) * (1 - root.clamped) * 0.55

    width: root.size * 0.72
    height: root.size

    Rectangle {
        x: 0; y: root.topY - 6
        width: root.w; height: 4
        radius: 2
        color: root.ink.text
    }

    Rectangle {
        x: 0; y: root.bottomY + 2
        width: root.w; height: 4
        radius: 2
        color: root.ink.text
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ink.text
            strokeWidth: 2.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            startX: 6; startY: root.topY

            PathLine { x: root.w - 6; y: root.topY }
            PathQuad { x: root.cx + root.neck; y: root.cy; controlX: root.w - 6; controlY: root.cy - 10 }
            PathQuad { x: root.w - 6; y: root.bottomY; controlX: root.w - 6; controlY: root.cy + 10 }
            PathLine { x: 6; y: root.bottomY }
            PathQuad { x: root.cx - root.neck; y: root.cy; controlX: 6; controlY: root.cy + 10 }
            PathQuad { x: 6; y: root.topY; controlX: 6; controlY: root.cy - 10 }
        }
    }

    // The sand above the neck.
    Shape {
        visible: root.clamped > 0.02
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillColor: Theme.indicatorTimer

            PathPolyline {
                path: [
                    Qt.point(root.cx - root.halfAt(root.level), root.level),
                    Qt.point(root.cx + root.halfAt(root.level), root.level),
                    Qt.point(root.cx + root.neck, root.cy - 2),
                    Qt.point(root.cx - root.neck, root.cy - 2),
                    Qt.point(root.cx - root.halfAt(root.level), root.level)
                ]
            }
        }
    }

    // The heap below it.
    Shape {
        visible: root.clamped < 0.98
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillColor: Theme.indicatorTimer
            startX: 10; startY: root.bottomY - 3

            PathQuad {
                x: root.w - 10; y: root.bottomY - 3
                controlX: root.cx; controlY: root.bottomY - 3 - root.heap * 2.2
            }

            PathLine { x: 10; y: root.bottomY - 3 }
        }
    }

    Rectangle {
        visible: root.running && root.clamped > 0.02
        x: root.cx - 1
        y: root.cy
        width: 2
        height: Math.max(0, root.bottomY - 3 - root.heap - root.cy)
        color: Theme.indicatorTimer
        opacity: 0.7
    }
}
