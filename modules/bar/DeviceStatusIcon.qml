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
        : Battery.percentage <= 20 ? Colors.red : Styling.srItem("overprimary")

    implicitWidth: Math.round(Styling.fontSize(4) * 1.6)
    implicitHeight: implicitWidth

    function dotColor(index: int): color {
        return Qt.alpha(root.foregroundColor, index < root.wifiDots ? 1 : 0.24);
    }

    BarRadialMeter {
        id: gauge
        anchors.fill: parent
        controlSize: Math.min(root.width, root.height)
        foregroundColor: root.foregroundColor
        progressColor: root.chargeColor
        value: root.chargeLevel
    }

    function dotPosition(index: int): point {
        const angle = (120 - index * 20) * Math.PI / 180;
        return Qt.point(root.width / 2 + gauge.meterRadius * Math.cos(angle),
            root.height / 2 + gauge.meterRadius * Math.sin(angle));
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.dotColor(0)
            strokeWidth: gauge.lineWidth * 1.15
            capStyle: ShapePath.RoundCap
            PathMove { x: root.dotPosition(0).x; y: root.dotPosition(0).y }
            PathLine { x: root.dotPosition(0).x + 0.01; y: root.dotPosition(0).y }
        }
        ShapePath {
            strokeColor: root.dotColor(1)
            strokeWidth: gauge.lineWidth * 1.15
            capStyle: ShapePath.RoundCap
            PathMove { x: root.dotPosition(1).x; y: root.dotPosition(1).y }
            PathLine { x: root.dotPosition(1).x + 0.01; y: root.dotPosition(1).y }
        }
        ShapePath {
            strokeColor: root.dotColor(2)
            strokeWidth: gauge.lineWidth * 1.15
            capStyle: ShapePath.RoundCap
            PathMove { x: root.dotPosition(2).x; y: root.dotPosition(2).y }
            PathLine { x: root.dotPosition(2).x + 0.01; y: root.dotPosition(2).y }
        }
        ShapePath {
            strokeColor: root.dotColor(3)
            strokeWidth: gauge.lineWidth * 1.15
            capStyle: ShapePath.RoundCap
            PathMove { x: root.dotPosition(3).x; y: root.dotPosition(3).y }
            PathLine { x: root.dotPosition(3).x + 0.01; y: root.dotPosition(3).y }
        }
    }

    StyledText {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.height * 0.025
        text: Icons.bluetooth
        font.family: Icons.font
        font.pixelSize: Math.round(root.width * 0.35)
        color: Qt.alpha(root.foregroundColor, BluetoothService.enabled ? 1 : 0.38)
    }

    StyledRect {
        objectName: "deviceStatusChargingBadge"
        visible: Battery.isCharging
        x: root.width * 0.65
        y: root.height * 0.085
        width: root.width * 0.26
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
