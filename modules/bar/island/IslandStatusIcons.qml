pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

RowLayout {
    id: root

    required property Item bar

    spacing: 2

    readonly property string iconFont: "Material Symbols Rounded"

    // ═══════════════════════════════════════════════════════════════
    // 1. BRIGHTNESS DYNAMIC ICON (7 Granular States)
    // ═══════════════════════════════════════════════════════════════
    Item {
        id: brightBtn
        implicitWidth: 26
        implicitHeight: 26
        Layout.alignment: Qt.AlignVCenter

        readonly property var currentMonitor: Brightness.getMonitorForScreen(root.bar.screen)
        readonly property real brightnessVal: currentMonitor?.brightness ?? 0.5

        readonly property string iconGlyph: {
            if (brightnessVal <= 0.08) return "nightlight";
            if (brightnessVal <= 0.22) return "brightness_low";
            if (brightnessVal <= 0.40) return "brightness_medium";
            if (brightnessVal <= 0.58) return "brightness_high";
            if (brightnessVal <= 0.76) return "brightness_7";
            if (brightnessVal <= 0.90) return "sunny";
            return "light_mode";
        }

        readonly property color iconColor: {
            if (brightMouse.containsMouse) return Colors.primary;
            if (brightnessVal <= 0.15) return Colors.overSurfaceVariant;
            return Colors.overBackground;
        }

        StyledRect {
            anchors.fill: parent
            radius: 13
            variant: brightMouse.containsMouse ? "focus" : "transparent"
            scale: brightMouse.pressed ? 0.88 : (brightMouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

            DynamicSunIcon {
                anchors.centerIn: parent
                size: 18
                value: brightBtn.brightnessVal
                color: brightBtn.iconColor
                animated: true
            }
        }

        WheelHandler {
            target: brightBtn
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = event.angleDelta.y > 0 ? 0.05 : -0.05;
                const newVal = Math.max(0.05, Math.min(1.0, brightBtn.brightnessVal + delta));
                if (Brightness.syncBrightness) {
                    for (let i = 0; i < Brightness.monitors.length; i++) {
                        const m = Brightness.monitors[i];
                        if (m?.ready) m.setBrightness(newVal);
                    }
                } else if (brightBtn.currentMonitor?.ready) {
                    brightBtn.currentMonitor.setBrightness(newVal);
                }
            }
        }

        MouseArea {
            id: brightMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.bar.expand("dashboard")
        }

        StyledToolTip {
            show: brightMouse.containsMouse
            tooltipText: "Brightness " + Math.round(brightBtn.brightnessVal * 100) + "%"
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 2. VOLUME DYNAMIC ICON (6 Granular States)
    // ═══════════════════════════════════════════════════════════════
    Item {
        id: volBtn
        implicitWidth: 26
        implicitHeight: 26
        Layout.alignment: Qt.AlignVCenter

        readonly property var audioDevice: Audio.sink?.audio ?? null
        readonly property real volumeVal: audioDevice?.volume ?? 0
        readonly property bool isMuted: audioDevice?.muted ?? false

        readonly property string iconGlyph: {
            if (isMuted) return "volume_off";
            if (volumeVal < 0.01) return "volume_mute";
            if (volumeVal < 0.33) return "volume_mute";
            if (volumeVal < 0.66) return "volume_down";
            return "volume_up";
        }

        readonly property color iconColor: {
            if (isMuted) return Colors.error;
            if (volMouse.containsMouse) return Colors.primary;
            if (volumeVal < 0.01) return Colors.overSurfaceVariant;
            return Colors.overBackground;
        }

        StyledRect {
            anchors.fill: parent
            radius: 13
            variant: volMouse.containsMouse ? "focus" : "transparent"
            scale: volMouse.pressed ? 0.88 : (volMouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

            DynamicVolumeIcon {
                anchors.centerIn: parent
                size: 18
                value: volBtn.volumeVal
                muted: volBtn.isMuted
                color: volBtn.iconColor
                animated: true
            }
        }

        WheelHandler {
            target: volBtn
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (volBtn.audioDevice) {
                    const delta = event.angleDelta.y > 0 ? 0.05 : -0.05;
                    volBtn.audioDevice.volume = Math.max(0.0, Math.min(1.0, volBtn.volumeVal + delta));
                }
            }
        }

        MouseArea {
            id: volMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.bar.expand("sound");
                } else {
                    if (volBtn.audioDevice) {
                        volBtn.audioDevice.muted = !volBtn.audioDevice.muted;
                    }
                }
            }
        }

        StyledToolTip {
            show: volMouse.containsMouse
            tooltipText: (volBtn.isMuted ? "Muted " : "Volume ") + Math.round(volBtn.volumeVal * 100) + "%"
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 3. BATTERY DYNAMIC ICON (Plug Icon on Charging + 9 Levels)
    // ═══════════════════════════════════════════════════════════════
    Item {
        id: batBtn
        visible: Battery.available
        implicitWidth: 26
        implicitHeight: 26
        Layout.alignment: Qt.AlignVCenter

        readonly property int percent: Battery.percent
        readonly property bool charging: Battery.charging

        readonly property color iconColor: {
            if (percent < 20 && !charging) return Colors.error;
            if (charging) return Colors.primary;
            if (batMouse.containsMouse) return Colors.primary;
            return Colors.overBackground;
        }

        StyledRect {
            anchors.fill: parent
            radius: 13
            variant: batMouse.containsMouse ? "focus" : "transparent"
            scale: batMouse.pressed ? 0.88 : (batMouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

            DynamicBatteryIcon {
                anchors.centerIn: parent
                size: 18
                percent: batBtn.percent
                charging: batBtn.charging
                color: batBtn.iconColor
                animated: true
            }
        }

        MouseArea {
            id: batMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.bar.expand("battery")
        }

        StyledToolTip {
            show: batMouse.containsMouse
            tooltipText: `${batBtn.percent}%${batBtn.charging ? " (Charging)" : ""}`
        }
    }
}
