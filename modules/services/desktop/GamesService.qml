pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.theme

Singleton {
    id: root

    property bool ready: false
    readonly property list<var> catalogue: [
        { id: "whack", name: "Whack-a-Mole", icon: "󰣪", tint: "green", width: 520, height: 440, unit: "points", lower: false },
        { id: "snake", name: "Snake Sprint", icon: "󱔎", tint: "green", width: 520, height: 520, unit: "points", lower: false },
        { id: "flood", name: "Flood Colors", icon: "󰖌", tint: "blue", width: 520, height: 560, unit: "moves", lower: true },
        { id: "mini2048", name: "2048 Mini", icon: "󰎠", tint: "blue", width: 480, height: 520, unit: "points", lower: false },
        { id: "lights", name: "Lights Out", icon: "󰛨", tint: "yellow", width: 460, height: 500, unit: "moves", lower: true },
        { id: "hextris", name: "Hextris", icon: "󰋘", tint: "red", width: 520, height: 560, unit: "points", lower: false },
        { id: "bots", name: "Bot Bash", icon: "󰚩", tint: "red", width: 520, height: 520, unit: "points", lower: false },
        { id: "target", name: "Target Smash", icon: "󰓾", tint: "red", width: 560, height: 460, unit: "points", lower: false },
        { id: "space", name: "Space Blaster", icon: "󱓞", tint: "blue", width: 520, height: 600, unit: "points", lower: false },
        { id: "tetris", name: "Tetris", icon: "▙", tint: "accent", width: 460, height: 600, unit: "points", lower: false },
        { id: "solitaire", name: "Solitaire", icon: "♠", tint: "green", width: 760, height: 560, unit: "moves", lower: true }
    ]
    readonly property var tints: ({
        accent: Colors.primary,
        green: Colors.green,
        yellow: Colors.yellow,
        red: Colors.error,
        blue: Colors.blue
    })
    readonly property int shelfWidth: 940
    readonly property int shelfHeight: 196
    readonly property int stripHeight: 28
    readonly property int stripGap: 12
    readonly property real panelPadding: Styling.fontSize(8)
    property string playing: ""
    property string lastOpened: ""
    property var bests: ({})

    readonly property int totalPlays: root.catalogue.reduce((sum, item) => sum + root.playsOf(item.id), 0)
    readonly property string lastPlayed: {
        let selected = ""
        let newest = 0
        for (const item of root.catalogue) {
            const record = root.recordOf(item.id)
            if (record && record.playedAt > newest) {
                newest = record.playedAt
                selected = item.id
            }
        }
        return selected
    }
    readonly property list<var> ranked: root.catalogue.filter(item => root.played(item.id))
        .sort((left, right) => root.recordOf(right.id).playedAt - root.recordOf(left.id).playedAt)

    signal newBest(string id, int score)

    function entry(id: string): var {
        return root.catalogue.find(item => item.id === id) ?? null
    }

    function tintOf(id: string): color {
        const item = root.entry(id)
        return item ? root.tints[item.tint] ?? Colors.primary : Colors.primary
    }

    function panelSize(id: string): var {
        const item = root.entry(id)
        if (!item)
            return { width: root.shelfWidth, height: root.shelfHeight }
        return {
            width: item.width + 2 * root.panelPadding,
            height: item.height + root.stripHeight + root.stripGap + 2 * root.panelPadding
        }
    }

    function open(id: string): void {
        if (!root.entry(id))
            return
        root.playing = id
        root.lastOpened = id
    }

    function leave(): void {
        root.playing = ""
    }

    function recordOf(id: string): var {
        return root.bests[id] ?? null
    }

    function played(id: string): bool {
        return root.recordOf(id) !== null
    }

    function bestOf(id: string): int {
        const record = root.recordOf(id)
        return record ? record.best : 0
    }

    function playsOf(id: string): int {
        const record = root.recordOf(id)
        return record ? record.plays : 0
    }

    function record(id: string, score: int): bool {
        const game = root.entry(id)
        if (!game || !Number.isFinite(score) || score <= 0)
            return false
        const previous = root.recordOf(id)
        const better = previous === null || (game.lower ? score < previous.best : score > previous.best)
        const next = Object.assign({}, root.bests)
        next[id] = {
            best: better ? score : previous.best,
            plays: (previous ? previous.plays : 0) + 1,
            playedAt: Date.now()
        }
        root.bests = next
        if (root.ready)
            root.saver.restart()
        if (better) {
            root.newBest(id, score)
            if (previous !== null)
                Quickshell.execDetached(["notify-send", game.icon, `New best · ${game.name} ${score}`])
        }
        return better
    }

    function hydrate(saved: var): void {
        if (root.ready)
            return
        const pending = root.bests
        const loaded = Object.assign({}, saved ?? ({}))
        for (const id of Object.keys(pending)) {
            const local = pending[id]
            const previous = loaded[id]
            if (!previous) {
                loaded[id] = local
                continue
            }
            const game = root.entry(id)
            loaded[id] = {
                best: game && game.lower ? Math.min(previous.best, local.best)
                    : Math.max(previous.best, local.best),
                plays: (Number(previous.plays) || 0) + (Number(local.plays) || 0),
                playedAt: Math.max(previous.playedAt, local.playedAt)
            }
        }
        root.bests = loaded
        root.ready = true
        if (Object.keys(pending).length > 0)
            root.saver.restart()
    }

    readonly property Timer saver: Timer {
        interval: 120
        onTriggered: {
            if (!root.ready)
                return
            state.bests = root.bests
            root.file.writeAdapter()
        }
    }

    readonly property FileView file: FileView {
        path: Quickshell.statePath("desktop-games.json")
        atomicWrites: true
        onLoaded: root.hydrate(state.bests)
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.hydrate({})
        }

        JsonAdapter {
            id: state
            property var bests: ({})
        }
    }
}
