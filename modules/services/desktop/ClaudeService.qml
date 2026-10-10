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
    property bool available: false
    property real blockStart: 0
    property real blockEnd: 0
    property int blockTokens: 0
    property int blockMessages: 0
    property int weekTokens: 0
    property int weekMessages: 0
    property int peakBlockTokens: 0
    property int peakWeekTokens: 0


    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }
    readonly property real remaining: root.available
        ? Math.max(0, root.blockEnd * 1000 - root.clock.date.getTime()) : 0
    readonly property real elapsed: {
        const span = (root.blockEnd - root.blockStart) * 1000
        if (!root.available || span <= 0)
            return 0
        return Math.max(0, Math.min(1, 1 - root.remaining / span))
    }
    readonly property string resetsIn: {
        if (!root.available)
            return ""
        const minutes = Math.ceil(root.remaining / 60000)
        if (minutes <= 0)
            return "resets now"
        const hours = Math.floor(minutes / 60)
        return hours > 0 ? `resets in ${hours} h ${minutes % 60} min` : `resets in ${minutes} min`
    }
    readonly property color tint: root.available ? Colors.primary : Colors.outline
    readonly property real gauge: root.elapsed



    function compact(tokens: int): string {
        if (tokens >= 1000000) return `${(tokens / 1000000).toFixed(1)}M`
        if (tokens >= 1000) return `${Math.round(tokens / 1000)}k`
        return `${tokens}`
    }


    function subscribe(): void {
        root.watchers += 1
        root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        if (root.watchers > 0 && !root.query.running)
            root.query.running = true
    }

    function receiveUsage(output: string): void {
        let report
        try {
            report = JSON.parse(output)
        } catch (error) {
            console.warn("ClaudeService: invalid transcript usage response", error)
            root.clearUsage()
            return
        }
        if (!report || report.available !== true) {
            root.clearUsage()
            return
        }
        root.blockStart = Number(report.blockStart) || 0
        root.blockEnd = Number(report.blockEnd) || 0
        root.blockTokens = Number(report.blockTokens) || 0
        root.blockMessages = Number(report.blockMessages) || 0
        root.weekTokens = Number(report.weekTokens) || 0
        root.weekMessages = Number(report.weekMessages) || 0
        root.peakBlockTokens = Number(report.peakBlockTokens) || 0
        root.peakWeekTokens = Number(report.peakWeekTokens) || 0
        root.available = true
    }

    function clearUsage(): void {
        root.available = false
        root.blockStart = 0
        root.blockEnd = 0
        root.blockTokens = 0
        root.blockMessages = 0
        root.weekTokens = 0
        root.weekMessages = 0
        root.peakBlockTokens = 0
        root.peakWeekTokens = 0
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }


    readonly property Process query: Process {
        command: ["python3", Quickshell.shellPath("scripts/desktop/claude_usage.py"),
            Quickshell.statePath("desktop-claude-usage.json")]
        stdout: StdioCollector {
            onStreamFinished: root.receiveUsage(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.clearUsage()
        }
    }
}
