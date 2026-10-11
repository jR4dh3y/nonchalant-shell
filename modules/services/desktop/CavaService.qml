pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int bandCount: 64
    property var bands: new Array(root.bandCount).fill(0)
    readonly property real peakFall: 0.035
    property var peaks: new Array(root.bandCount).fill(0)
    readonly property int barCount: 8
    readonly property var values: {
        const half = root.barCount / 2
        const width = root.bandCount / half
        const groups = []
        for (let group = 0; group < half; group++) {
            let total = 0
            for (let index = 0; index < width; index++)
                total += root.bands[group * width + index]
            groups.push(total / width)
        }
        return groups.slice().reverse().concat(groups)
    }
    property int watchers: 0
    property bool available: false
    property string error: ""
    readonly property bool active: (root.watchers > 0 || root.linger.running) && !root.failed
    property bool failed: false
    readonly property real level: {
        if (root.values.length === 0)
            return 0
        let total = 0
        for (const value of root.values)
            total += Math.max(0, value)
        return Math.pow(total / root.values.length, 0.55)
    }

    readonly property Timer linger: Timer { interval: 2000 }

    onActiveChanged: {
        if (!root.active) {
            root.bands = new Array(root.bandCount).fill(0)
            root.peaks = new Array(root.bandCount).fill(0)
            root.available = false
        }
    }

    readonly property Process process: Process {
        command: ["cava", "-p", Quickshell.shellPath("scripts/desktop/cava.conf")]
        running: root.active
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.parse(line)
        }
        onExited: (exitCode, exitStatus) => {
            root.available = false
            if (root.active && exitCode !== 0) {
                root.failed = true
                root.error = "Cava is unavailable"
            }
        }
    }

    function parse(line: string): void {
        const fields = line.split(";")
        if (fields.length < root.bandCount)
            return
        const next = []
        let valid = 0
        for (let index = 0; index < root.bandCount; index++) {
            const value = Number(fields[index])
            if (Number.isFinite(value))
                valid++
            next.push(Number.isFinite(value) ? Math.max(0, Math.min(1, value / 100)) : 0)
        }
        if (valid === 0)
            return
        root.available = true
        root.error = ""
        const fallen = next.map((value, index) => Math.max(value, root.peaks[index] - root.peakFall, 0))
        if (next.every((value, index) => value === root.bands[index])
                && fallen.every((value, index) => value === root.peaks[index]))
            return
        root.bands = next
        root.peaks = fallen
    }

    function subscribe(): void {
        root.failed = false
        root.error = ""
        root.linger.stop()
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
        if (root.watchers === 0)
            root.linger.restart()
    }
}
