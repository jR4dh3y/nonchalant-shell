pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services as Nonchalant

Singleton {
    function currentMonitor(): var {
        const focusedName = Nonchalant.NiriService.focusedMonitor?.name ?? ""
        return Nonchalant.Brightness.monitors.find(monitor => monitor.ready
            && monitor.screen.name === focusedName)
            ?? Nonchalant.Brightness.monitors.find(monitor => monitor.ready)
            ?? null
    }
    readonly property bool available: currentMonitor() !== null
    readonly property int percent: available ? Math.round(currentMonitor().brightness * 100) : 0
    readonly property string icon: !available ? "󰃞"
        : percent < 34 ? "󰃞"
        : percent < 67 ? "󰃟" : "󰃠"

    function setPercent(value: real): void {
        const monitor = currentMonitor()
        if (monitor)
            monitor.setBrightness(Math.max(0, Math.min(100, value)) / 100)
    }

    function step(delta: real): void {
        const monitor = currentMonitor()
        if (monitor)
            monitor.setBrightness(monitor.brightness + delta / 100)
    }
}
