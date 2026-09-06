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
    property bool useMaterialFont: true

    readonly property real clampedPct: Math.max(0, Math.min(100, percent))

    implicitWidth: size
    implicitHeight: size

    // Material Symbols glyph mapping (9-bar resolution + charging plug)
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

        // Option 2: Geometric battery capsule with fill bar (fallback)
        Item {
            visible: !root.useMaterialFont
            anchors.fill: parent

            // When charging: Wall plug icon
            Text {
                visible: root.charging
                anchors.centerIn: parent
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "power"
                font.family: "Material Symbols Rounded"
                font.pixelSize: root.size
                color: root.color

                Behavior on color {
                    enabled: root.animated
                    ColorAnimation { duration: 160 }
                }
            }

            // When discharging: Geometric battery capsule with fill bar
            Item {
                visible: !root.charging
                anchors.centerIn: parent
                readonly property real bodyWidth: Math.round(root.size * 0.80)
                readonly property real bodyHeight: Math.round(root.size * 0.48)
                width: bodyWidth + 2.5
                height: bodyHeight

                // Battery body capsule
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.bodyWidth
                    height: parent.bodyHeight
                    radius: 2.5
                    color: "transparent"
                    border.color: root.color
                    border.width: 1.5

                    Behavior on border.color {
                        enabled: root.animated
                        ColorAnimation { duration: 160 }
                    }

                    // Inner fill bar
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property real maxFillW: parent.width - 4
                        width: Math.max(0, maxFillW * (root.clampedPct / 100.0))
                        height: parent.height - 4
                        radius: 1
                        color: root.color

                        Behavior on width {
                            enabled: root.animated
                            NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                        }

                        Behavior on color {
                            enabled: root.animated
                            ColorAnimation { duration: 160 }
                        }
                    }
                }

                // Cathode terminal nipple (+ pole)
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2.5
                    height: Math.round(parent.bodyHeight * 0.45)
                    radius: 1
                    color: root.color

                    Behavior on color {
                        enabled: root.animated
                        ColorAnimation { duration: 160 }
                    }
                }
            }
        }
    }
}
