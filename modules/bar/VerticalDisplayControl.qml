pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    required property Item bar
    required property int controlSize
    // Monitors without software brightness (no backlight, no DDC/CI) keep only night light.
    readonly property bool brightnessAvailable: Brightness.isAvailable(root.bar.screen)
    readonly property bool split: NightLightService.active && brightnessAvailable
    property real splitProgress: split ? 1 : 0
    readonly property real splitAmount: Math.max(0, splitProgress)
    readonly property real brightness: Brightness.getMonitorForScreen(root.bar.screen)?.brightness ?? 0.5

    implicitWidth: controlSize
    implicitHeight: controlSize
    scale: brightnessHalf.pressed || temperatureHalf.pressed ? 0.94 : 1
    PressBehavior on scale { pressed: brightnessHalf.pressed || temperatureHalf.pressed }

    Behavior on splitProgress {
        enabled: Motion.enabled
        NumberAnimation {
            duration: root.split ? Motion.expandDuration : Motion.collapseDuration
            easing.type: root.split ? Easing.OutBack : Easing.OutQuad
            easing.overshoot: Motion.overshoot
        }
    }

    BarRadialMeter {
        anchors.fill: parent
        visible: root.brightnessAvailable || NightLightService.active
        controlSize: root.controlSize
        value: root.brightnessAvailable ? root.brightness : NightLightService.normalizedTemperature
        startAngle: 140 + 48 * root.splitAmount
        spanAngle: 260 - 96 * root.splitAmount
    }

    BarRadialMeter {
        anchors.fill: parent
        opacity: root.splitAmount
        visible: opacity > 0
        controlSize: root.controlSize
        value: NightLightService.normalizedTemperature
        foregroundColor: temperatureHalf.foregroundColor
        startAngle: 8
        spanAngle: 164 * root.splitAmount
    }

    component DisplayHalf: Item {
        id: half
        required property bool temperature
        readonly property bool pressed: mouse.pressed
        readonly property color foregroundColor: Colors.overBackground
        readonly property string title: temperature
            ? "Night Light: " + NightLightService.temperature + " K"
            : "Brightness " + Math.round(root.brightness * 100) + "%"
        width: root.controlSize
        height: root.controlSize * (1 - root.splitAmount / 2)
        z: -1
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: title
        Accessible.onPressAction: NightLightService.toggle()

        function adjust(direction: real): void {
            if (temperature)
                NightLightService.setTemperature(NightLightService.temperature + direction * 100);
            else
                Brightness.setBrightnessForScreen(root.bar.screen,
                    Math.max(0, Math.min(1, root.brightness + direction * 0.05)));
        }

        Keys.onSpacePressed: NightLightService.toggle()
        Keys.onReturnPressed: NightLightService.toggle()
        Keys.onUpPressed: half.adjust(1)
        Keys.onDownPressed: half.adjust(-1)

        Item {
            anchors.fill: parent
            clip: true

            StyledRect {
                id: halfSurface
                width: root.width
                height: root.height
                y: -half.y
                radius: Styling.pillRadius(width)
                variant: "pane"
                enableBorder: false
                enableShadow: false
                HoverTint {
                    hovered: mouse.containsMouse
                    pressed: mouse.pressed
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: (half.temperature ? -1 : 1) * root.height * 0.07 * root.splitAmount
            text: half.temperature ? Icons.temperature : Icons.sun
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(3) + (root.controlSize * 0.29 - Styling.fontSize(3)) * root.splitAmount
            color: half.foregroundColor
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: NightLightService.toggle()
            onWheel: event => {
                const delta = event.angleDelta.y || event.angleDelta.x;
                if (delta === 0)
                    return;
                half.adjust(delta > 0 ? 1 : -1);
                event.accepted = true;
            }
        }

        StyledToolTip {
            x: root.width + root.controlSize / 5
            show: mouse.containsMouse
            tooltipText: half.title
            description: "Click to turn night light " + (NightLightService.active ? "off" : "on") + " · Scroll to adjust"
        }
    }

    DisplayHalf {
        id: brightnessHalf
        objectName: "verticalBrightnessControl"
        temperature: !root.brightnessAvailable
    }

    DisplayHalf {
        id: temperatureHalf
        objectName: "verticalTemperatureControl"
        y: brightnessHalf.height
        height: root.height - y
        opacity: root.splitAmount
        visible: root.splitAmount > 0
        enabled: root.split
        temperature: true
    }
}
