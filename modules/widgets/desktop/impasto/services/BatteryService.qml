pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.modules.services as Nonchalant
import qs.modules.widgets.desktop.impasto.theme as Impasto

Singleton {
    readonly property UPowerDevice device: Nonchalant.Battery.primaryDevice
    readonly property bool available: device !== null && device.ready && device.isLaptopBattery
    readonly property int percent: available ? Math.round(Nonchalant.Battery.percentage) : 0
    readonly property int state: Nonchalant.Battery.chargeState
    readonly property bool charging: available && Nonchalant.Battery.isCharging
    readonly property bool full: available && state === UPowerDevice.FullyCharged
    readonly property bool low: available && !charging && !full && percent <= 20
    readonly property real watts: available ? Math.abs(device.changeRate) : 0
    readonly property real energy: available ? device.energy : 0
    readonly property real energyCapacity: available ? device.energyCapacity : 0
    readonly property bool healthKnown: available && device.healthSupported
    readonly property int health: healthKnown ? Math.round(device.healthPercentage) : 0
    readonly property string estimate: {
        if (!available)
            return ""
        if (full)
            return "Fully charged"
        const seconds = charging ? device.timeToFull : device.timeToEmpty
        if (seconds <= 0)
            return charging ? "Charging" : ""
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.round((seconds % 3600) / 60)
        const span = hours > 0 ? `${hours} h ${minutes} min` : `${minutes} min`
        return charging ? `${span} to full` : `${span} left`
    }
    readonly property string stateWord: !available ? ""
        : full ? "Full"
        : charging ? "Charging"
        : "On battery"
    readonly property color tint: !available ? Impasto.Theme.indicatorDim
        : charging || full ? Impasto.Theme.indicatorGood
        : percent <= 15 ? Impasto.Theme.indicatorBad
        : percent <= 35 ? Impasto.Theme.indicatorWarn
        : Impasto.Theme.indicatorGood
    readonly property list<string> levelIcons: [
        "󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"
    ]
    readonly property string icon: {
        if (!available)
            return "󰂑"
        if (charging)
            return "󰂄"
        if (low)
            return "󰂃"
        return levelIcons[Math.max(0, Math.min(10, Math.round(percent / 10)))]
    }
}
