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

    implicitWidth: Styling.fontSize(4) * 1.5
    implicitHeight: implicitWidth

    function dotColor(index: int): color {
        return Qt.alpha(root.foregroundColor, index < root.wifiDots ? 1 : 0.2);
    }

    Shape {
        width: 28
        height: 28
        scale: root.width / 28
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        // Leave the bottom of the battery gauge open for the four Wi-Fi dots.
        ShapePath {
            strokeColor: Qt.alpha(root.foregroundColor, 0.18)
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: 14; centerY: 13
                radiusX: 12; radiusY: 12
                startAngle: 124; sweepAngle: 292
            }
        }
        ShapePath {
            strokeColor: Battery.available ? Battery.statusColor() : root.foregroundColor
            strokeWidth: root.chargeLevel > 0 ? 2 : 0
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: 14; centerY: 13
                radiusX: 12; radiusY: 12
                startAngle: 124; sweepAngle: 292 * root.chargeLevel
            }
        }
        ShapePath {
            strokeColor: Qt.alpha(root.foregroundColor, BluetoothService.enabled ? 1 : 0.35)
            strokeWidth: 1.9
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            PathSvg { path: "M 13 6 V 19 L 18 14.5 L 9 7.5 M 9 17.5 L 18 10.5 L 13 6" }
        }
        ShapePath {
            strokeColor: root.dotColor(0)
            strokeWidth: 2.4
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 8.3 26 L 8.31 26" }
        }
        ShapePath {
            strokeColor: root.dotColor(1)
            strokeWidth: 2.4
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 12.1 26 L 12.11 26" }
        }
        ShapePath {
            strokeColor: root.dotColor(2)
            strokeWidth: 2.4
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 15.9 26 L 15.91 26" }
        }
        ShapePath {
            strokeColor: root.dotColor(3)
            strokeWidth: 2.4
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 19.7 26 L 19.71 26" }
        }
    }

    StyledRect {
        objectName: "deviceStatusChargingBadge"
        visible: Battery.isCharging
        x: root.width * 0.69
        y: -root.height * 0.03
        width: root.width * 0.42
        height: width
        radius: width / 2
        variant: root.selected ? "focus" : "pane"
        enableBorder: false
        enableShadow: false

        StyledText {
            anchors.centerIn: parent
            text: Icons.lightning
            font.family: Icons.font
            font.pixelSize: parent.width * 0.9
            color: Colors.green
        }
    }
}
