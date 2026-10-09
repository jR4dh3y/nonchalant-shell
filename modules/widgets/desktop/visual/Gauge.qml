pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real value: 0
    property real thickness: Math.max(2, width * 0.07)
    property color trackColor: "transparent"
    property color fillColor: "white"

    readonly property real side: Math.min(root.width, root.height)
    readonly property real radius: Math.max(0, (root.side - root.thickness) / 2)
    readonly property real fraction: Math.max(0, Math.min(1, root.value))

    Shape {
        anchors.centerIn: parent
        width: root.side
        height: root.side
        antialiasing: true

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.side / 2
                centerY: root.side / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 359.9
            }
        }

        ShapePath {
            strokeColor: root.fillColor
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.side / 2
                centerY: root.side / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 359.9 * root.fraction
            }
        }
    }
}