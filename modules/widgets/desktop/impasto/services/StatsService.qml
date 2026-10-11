pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services as Nonchalant

Singleton {
    id: root

    readonly property int pollInterval: 3000
    readonly property int historyLength: 100
    property int watchers: 0
    property bool ready: false

    property real cpu: 0
    property string cpuModel: Nonchalant.SystemResources.cpuModel
    property list<real> load: [0, 0, 0]
    property real memoryUsed: 0
    property real memoryTotal: 0
    property real networkDown: 0
    property real networkUp: 0
    property var temperature: null
    property int uptime: 0

    property list<real> cpuHistory: []
    property list<real> memoryHistory: []
    property list<real> downHistory: []
    property list<real> upHistory: []
    property list<real> temperatureHistory: []

    readonly property real memoryFraction: root.memoryTotal > 0
        ? root.memoryUsed / root.memoryTotal : 0
    readonly property string window:
        `last ${Math.round(root.historyLength * root.pollInterval / 1000 / 60)} min`

    readonly property FileView loadFile: FileView {
        path: root.watchers > 0 ? "/proc/loadavg" : ""
        watchChanges: false
        onLoaded: root.readLoad(text())
    }
    readonly property FileView uptimeFile: FileView {
        path: root.watchers > 0 ? "/proc/uptime" : ""
        watchChanges: false
        onLoaded: root.readUptime(text())
    }
    readonly property Timer sampler: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: {
            root.sample()
            root.loadFile.reload()
            root.uptimeFile.reload()
        }
    }

    function readLoad(text: string): void {
        const values = text.trim().split(/\s+/).slice(0, 3).map(Number)
        if (values.length === 3 && values.every(Number.isFinite))
            root.load = values
    }

    function readUptime(text: string): void {
        const seconds = Number(text.trim().split(/\s+/)[0])
        if (Number.isFinite(seconds))
            root.uptime = Math.floor(seconds)
    }

    function push(series: list<real>, value: real): list<real> {
        return series.concat([value]).slice(-root.historyLength)
    }

    function sample(): void {
        const source = Nonchalant.SystemResources
        if (root.watchers <= 0 || source.ramTotal <= 0)
            return

        root.cpu = source.cpuUsage
        root.cpuModel = source.cpuModel
        root.memoryTotal = source.ramTotal * 1024
        root.memoryUsed = source.ramUsed * 1024
        root.networkDown = source.networkDownloadSpeed
        root.networkUp = source.networkUploadSpeed
        root.temperature = source.cpuTemp >= 0 ? { celsius: source.cpuTemp } : null
        root.cpuHistory = root.push(root.cpuHistory, root.cpu / 100)
        root.memoryHistory = root.push(root.memoryHistory, root.memoryFraction)
        root.downHistory = root.push(root.downHistory, root.networkDown)
        root.upHistory = root.push(root.upHistory, root.networkUp)
        if (root.temperature !== null)
            root.temperatureHistory = root.push(root.temperatureHistory, root.temperature.celsius)
        root.ready = true
    }

    function bytes(value: real, decimals = 1): string {
        let amount = Math.max(0, value)
        let unit = 0
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        while (amount >= 1024 && unit < units.length - 1) {
            amount /= 1024
            unit += 1
        }
        return `${amount.toFixed(unit === 0 ? 0 : decimals)} ${units[unit]}`
    }

    function rate(value: real): string { return `${root.bytes(value, 0)}/s` }

    function duration(seconds: int): string {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        if (days > 0)
            return `${days}d ${hours}h`
        return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`
    }

    function subscribe(): void {
        root.watchers += 1
        Nonchalant.SystemResources.subscribe()
        if (root.watchers === 1) {
            root.loadFile.reload()
            root.uptimeFile.reload()
            Qt.callLater(root.sample)
        }
    }

    function release(): void {
        if (root.watchers <= 0)
            return
        root.watchers -= 1
        Nonchalant.SystemResources.release()
    }
}
