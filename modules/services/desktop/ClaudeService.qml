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

    property bool limitsKnown: false
    property real sessionUsed: 0
    property real weekUsed: 0
    property real sessionResets: 0
    property real weekResets: 0
    property string claim: ""
    property string plan: ""
    property list<var> models: []
    property bool limited: false
    readonly property int limitsInterval: 600000

    readonly property bool sessionMeasured: root.limitsKnown
    readonly property bool weeklyMeasured: root.limitsKnown
    readonly property bool measured: root.limitsKnown
    readonly property real sessionFraction: root.limitsKnown ? Math.max(0, Math.min(1, root.sessionUsed)) : 0
    readonly property real weeklyFraction: root.limitsKnown ? Math.max(0, Math.min(1, root.weekUsed)) : 0
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }
    readonly property real blockEnds: root.limitsKnown && root.sessionResets > 0
        ? root.sessionResets : root.blockEnd
    readonly property real remaining: !root.available && !root.limitsKnown ? 0
        : Math.max(0, root.blockEnds * 1000 - root.clock.date.getTime())
    readonly property real elapsed: {
        const span = root.limitsKnown && root.sessionResets > 0
            ? 5 * 3600000 : (root.blockEnd - root.blockStart) * 1000
        if ((!root.available && !root.limitsKnown) || span <= 0)
            return 0
        return Math.max(0, Math.min(1, 1 - root.remaining / span))
    }
    readonly property string resetsIn: {
        if (!root.available && !root.limitsKnown)
            return ""
        const minutes = Math.ceil(root.remaining / 60000)
        if (minutes <= 0)
            return "resets now"
        const hours = Math.floor(minutes / 60)
        return hours > 0 ? `resets in ${hours} h ${minutes % 60} min` : `resets in ${minutes} min`
    }
    readonly property color tint: {
        if (!root.available && !root.limitsKnown)
            return Colors.outline
        if (root.limited)
            return Colors.error
        if (!root.measured)
            return Colors.primary
        const worst = Math.max(root.sessionFraction, root.weeklyFraction,
            ...root.models.map(model => model.used))
        if (worst >= 0.85) return Colors.error
        if (worst >= 0.6) return Colors.yellow
        return Colors.primary
    }
    readonly property real gauge: root.measured
        ? Math.max(root.sessionFraction, root.weeklyFraction) : root.elapsed
    readonly property int rows: root.limitsKnown ? 3 + root.models.length : 2

    Component.onCompleted: Qt.callLater(root.refresh)

    function messages(count: int): string {
        return `${root.compact(count)} message${count === 1 ? "" : "s"}`
    }

    function compact(tokens: int): string {
        if (tokens >= 1000000) return `${(tokens / 1000000).toFixed(1)}M`
        if (tokens >= 1000) return `${Math.round(tokens / 1000)}k`
        return `${tokens}`
    }

    function percent(fraction: real): string {
        return `${Math.round(fraction * 100)}%`
    }

    function subscribe(): void {
        root.watchers += 1
        root.refresh()
        root.askLimits()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        if (!root.query.running)
            root.query.running = true
    }

    function askLimits(): void {
        if (!root.limitsQuery.running)
            root.limitsQuery.running = true
    }

    function receiveUsage(output: string): void {
        let report
        try {
            report = JSON.parse(output)
        } catch (error) {
            console.warn("ClaudeService: invalid transcript usage response", error)
            root.available = false
            return
        }
        if (!report || report.available !== true) {
            root.available = false
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

    function receiveLimits(output: string): void {
        let report
        try {
            report = JSON.parse(output)
        } catch (error) {
            root.clearLimits()
            return
        }
        if (!report || report.available !== true) {
            root.clearLimits()
            return
        }
        root.sessionUsed = Number(report.session?.used) || 0
        root.sessionResets = Number(report.session?.resets) || 0
        root.weekUsed = Number(report.week?.used) || 0
        root.weekResets = Number(report.week?.resets) || 0
        root.claim = report.claim ?? ""
        root.plan = report.plan ?? ""
        root.models = Array.isArray(report.models) ? report.models : []
        root.limited = report.status === "rate_limited"
            || [report.session, report.week].concat(root.models).some(window => window && window.used >= 1)
        root.limitsKnown = true
    }

    function clearLimits(): void {
        root.limitsKnown = false
        root.sessionUsed = 0
        root.weekUsed = 0
        root.sessionResets = 0
        root.weekResets = 0
        root.claim = ""
        root.plan = ""
        root.models = []
        root.limited = false
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    readonly property Timer limitsPoller: Timer {
        interval: root.limitsInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.askLimits()
    }

    readonly property Process limitsQuery: Process {
        command: ["python3", Quickshell.shellPath("scripts/desktop/claude_usage.py"), "limits"]
        stdout: StdioCollector {
            onStreamFinished: root.receiveLimits(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.clearLimits()
        }
    }

    readonly property Process query: Process {
        command: ["python3", Quickshell.shellPath("scripts/desktop/claude_usage.py"),
            Quickshell.statePath("desktop-claude-usage.json")]
        stdout: StdioCollector {
            onStreamFinished: root.receiveUsage(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.available = false
        }
    }
}
