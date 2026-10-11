pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int pollInterval: 1800000
    property int watchers: 0
    property bool available: false
    property bool checking: false
    property bool queryActive: false
    property bool queryStarted: false
    property bool queryExited: false
    property bool queryOutputFinished: false
    property int queryExitCode: 0
    property bool refreshPending: false
    property int count: 0
    property list<string> packages: []
    property list<var> updates: []
    property bool aur: false
    property string tool: ""
    property real checkedAt: 0

    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }
    readonly property string age: {
        if (root.checkedAt <= 0)
            return ""
        const minutes = Math.max(0, Math.round((root.clock.date.getTime() - root.checkedAt) / 60000))
        if (minutes < 1) return "just now"
        if (minutes < 60) return `${minutes} min ago`
        return `${Math.floor(minutes / 60)} h ${minutes % 60} min ago`
    }


    function subscribe(): void {
        root.watchers += 1
        if (!root.available || root.checkedAt <= 0
                || Date.now() - root.checkedAt >= root.pollInterval) {
            if (root.queryActive)
                root.refreshPending = true
            else
                root.refresh()
        }
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        if (root.watchers <= 0 || root.queryActive)
            return
        root.checking = true
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
            console.warn("UpdatesService: invalid update response", error)
            root.available = false
            return
        }
        root.available = report?.available === true
        if (!root.available)
            return
        root.count = Number(report.count) || 0
        root.packages = Array.isArray(report.packages) ? report.packages : []
        root.updates = Array.isArray(report.updates) ? report.updates : []
        root.aur = report.aur === true
        root.tool = typeof report.tool === "string" ? report.tool : ""
        root.checkedAt = Date.now()
    }
    function finishQuery(): void {
        if (!root.queryActive || !root.queryExited || !root.queryOutputFinished)
            return
        const exitCode = root.queryExitCode
        const retry = root.refreshPending
        root.queryActive = false
        root.queryStarted = false
        root.queryExited = false
        root.queryOutputFinished = false
        root.queryExitCode = 0
        root.checking = false
        root.refreshPending = false
        if (exitCode !== 0)
            root.available = false
        if (retry && root.watchers > 0 && (!root.available || root.checkedAt <= 0
                || Date.now() - root.checkedAt >= root.pollInterval))
            Qt.callLater(root.refresh)
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    readonly property Process query: Process {
        command: ["python3", Quickshell.shellPath("scripts/desktop/updates.py")]
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
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.queryActive)
                    return
                root.receive(text)
                root.queryOutputFinished = true
                root.finishQuery()
            }
        }
    }
}
