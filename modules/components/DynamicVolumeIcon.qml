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
    property bool useMaterialFont: false
    property bool useCanvas: false

    readonly property real clampedValue: Math.max(0.0, Math.min(1.0, value))

    implicitWidth: size
    implicitHeight: size

    // Material Symbols glyph mapping (fallback / testing parity)
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

        // Primary: Phosphor Icon font (perfect match with nonchalant shell outline styling and visual weight)
        Text {
            id: phosphorGlyph
            visible: !root.useMaterialFont && !root.useCanvas
            anchors.centerIn: parent
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            text: {
                if (root.muted) return Icons.speakerSlash;
                if (root.clampedValue < 0.01) return Icons.speakerNone;
                if (root.clampedValue <= 0.50) return Icons.speakerLow;
                return Icons.speakerHigh;
            }
            font.family: Icons.font
            font.pixelSize: root.size
            color: root.color

            Behavior on color {
                enabled: root.animated
                ColorAnimation { duration: 160 }
            }
        }

        // Option 1: Official Material Symbols Rounded Font (Fallback)
        Text {
            id: fontGlyph
            visible: root.useMaterialFont
            anchors.centerIn: parent
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            text: root.iconGlyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: Math.round(root.size * 1.12)
            color: root.color

            Behavior on color {
                enabled: root.animated
                ColorAnimation { duration: 160 }
            }
        }

        // Option 2: Unified mathematically balanced vector path (Canvas fallback)
        Canvas {
            id: vectorCanvas
            visible: root.useCanvas
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = root.color;
                ctx.strokeStyle = root.color;
                var cy = height / 2.0;

                var bx0 = Math.round(width * 0.10);
                var bx1 = Math.round(width * 0.28);
                var cx1 = Math.round(width * 0.48);
                var bh = Math.round(height * 0.16);
                var ch = Math.round(height * 0.36);

                ctx.beginPath();
                ctx.moveTo(bx0, cy - bh);
                ctx.lineTo(bx1, cy - bh);
                ctx.lineTo(cx1, cy - ch);
                ctx.lineTo(cx1, cy + ch);
                ctx.lineTo(bx1, cy + bh);
                ctx.lineTo(bx0, cy + bh);
                ctx.closePath();
                ctx.fill();

                ctx.lineWidth = 1.5;
                ctx.lineCap = "round";

                if (root.muted) {
                    ctx.beginPath();
                    ctx.moveTo(cx1 + 3, cy - ch);
                    ctx.lineTo(width - 1, cy + ch);
                    ctx.stroke();
                } else {
                    var arcCenter = cx1 - 2;
                    if (root.clampedValue > 0.05) {
                        ctx.beginPath();
                        ctx.arc(arcCenter, cy, width * 0.25, -0.65, 0.65);
                        ctx.stroke();
                    }
                    if (root.clampedValue > 0.50) {
                        ctx.beginPath();
                        ctx.arc(arcCenter, cy, width * 0.42, -0.68, 0.68);
                        ctx.stroke();
                    }
                }
            }

            Connections {
                target: root
                function onColorChanged() { if (root.useCanvas) vectorCanvas.requestPaint(); }
                function onValueChanged() { if (root.useCanvas) vectorCanvas.requestPaint(); }
                function onMutedChanged() { if (root.useCanvas) vectorCanvas.requestPaint(); }
            }

            Component.onCompleted: {
                if (root.useCanvas) vectorCanvas.requestPaint();
            }
        }
    }
}
