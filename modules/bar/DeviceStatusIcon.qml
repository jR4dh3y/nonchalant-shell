pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    required property color foregroundColor
    property bool selected: false
    readonly property real chargeLevel: Battery.available ? Math.max(0, Math.min(1, Battery.percentage / 100)) : 1
    readonly property int wifiDots: NetworkService.wifiConnected
        ? Math.max(1, Math.min(4, Math.ceil(NetworkService.networkStrength / 25))) : 0
    readonly property color chargeColor: !Battery.available ? root.foregroundColor
        : Battery.isCharging ? Colors.green
        : Battery.percentage <= 20 ? Colors.red : root.foregroundColor

    implicitWidth: Math.round(Styling.fontSize(4) * 1.6)
    implicitHeight: implicitWidth

    function dotColor(index: int): color {
        return Qt.alpha(root.foregroundColor, index < root.wifiDots ? 1 : 0.28);
    }

    Shape {
        width: 32
        height: 32
        scale: root.width / 32
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        // One circular contour: the gauge leaves 100 degrees for four dots,
        // spaced every 20 degrees along the same radius.
        ShapePath {
            strokeColor: Qt.alpha(root.foregroundColor, 0.28)
            strokeWidth: 3
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: 16; centerY: 16
                radiusX: 12.3; radiusY: 12.3
                startAngle: 140; sweepAngle: 260
            }
        }
        ShapePath {
            strokeColor: root.chargeLevel > 0 ? root.chargeColor : "transparent"
            strokeWidth: 3
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: 16; centerY: 16
                radiusX: 12.3; radiusY: 12.3
                startAngle: 140; sweepAngle: 260 * root.chargeLevel
            }
        }
        ShapePath {
            strokeColor: root.dotColor(0)
            strokeWidth: 2.8
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 9.85 26.65 L 9.86 26.65" }
        }
        ShapePath {
            strokeColor: root.dotColor(1)
            strokeWidth: 2.8
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 13.864 28.113 L 13.874 28.113" }
        }
        ShapePath {
            strokeColor: root.dotColor(2)
            strokeWidth: 2.8
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 18.136 28.113 L 18.146 28.113" }
        }
        ShapePath {
            strokeColor: root.dotColor(3)
            strokeWidth: 2.8
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 22.15 26.65 L 22.16 26.65" }
        }
    }

    StyledText {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.height * 0.025
        text: Icons.bluetooth
        font.family: Icons.font
        font.pixelSize: Math.round(root.width * 0.48)
        color: Qt.alpha(root.foregroundColor, BluetoothService.enabled ? 1 : 0.38)
    }

    StyledRect {
        objectName: "deviceStatusChargingBadge"
        visible: Battery.isCharging
        x: root.width * 0.68
        y: -root.height * 0.01
        width: root.width * 0.42
        height: width
        radius: width / 2
        variant: root.selected ? "focus" : "pane"
        enableBorder: false
        enableShadow: false

        Shape {
            anchors.centerIn: parent
            width: 7
            height: 10
            scale: parent.height * 0.8 / height
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillColor: Colors.green
                PathSvg { path: "M 4 0 L 0 5.5 H 3 L 2 10 L 7 3.5 H 4 Z" }
            }
        }
    }
}
