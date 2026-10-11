pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property int pollInterval: 1800000
    property int watchers: 0
    property bool available: false
    property string user: ""
    property int total: 0
    property int streak: 0
    property int today: 0
    property int busiest: 0
    property list<var> weeks: []
    property bool userUnknown: false
    property date readAt: new Date(0)
    property string requestedUser: ""
    property string loadedForUser: ""
    property bool refreshPending: false
    property bool queryActive: false
    property bool queryStarted: false
    property bool queryExited: false
    property bool queryOutputFinished: false
    property int queryExitCode: 0
    readonly property string configuredUser: (Config.desktop.githubUser ?? "").trim()
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0 && root.available
    }
    readonly property string age: {
        if (!root.available)
            return ""
        const minutes = Math.floor((root.clock.date.getTime() - root.readAt.getTime()) / 60000)
        if (minutes < 2) return "just now"
        if (minutes < 60) return `${minutes} min ago`
        return `${Math.round(minutes / 60)} h ago`
    }
    readonly property string totalLabel: root.grouped(root.total)
    readonly property int cardGrid: 7 * 9 + 6 * 3


    function grouped(count: int): string {
        return `${count}`.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }

    function subscribe(): void {
        root.watchers += 1
        const minutes = (Date.now() - root.readAt.getTime()) / 60000
        if (!root.available || minutes > 15)
            root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        if (root.watchers <= 0 || root.configuredUser === "")
            return
        if (root.queryActive) {
            root.refreshPending = root.requestedUser !== root.configuredUser
            return
        }
        root.requestedUser = root.configuredUser
        root.refreshPending = false
        root.queryActive = true
        root.queryStarted = false
        root.queryExited = false
        root.queryOutputFinished = false
        root.queryExitCode = 0
        root.query.running = true
    }
    function finishQuery(): void {
        if (!root.queryActive || !root.queryExited || !root.queryOutputFinished)
            return
        const askedUser = root.requestedUser
        const needsRefresh = root.refreshPending || askedUser !== root.configuredUser
        const exitCode = root.queryExitCode
        root.queryActive = false
        root.queryStarted = false
        root.queryExited = false
        root.queryOutputFinished = false
        root.queryExitCode = 0
        root.refreshPending = false
        if (exitCode !== 0 && askedUser === root.configuredUser)
            root.available = false
        if (needsRefresh && root.watchers > 0 && root.configuredUser !== "")
            Qt.callLater(root.refresh)
    }

    function receive(output: string): void {
        if (root.requestedUser !== root.configuredUser)
            return
        let report
        try {
            report = JSON.parse(output)
        } catch (error) {
            console.warn("GithubService: invalid contribution response", error)
            return
        }
        if (!report || report.available !== true || !Array.isArray(report.weeks)) {
            root.userUnknown = report?.reason === "user" && root.configuredUser !== ""
            if (root.configuredUser === "")
                root.available = false
            return
        }
        root.userUnknown = false
        root.user = report.user
        root.total = report.total
        root.streak = report.streak
        root.today = report.today
        root.busiest = report.busiest
        root.weeks = report.weeks
        root.readAt = new Date()
        root.loadedForUser = root.requestedUser
        root.available = true
    }

    Connections {
        target: Config.desktop
        function onGithubUserChanged(): void {
            root.userUnknown = false
            if (root.loadedForUser !== root.configuredUser) {
                root.available = false
                root.user = ""
                root.total = 0
                root.streak = 0
                root.today = 0
                root.busiest = 0
                root.weeks = []
                root.readAt = new Date(0)
                root.loadedForUser = ""
            }
            root.refresh()
        }
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0 && root.configuredUser !== ""
        onTriggered: root.refresh()
    }

    readonly property Process query: Process {
        command: {
            const command = ["python3", Quickshell.shellPath("scripts/desktop/github.py")]
            return root.requestedUser === "" ? command : command.concat([root.requestedUser])
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
