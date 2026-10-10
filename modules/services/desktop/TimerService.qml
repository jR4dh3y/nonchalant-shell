pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.theme

Singleton {
    id: root

    signal finished(string label)

    property bool running: false
    property bool paused: false
    property string label: ""
    property real endsAt: 0
    property real duration: 0
    property real remaining: 0

    readonly property real progress: root.duration > 0
        ? Math.max(0, Math.min(1, root.remaining / root.duration)) : 0
    readonly property int seconds: Math.max(0, Math.ceil(root.remaining / 1000))
    readonly property color tint: !root.running ? Colors.outline
        : root.seconds <= 30 ? Colors.error
        : root.seconds <= 120 ? Colors.yellow : Colors.primary
    readonly property string display: {
        const total = Math.max(0, Math.ceil(root.remaining / 1000))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const seconds = total % 60
        const pad = value => value < 10 ? `0${value}` : `${value}`
        return hours > 0 ? `${hours}:${pad(minutes)}:${pad(seconds)}` : `${minutes}:${pad(seconds)}`
    }

    readonly property Timer ticker: Timer {
        interval: 250
        repeat: true
        running: root.running && !root.paused
        onTriggered: {
            root.remaining = root.endsAt - Date.now()
            if (root.remaining <= 0)
                root.complete()
        }
    }


    function parse(text: string): real {
        const clean = (text ?? "").trim().toLowerCase()
        if (clean === "")
            return 0
        const clock = clean.match(/^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$/)
        if (clock) {
            const hours = clock[3] === undefined ? 0 : Number(clock[1])
            const minutes = clock[3] === undefined ? Number(clock[1]) : Number(clock[2])
            const seconds = clock[3] === undefined ? Number(clock[2]) : Number(clock[3])
            return (hours * 3600 + minutes * 60 + seconds) * 1000
        }
        if (!/^\d+(?:\.\d+)?\s*[hms]?(?:\s*\d+(?:\.\d+)?\s*[hms]?)*$/.test(clean))
            return 0
        const units = { h: 3600, m: 60, s: 1 }
        const pattern = /(\d+(?:\.\d+)?)\s*(h|m|s)?/g
        let total = 0
        let lastUnit = ""
        let match
        while ((match = pattern.exec(clean)) !== null) {
            const amount = Number(match[1])
            const unit = match[2] || (lastUnit === "h" ? "m" : lastUnit === "m" ? "s" : "m")
            total += amount * units[unit]
            lastUnit = unit
        }
        return Number.isFinite(total) ? Math.round(total * 1000) : 0
    }

    function start(milliseconds: real, label = ""): void {
        if (!Number.isFinite(milliseconds) || milliseconds <= 0)
            return
        root.duration = milliseconds
        root.endsAt = Date.now() + milliseconds
        root.remaining = milliseconds
        root.label = (label ?? "").trim()
        root.paused = false
        root.running = true
    }

    function pause(): void {
        if (!root.running || root.paused)
            return
        root.remaining = Math.max(0, root.endsAt - Date.now())
        if (root.remaining <= 0) {
            root.complete()
            return
        }
        root.paused = true
    }

    function resume(): void {
        if (!root.running || !root.paused)
            return
        root.endsAt = Date.now() + root.remaining
        root.paused = false
    }

    function toggle(): void {
        if (root.paused)
            root.resume()
        else
            root.pause()
    }

    function restart(): void {
        if (root.duration > 0)
            root.start(root.duration, root.label)
    }

    function cancel(): void {
        root.running = false
        root.paused = false
        root.remaining = 0
        root.label = ""
    }

    function complete(): void {
        if (!root.running)
            return
        const finishedLabel = root.label
        root.running = false
        root.paused = false
        root.remaining = 0
        Quickshell.execDetached(["notify-send", "-u", "critical",
            finishedLabel === "" ? "Timer finished" : finishedLabel,
            "The countdown has run out."])
        root.finished(finishedLabel)
        root.label = ""
    }
}
