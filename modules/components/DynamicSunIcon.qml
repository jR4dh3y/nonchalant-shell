pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme

Item {
    id: root

    property real value: 1.0
    property real size: 20
    property color color: clampedValue <= 0.22 ? Colors.overSurfaceVariant : (clampedValue <= 0.58 ? Colors.yellow : Colors.primary)
    property bool animated: true
    property real rotationMultiplier: 180

    readonly property real clampedValue: Math.max(0.0, Math.min(1.0, value))
    readonly property real ringDiameter: Math.round(size * 0.46)
    readonly property real ringBorderWidth: Math.max(1.5, Math.round(size * 0.08))
    readonly property real gap: Math.max(1.5, size * 0.08)
    readonly property real baseOffset: (ringDiameter / 2) + gap
    readonly property real maxRayLength: Math.max(1.5, (size / 2) - baseOffset)
    readonly property real rayLength: maxRayLength * clampedValue
    readonly property real rayThickness: Math.max(1.5, Math.round(size * 0.08))

    implicitWidth: size
    implicitHeight: size

    Item {
        id: container
        anchors.centerIn: parent
        width: root.size
        height: root.size
        rotation: root.clampedValue * root.rotationMultiplier

        Behavior on rotation {
            enabled: root.animated
            NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
        }

        // Central hollow ring
        Rectangle {
            anchors.centerIn: parent
            width: root.ringDiameter
            height: root.ringDiameter
            radius: width / 2
            color: "transparent"
            border.color: root.color
            border.width: root.ringBorderWidth

            Behavior on border.color {
                enabled: root.animated
                ColorAnimation { duration: 160 }
            }
        }

        // 8 Radial rays that dynamically grow and shrink
        Repeater {
            model: 8

            Item {
                required property int index
                anchors.centerIn: parent
                width: root.size
                height: root.size
                rotation: index * 45

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.rayThickness
                    height: Math.max(0, root.rayLength)
                    radius: root.rayThickness / 2
                    color: root.color
                    opacity: root.clampedValue > 0.05 ? 1.0 : (root.clampedValue / 0.05)
                    y: Math.round((parent.height / 2) - root.baseOffset - height)

                    Behavior on height {
                        enabled: root.animated
                        NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                    }
                    Behavior on y {
                        enabled: root.animated
                        NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                    }
                    Behavior on opacity {
                        enabled: root.animated
                        NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                    }
                    Behavior on color {
                        enabled: root.animated
                        ColorAnimation { duration: 160 }
                    }
                }
            }
        }
    }
}
