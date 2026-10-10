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
            if (root.checking)
                root.refreshPending = true
            else
                root.refresh()
        }
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        if (root.watchers <= 0 || root.checking)
            return
        root.checking = true
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

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    readonly property Process query: Process {
        command: ["python3", Quickshell.shellPath("scripts/desktop/updates.py")]
        onExited: (exitCode, exitStatus) => {
            root.checking = false
            if (exitCode !== 0)
                root.available = false
            const retry = root.refreshPending
            root.refreshPending = false
            if (retry && root.watchers > 0 && (!root.available || root.checkedAt <= 0
                    || Date.now() - root.checkedAt >= root.pollInterval))
                Qt.callLater(root.refresh)
        }
        stdout: StdioCollector {
            onStreamFinished: root.receive(text)
        }
    }
}
