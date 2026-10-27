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
    readonly property bool canInteract: root.bar && !root.bar.isExpanded && !root.bar.isMorphing

    // One notch of a mouse wheel moves a level by 5%; touchpads scroll
    // proportionally instead of jumping 5% per tiny event.
    function wheelStep(angleY: real, pixelY: real): real {
        return (angleY !== 0 ? angleY : pixelY) / 120 * 0.05;
    }

    function adjustBrightness(step: real) {
        const newVal = Math.max(0.05, Math.min(1.0, brightBtn.brightnessVal + step));
        if (Brightness.syncBrightness) {
            for (let i = 0; i < Brightness.monitors.length; i++) {
                const m = Brightness.monitors[i];
                if (m?.ready) m.setBrightness(newVal);
            }
        } else if (brightBtn.currentMonitor?.ready) {
            brightBtn.currentMonitor.setBrightness(newVal);
        } else if (Brightness.monitors.length > 0 && Brightness.monitors[0]?.ready) {
            Brightness.monitors[0].setBrightness(newVal);
        }
    }

    function adjustVolume(step: real) {
        if (!volBtn.audioDevice)
            return;
        if (step > 0 && volBtn.isMuted)
            volBtn.audioDevice.muted = false;
        Audio.setVolume(Math.max(0.0, Math.min(1.0, volBtn.volumeVal + step)));
    }

    function adjustMic(step: real) {
        const mic = Audio.source?.audio ?? null;
        if (!mic)
            return;
        if (step > 0 && mic.muted)
            mic.muted = false;
        Audio.setMicVolume(Math.max(0.0, Math.min(1.0, mic.volume + step)));
    }

    // ═══════════════════════════════════════════════════════════════
    // 1. BRIGHTNESS DYNAMIC ICON (7 Granular States)
    // ═══════════════════════════════════════════════════════════════
    Item {
        id: brightBtn
        implicitWidth: 26
        implicitHeight: 26
        Layout.alignment: Qt.AlignVCenter

        readonly property var currentMonitor: {
            if (root.bar?.screen)
                return Brightness.getMonitorForScreen(root.bar.screen);
            return Brightness.monitors.length > 0 ? Brightness.monitors[0] : null;
        }
        readonly property real brightnessVal: currentMonitor?.brightness ?? (Brightness.monitors.length > 0 ? Brightness.monitors[0]?.brightness ?? 0.5 : 0.5)

        readonly property string iconGlyph: {
            if (brightnessVal <= 0.08) return "nightlight";
            if (brightnessVal <= 0.22) return "brightness_low";
            if (brightnessVal <= 0.40) return "brightness_medium";
            if (brightnessVal <= 0.58) return "brightness_high";
            if (brightnessVal <= 0.76) return "brightness_7";
            if (brightnessVal <= 0.90) return "sunny";
            return "light_mode";
        }

        readonly property bool isHovered: brightMouse.containsMouse && root.canInteract
        readonly property bool isPressed: brightMouse.pressed && isHovered

        readonly property color iconColor: {
            if (isHovered) return Colors.primary;
            if (brightnessVal <= 0.15) return Colors.overSurfaceVariant;
            return Colors.overBackground;
        }

        StyledRect {
            anchors.fill: parent
            radius: 13
            variant: brightBtn.isHovered ? "focus" : "transparent"
            scale: brightBtn.isPressed ? 0.92 : 1.0
            PressBehavior on scale {
                pressed: brightBtn.isPressed
            }

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
            onWheel: event => root.adjustBrightness(root.wheelStep(event.angleDelta.y, event.pixelDelta.y))
        }

        MouseArea {
            id: brightMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.bar.expand("dashboard")
        }

        StyledToolTip {
            show: brightBtn.isHovered
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

        readonly property bool isHovered: volMouse.containsMouse && root.canInteract
        readonly property bool isPressed: volMouse.pressed && isHovered

        readonly property color iconColor: {
            if (isMuted) return Colors.error;
            if (isHovered) return Colors.primary;
            if (volumeVal < 0.01) return Colors.overSurfaceVariant;
            return Colors.overBackground;
        }

        StyledRect {
            anchors.fill: parent
            radius: 13
            variant: volBtn.isHovered ? "focus" : "transparent"
            scale: volBtn.isPressed ? 0.92 : 1.0
            PressBehavior on scale {
                pressed: volBtn.isPressed
            }

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
            onWheel: event => root.adjustVolume(root.wheelStep(event.angleDelta.y, event.pixelDelta.y))
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
            show: volBtn.isHovered
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

        readonly property bool isHovered: batMouse.containsMouse && root.canInteract
        readonly property bool isPressed: batMouse.pressed && isHovered

        readonly property color iconColor: {
            if (percent < 20 && !charging) return Colors.error;
            if (charging) return Colors.primary;
            if (isHovered) return Colors.primary;
            return Colors.overBackground;
        }

        StyledRect {
            anchors.fill: parent
            radius: 13
            variant: batBtn.isHovered ? "focus" : "transparent"
            scale: batBtn.isPressed ? 0.92 : 1.0
            PressBehavior on scale {
                pressed: batBtn.isPressed
            }

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
            show: batBtn.isHovered
            tooltipText: `${batBtn.percent}%${batBtn.charging ? " (Charging)" : ""}`
        }
    }
}
