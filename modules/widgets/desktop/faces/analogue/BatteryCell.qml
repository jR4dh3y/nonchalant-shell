// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B   A   T   T   E   R   Y       C   E   L   L                          │
// │   battery cell drawing                                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// A battery on its side: the case, the terminal and a fill from the left, with
// a bolt in the accent while charging. The fill colour is passed in, since a
// low charge is red in every palette.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property real size: 110
    property real fraction: 0.5
    property bool charging: false
    property color fill: root.ink.text

    readonly property real clamped: Math.max(0, Math.min(1, root.fraction))
    readonly property real body: root.size - 8

    width: root.size
    height: root.size * 0.48

    Rectangle {
        x: 0
        y: 0
        width: root.body
        height: root.height
        radius: 10
        color: "transparent"
        border.color: root.ink.text
        border.width: 2.5
    }

    Rectangle {
        x: root.body + 2
        y: root.height / 2 - 10
        width: 6
        height: 20
        radius: 2
        color: root.ink.text
    }

    Rectangle {
        x: 6
        y: 6
        width: Math.max(0, (root.body - 12) * root.clamped)
        height: root.height - 12
        radius: 5
        color: root.fill

        Behavior on width { NumberAnimation { duration: Theme.durationMedium } }
    }

    Shape {
        id: bolt

        visible: root.charging
        preferredRendererType: Shape.CurveRenderer

        readonly property real cx: root.body / 2
        readonly property real cy: root.height / 2
        readonly property real u: root.height * 0.06

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.ink.accent

            PathPolyline {
                path: [
                    Qt.point(bolt.cx + bolt.u * 1.2, bolt.cy - bolt.u * 5),
                    Qt.point(bolt.cx - bolt.u * 2.6, bolt.cy + bolt.u * 0.6),
                    Qt.point(bolt.cx + bolt.u * 0.4, bolt.cy + bolt.u * 0.6),
                    Qt.point(bolt.cx - bolt.u * 1.2, bolt.cy + bolt.u * 5),
                    Qt.point(bolt.cx + bolt.u * 2.6, bolt.cy - bolt.u * 0.6),
                    Qt.point(bolt.cx - bolt.u * 0.4, bolt.cy - bolt.u * 0.6),
                    Qt.point(bolt.cx + bolt.u * 1.2, bolt.cy - bolt.u * 5)
                ]
            }
        }
    }
}
