// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A   R   C   S                                                          │
// │   signal strength arcs                                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// Wi-Fi as arcs lit by signal strength, one for weak and three for strong. A
// plug on a cable.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property real size: 120
    property real strength: 0
    property bool connected: false
    property bool wired: false

    readonly property real cx: root.size / 2
    readonly property real dotY: root.size * 0.72
    readonly property real stroke: Math.max(4, root.size * 0.055)

    width: root.size
    height: root.size

    Rectangle {
        visible: !root.wired
        x: root.cx - root.stroke * 0.6
        y: root.dotY - root.stroke * 0.6
        width: root.stroke * 1.2
        height: width
        radius: width / 2
        color: root.connected ? root.ink.text : root.ink.dim
    }

    Shape {
        visible: !root.wired
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Written out three times: a Repeater creates Items, and a ShapePath is
        // not one. Lit at a third, two thirds and full signal.
        ShapePath {
            strokeColor: root.connected ? root.ink.text : root.ink.dim
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.cx; centerY: root.dotY
                radiusX: root.size * 0.16; radiusY: root.size * 0.16
                startAngle: 225; sweepAngle: 90
            }
        }

        ShapePath {
            strokeColor: root.connected && root.strength > 1 / 3 ? root.ink.text : root.ink.dim
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.cx; centerY: root.dotY
                radiusX: root.size * 0.31; radiusY: root.size * 0.31
                startAngle: 225; sweepAngle: 90
            }
        }

        ShapePath {
            strokeColor: root.connected && root.strength > 2 / 3 ? root.ink.text : root.ink.dim
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.cx; centerY: root.dotY
                radiusX: root.size * 0.46; radiusY: root.size * 0.46
                startAngle: 225; sweepAngle: 90
            }
        }
    }

    // A plug: the body, two prongs, the cable.
    Item {
        visible: root.wired
        anchors.fill: parent

        Rectangle {
            x: root.cx - root.size * 0.16
            y: root.size * 0.34
            width: root.size * 0.32
            height: root.size * 0.28
            radius: 6
            color: "transparent"
            border.color: root.ink.text
            border.width: 2.5
        }

        Repeater {
            model: [-0.07, 0.07]

            Rectangle {
                required property real modelData

                x: root.cx + root.size * modelData - 2
                y: root.size * 0.2
                width: 4
                height: root.size * 0.15
                radius: 2
                color: root.ink.text
            }
        }

        Rectangle {
            x: root.cx - 2
            y: root.size * 0.62
            width: 4
            height: root.size * 0.2
            radius: 2
            color: root.ink.text
        }
    }
}
