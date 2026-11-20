pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.UPower as UPowerService
import qs.modules.theme

Singleton {
    id: root

    readonly property UPowerService.UPowerDevice primaryDevice: UPowerService.UPower.displayDevice

    readonly property bool available: primaryDevice !== null && primaryDevice.ready && primaryDevice.isPresent && primaryDevice.type === UPowerService.UPowerDeviceType.Battery
    readonly property real percentage: available ? (primaryDevice.percentage * 100) : 0
    readonly property bool isCharging: available && primaryDevice.state === UPowerService.UPowerDeviceState.Charging
    readonly property bool isPluggedIn: available && (primaryDevice.state === UPowerService.UPowerDeviceState.Charging || primaryDevice.state === UPowerService.UPowerDeviceState.FullyCharged)
    readonly property real percent: percentage
    readonly property bool charging: isPluggedIn
    readonly property int chargeState: available ? primaryDevice.state : UPowerService.UPowerDeviceState.Unknown
    property int lastBatteryAlertThreshold: 0

    // Add some helpful descriptive properties if needed
    readonly property string timeToEmpty: available && primaryDevice.timeToEmpty > 0 ? formatTime(primaryDevice.timeToEmpty) : ""
    readonly property string timeToFull: available && primaryDevice.timeToFull > 0 ? formatTime(primaryDevice.timeToFull) : ""

    function formatTime(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    function getBatteryIcon() {
        if (!available) return Icons.batteryEmpty;
        if (isPluggedIn) return Icons.batteryCharging;
        
        const pct = percentage;
        if (pct > 75) return Icons.batteryFull;
        if (pct > 50) return Icons.batteryHigh;
        if (pct > 25) return Icons.batteryMedium;
        if (pct > 5) return Icons.batteryLow;
        return Icons.batteryEmpty;
    }

    // Charge color shared by every bar: charging success, at most 15% danger,
    // at most 30% warning, otherwise the accent. Status roles keep their hue
    // on every wallpaper, unlike the old red-to-green slot blend.
    function statusColor(palette: ShellPalette): color {
        if (!root.available)
            return palette.overBackground;
        if (root.isCharging)
            return palette.success;
        if (root.percentage <= 15)
            return palette.danger;
        return root.percentage <= 30 ? palette.warning : palette.primary;
    }

    function evaluateBatteryAlert() {
        if (!available || isPluggedIn) {
            lastBatteryAlertThreshold = 0;
            return;
        }

        const roundedPercentage = Math.floor(percentage);
        const threshold = roundedPercentage <= 10 ? 10 : (roundedPercentage <= 20 ? 20 : 0);
        if (threshold === 0) {
            lastBatteryAlertThreshold = 0;
            return;
        }

        if (threshold === lastBatteryAlertThreshold) {
            return;
        }

        sendBatteryAlert(threshold, roundedPercentage);
        lastBatteryAlertThreshold = threshold;
    }

    function sendBatteryAlert(threshold, roundedPercentage) {
        const isCritical = threshold <= 10;
        Notifications.notifyInternal({
            "appName": "Battery",
            "summary": isCritical ? "Critical battery" : "Low battery",
            "body": "Battery is at " + roundedPercentage + "%." + (isCritical ? " Connect your charger or enable power saver." : " Enable power saver to reduce consumption."),
            "urgency": NotificationUrgency.Critical,
            "historyPriority": 100,
            "bypassDoNotDisturb": true,
            "replaceKey": "battery-low-alert",
            "expireTimeout": 10000,
            "actions": [{
                    "identifier": "enable-power-saver",
                    "text": "Power saver"
                }, {
                    "identifier": "dismiss",
                    "text": "Ignore"
                }],
            "actionHandlers": {
                "enable-power-saver": function () {
                    PowerProfile.setProfile("power-saver");
                },
                "dismiss": function (id) {
                    Notifications.discardNotification(id);
                }
            }
        });
    }

    Connections {
        target: root

        function onAvailableChanged() {
            root.evaluateBatteryAlert();
        }

        function onPercentageChanged() {
            root.evaluateBatteryAlert();
        }

        function onIsPluggedInChanged() {
            root.evaluateBatteryAlert();
        }
    }

    Component.onCompleted: Qt.callLater(root.evaluateBatteryAlert)
}
