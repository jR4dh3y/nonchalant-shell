pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme

Item {
    id: root

    property int percent: 100
    property bool charging: false
    property real size: 18
    property color color: charging ? Colors.green : (percent < 20 ? Colors.error : (percent < 50 ? Colors.yellow : Colors.overBackground))
    property bool animated: true
    property bool useMaterialFont: false

    readonly property real clampedPct: Math.max(0, Math.min(100, percent))

    implicitWidth: size
    implicitHeight: size

    // Dimensions mathematically calculated to have identical even parity for pixel-perfect left-right symmetry
    readonly property int bodyWidth: Math.max(6, Math.round(size * 0.52 / 2.0) * 2)
    readonly property int capWidth: Math.max(2, Math.round(bodyWidth * 0.40 / 2.0) * 2)
    readonly property int capHeight: Math.max(1, Math.round(size * 0.10))
    readonly property int bodyHeight: Math.max(8, Math.round(size * 0.70))

    // Material Symbols glyph mapping (fallback / testing parity)
    readonly property string iconGlyph: {
        if (charging) return "power";
        if (clampedPct < 15) return "battery_alert";
        if (clampedPct < 25) return "battery_0_bar";
        if (clampedPct < 38) return "battery_1_bar";
        if (clampedPct < 50) return "battery_2_bar";
        if (clampedPct < 62) return "battery_3_bar";
        if (clampedPct < 74) return "battery_4_bar";
        if (clampedPct < 86) return "battery_5_bar";
        if (clampedPct < 95) return "battery_6_bar";
        return "battery_full";
    }

    // ─────────────────────────────────────────────────────────────
    // Primary: Mathematically centered, pixel-perfect vector battery
    // ─────────────────────────────────────────────────────────────
    Item {
        id: container
        visible: !root.useMaterialFont
        anchors.centerIn: parent
        width: root.bodyWidth
        height: root.capHeight + 1 + root.bodyHeight

        // Cathode terminal cap (100% horizontal center alignment with identical left and right shoulders)
        Rectangle {
            id: cap
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: root.capWidth
            height: root.capHeight
            radius: 1
            color: root.color

            Behavior on color {
                enabled: root.animated
                ColorAnimation { duration: 160 }
            }
        }

        // Battery capsule body
        Rectangle {
            id: bodyCapsule
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: cap.bottom
            anchors.topMargin: 1
            anchors.bottom: parent.bottom
            width: root.bodyWidth
            radius: Math.max(2, Math.round(root.bodyWidth * 0.22))
            color: (root.clampedPct >= 95 && !root.charging) ? root.color : "transparent"
            border.color: root.color
            border.width: 1.5

            Behavior on color {
                enabled: root.animated
                ColorAnimation { duration: 160 }
            }

            Behavior on border.color {
                enabled: root.animated
                ColorAnimation { duration: 160 }
            }

            // Subtle track background when empty / discharging
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.alpha(root.color, 0.12)
                visible: !root.charging && root.clampedPct < 95
            }

            // Dynamic fluid fill rising from bottom
            Rectangle {
                id: fillLevel
                visible: !root.charging && root.clampedPct < 95 && root.clampedPct > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1.5
                readonly property real maxFillW: parent.width - 3
                readonly property real maxFillH: parent.height - 3
                width: maxFillW
                height: Math.max(1, Math.round(maxFillH * (root.clampedPct / 100.0)))
                radius: 1
                color: root.color

                Behavior on height {
                    enabled: root.animated
                    NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                }

                Behavior on color {
                    enabled: root.animated
                    ColorAnimation { duration: 160 }
                }
            }

            // Centered lightning bolt when charging
            Canvas {
                id: boltCanvas
                visible: root.charging
                anchors.centerIn: parent
                width: parent.width
                height: parent.height

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = root.color;
                    const cx = width / 2.0;
                    const cy = height / 2.0;
                    const scaleH = height / 14.0;
                    const scaleW = width / 10.0;

                    ctx.beginPath();
                    ctx.moveTo(cx + (0.8 * scaleW), cy - (3.8 * scaleH));
                    ctx.lineTo(cx - (2.0 * scaleW), cy + (0.2 * scaleH));
                    ctx.lineTo(cx - (0.2 * scaleW), cy + (0.2 * scaleH));
                    ctx.lineTo(cx - (0.8 * scaleW), cy + (3.8 * scaleH));
                    ctx.lineTo(cx + (2.0 * scaleW), cy - (0.2 * scaleH));
                    ctx.lineTo(cx + (0.2 * scaleW), cy - (0.2 * scaleH));
                    ctx.closePath();
                    ctx.fill();
                }

                Connections {
                    target: root
                    function onColorChanged() { if (root.charging) boltCanvas.requestPaint(); }
                    function onChargingChanged() { if (root.charging) boltCanvas.requestPaint(); }
                }

                Component.onCompleted: {
                    if (root.charging) boltCanvas.requestPaint();
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Optional Font Fallback: Material Symbols (when useMaterialFont: true)
    // ─────────────────────────────────────────────────────────────
    Text {
        id: fontGlyph
        visible: root.useMaterialFont
        anchors.centerIn: parent
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        text: root.iconGlyph
        font.family: "Material Symbols Rounded"
        font.pixelSize: root.size
        color: root.color

        Behavior on color {
            enabled: root.animated
            ColorAnimation { duration: 160 }
        }
    }
}
