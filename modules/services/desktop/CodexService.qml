pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.theme

Singleton {
    id: root

    readonly property int pollInterval: 120000
    property int watchers: 0
    property bool queryActive: false
    property bool queryStarted: false
    property bool queryExited: false
    property bool queryOutputFinished: false
    property int queryExitCode: 0
    property bool available: false
    property string plan: ""
    property real observed: 0
    property list<var> limits: []
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }
    readonly property list<var> live: root.limits.filter(limit => root.current(limit))
    readonly property real gauge: root.live.reduce((worst, limit) => Math.max(worst, limit.used), 0)
    readonly property bool measured: root.live.length > 0
    readonly property var fullest: root.live.reduce(
        (worst, limit) => worst === null || limit.used > worst.used ? limit : worst, null)
    readonly property string fullestName: root.fullest ? root.fullest.name.toLowerCase() : ""
    readonly property string figure: root.measured ? `${Math.round(root.gauge * 100)}%` : "—"
    readonly property color tint: !root.measured ? Colors.primary
        : root.gauge >= 0.85 ? Colors.error
        : root.gauge >= 0.6 ? Colors.yellow : Colors.primary
    readonly property string age: {
        if (root.observed <= 0)
            return ""
        const minutes = Math.floor((root.clock.date.getTime() - root.observed * 1000) / 60000)
        if (minutes < 1) return "read just now"
        if (minutes < 60) return `read ${minutes} min ago`
        if (minutes < 24 * 60) return `read ${Math.floor(minutes / 60)} h ago`
        return `read ${Qt.formatDateTime(new Date(root.observed * 1000), "ddd d MMM")}`
    }


    function current(limit: var): bool {
        return !!limit && limit.resets * 1000 > root.clock.date.getTime()
    }

    function windowLine(limit: var): string {
        if (!limit)
            return ""
        const minutes = Math.ceil((limit.resets * 1000 - root.clock.date.getTime()) / 60000)
        const when = minutes <= 0 ? "renewed"
            : minutes < 60 ? `resets in ${minutes} min`
            : minutes < 24 * 60 ? `resets in ${Math.floor(minutes / 60)} h`
            : `resets ${Qt.formatDateTime(new Date(limit.resets * 1000), "ddd HH:mm")}`
        return `${limit.name.toLowerCase()} · ${when}`
    }

    function subscribe(): void {
        root.watchers += 1
        root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        if (root.watchers <= 0 || root.queryActive)
            return
        root.queryActive = true
        root.queryStarted = false
        root.queryExited = false
        root.queryOutputFinished = false
        root.queryExitCode = 0
        root.query.running = true
    }

    function receive(output: string): void {
        let report
        try {
            report = JSON.parse(output)
        } catch (error) {
            console.warn("CodexService: invalid session usage response", error)
            root.clear()
            return
        }
        if (!report || report.available !== true || !Array.isArray(report.limits)) {
            root.clear()
            return
        }
        root.plan = report.plan ?? ""
        root.observed = Number(report.observed) || 0
        root.limits = report.limits.slice().sort((left, right) => left.minutes - right.minutes)
        root.available = true
    }

    function clear(): void {
        root.available = false
        root.plan = ""
        root.observed = 0
        root.limits = []
    }
    function finishQuery(): void {
        if (!root.queryActive || !root.queryExited || !root.queryOutputFinished)
            return
        const exitCode = root.queryExitCode
        root.queryActive = false
        root.queryStarted = false
        root.queryExited = false
        root.queryOutputFinished = false
        root.queryExitCode = 0
        if (exitCode !== 0)
            root.clear()
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    readonly property Process query: Process {
        command: ["python3", Quickshell.shellPath("scripts/desktop/codex_usage.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.queryActive)
                    return
                root.receive(text)
                root.queryOutputFinished = true
                root.finishQuery()
            }
        }
        onStarted: root.queryStarted = true
        onExited: (exitCode, exitStatus) => {
            if (!root.queryActive)
                return
            root.queryExitCode = exitCode
            root.queryExited = true
            root.finishQuery()
        }
        // FailedToStart emits neither exited nor stream finished.
        onRunningChanged: {
            if (query.running || !root.queryActive || root.queryStarted || root.queryExited)
                return
            root.queryExitCode = -1
            root.queryExited = true
            root.queryOutputFinished = true
            root.finishQuery()
        }
    }
}
