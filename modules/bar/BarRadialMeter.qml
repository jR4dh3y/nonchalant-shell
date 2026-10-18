pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.theme

// Shared geometry for the audio, brightness and device-status droplets.
Item {
    id: root

    required property real controlSize
    property real value: 0
    property real startAngle: 140
    property real spanAngle: 260
    readonly property real standardRadius: root.controlSize * 0.4
    readonly property real standardLineWidth: root.controlSize / 16
    property real meterRadius: root.standardRadius
    property real lineWidth: root.standardLineWidth
    property color foregroundColor: Colors.overBackground
    property color trackColor: Qt.alpha(root.foregroundColor, 0.24)
    property color progressColor: Styling.srItem("overprimary")
    readonly property real normalizedValue: Math.max(0, Math.min(1, root.value))

    implicitWidth: controlSize
    implicitHeight: controlSize

    Behavior on value {
        enabled: Motion.enabled
        NumberAnimation { duration: Motion.fadeInDuration; easing.type: Easing.OutCubic }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.meterRadius; radiusY: root.meterRadius
                startAngle: root.startAngle; sweepAngle: root.spanAngle
            }
        }
        ShapePath {
            strokeColor: root.normalizedValue > 0 ? root.progressColor : "transparent"
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.meterRadius; radiusY: root.meterRadius
                startAngle: root.startAngle; sweepAngle: root.spanAngle * root.normalizedValue
            }
        }
    }
}
