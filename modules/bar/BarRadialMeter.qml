pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.theme
import "../components/RoundedTrack.js" as RoundedTrack

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
    // Concentric with the pill-shaped button around it, so the ring squares
    // off together with the button as roundness drops.
    property real cornerRadius: Math.max(0, Styling.pillRadius(root.controlSize) - (root.controlSize / 2 - root.meterRadius))
    property color foregroundColor: Colors.overBackground
    property color trackColor: Qt.alpha(root.foregroundColor, 0.24)
    property color progressColor: Styling.srItem("overprimary")
    readonly property real normalizedValue: Math.max(0, Math.min(1, root.value))

    // Point on the ring at `deg` (Qt angles), for markers placed along it.
    function pointAt(deg: real): point {
        const p = RoundedTrack.boundaryPoint(root.width / 2, root.height / 2, root.meterRadius, root.cornerRadius, deg);
        return Qt.point(p.x, p.y);
    }

    function trace(sweep: real, fraction: real): list<point> {
        const pts = RoundedTrack.trace(root.width / 2, root.height / 2, root.meterRadius, root.cornerRadius, root.startAngle, sweep, fraction);
        // PathPolyline rejects an empty list; an empty meter is one
        // (transparent) point at the start.
        return pts.length > 0 ? pts.map(p => Qt.point(p.x, p.y)) : [root.pointAt(root.startAngle)];
    }

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
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            PathPolyline {
                path: root.trace(root.spanAngle, 1)
            }
        }
        ShapePath {
            strokeColor: root.normalizedValue > 0 ? root.progressColor : "transparent"
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            PathPolyline {
                path: root.trace(root.spanAngle, root.normalizedValue)
            }
        }
    }
}
