pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme

Item {
    id: root

    property real value: 0.5
    property bool muted: false
    property real size: 18
    property color color: muted ? Colors.error : (clampedValue < 0.01 ? Colors.overSurfaceVariant : (clampedValue <= 0.85 ? Colors.primary : Colors.yellow))
    property bool animated: true
    property bool useMaterialFont: true

    readonly property real clampedValue: Math.max(0.0, Math.min(1.0, value))

    implicitWidth: size
    implicitHeight: size

    // Material Symbols glyph mapping (4 distinct audio states)
    readonly property string iconGlyph: {
        if (muted) return "volume_off";
        if (clampedValue < 0.01) return "volume_mute";
        if (clampedValue <= 0.50) return "volume_down";
        return "volume_up";
    }

    Item {
        anchors.centerIn: parent
        width: root.size
        height: root.size

        // Option 1: Official Material Symbols Rounded Font (Perfect symmetry, native hinting)
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

        // Option 2: Unified mathematically balanced vector path (seamless cone-to-base, no stepping)
        Canvas {
            id: vectorCanvas
            visible: !root.useMaterialFont
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = root.color;
                ctx.strokeStyle = root.color;
                var cy = height / 2.0;

                // Single unified polygon: base + cone with perfect symmetry around cy
                var bx0 = Math.round(width * 0.08);
                var bx1 = Math.round(width * 0.28);
                var cx1 = Math.round(width * 0.54);
                var bh = Math.round(height * 0.16);
                var ch = Math.round(height * 0.34);

                ctx.beginPath();
                ctx.moveTo(bx0, cy - bh);
                ctx.lineTo(bx1, cy - bh);
                ctx.lineTo(cx1, cy - ch);
                ctx.lineTo(cx1, cy + ch);
                ctx.lineTo(bx1, cy + bh);
                ctx.lineTo(bx0, cy + bh);
                ctx.closePath();
                ctx.fill();

                ctx.lineWidth = Math.max(1.5, Math.round(width * 0.09));
                ctx.lineCap = "round";

                if (root.muted) {
                    // Mute slash
                    ctx.beginPath();
                    ctx.moveTo(cx1 + 3, cy - ch);
                    ctx.lineTo(width - 1, cy + ch);
                    ctx.stroke();
                } else {
                    // Wave arcs
                    if (root.clampedValue > 0.05) {
                        ctx.beginPath();
                        ctx.arc(bx1 + 1, cy, width * 0.32, -0.65, 0.65);
                        ctx.stroke();
                    }
                    if (root.clampedValue > 0.50) {
                        ctx.beginPath();
                        ctx.arc(bx1, cy, width * 0.48, -0.70, 0.70);
                        ctx.stroke();
                    }
                }
            }

            Connections {
                target: root
                function onColorChanged() { if (!root.useMaterialFont) vectorCanvas.requestPaint(); }
                function onValueChanged() { if (!root.useMaterialFont) vectorCanvas.requestPaint(); }
                function onMutedChanged() { if (!root.useMaterialFont) vectorCanvas.requestPaint(); }
            }

            Component.onCompleted: {
                if (!root.useMaterialFont) vectorCanvas.requestPaint();
            }
        }
    }
}
