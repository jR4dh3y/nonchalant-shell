pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services
import qs.modules.theme

Singleton {
    id: root

    property bool ready: false
    readonly property list<string> tints: ["yellow", "accent", "green", "blue", "red"]
    property list<var> notes: []

    readonly property list<var> live: root.notes.filter(note => !note.archived)
        .sort((left, right) => right.edited - left.edited)
    readonly property list<var> archived: root.notes.filter(note => note.archived)
        .sort((left, right) => right.edited - left.edited)
    readonly property int count: root.live.length
    readonly property var newest: root.live[0] ?? null
    readonly property int panelWidth: 560
    readonly property int panelHeight: 520
    property string opened: ""
    property bool direct: false

    signal added(string key)

    function tintColor(name: string): color {
        switch (name) {
        case "green": return Colors.green
        case "yellow": return Colors.yellow
        case "red": return Colors.error
        case "blue": return Colors.blue
        }
        return Colors.primary
    }

    function paperOf(name: string): color {
        return Qt.tint(root.tintColor(name), Colors.surfaceContainerLow)
    }

    function normalise(list: list<var>): list<var> {
        const rows = []
        for (const item of list) {
            if (!item || typeof item.key !== "string" || item.key === "")
                continue
            rows.push(Object.assign({
                title: "", text: "", tint: "yellow", created: 0, edited: 0, archived: false
            }, item))
        }
        return rows
    }

    function hydrate(saved: list<var>): void {
        if (root.ready)
            return
        const pending = root.notes
        const loaded = root.normalise(saved)
        for (const note of pending) {
            if (!loaded.some(existing => existing.key === note.key))
                loaded.push(note)
        }
        root.notes = loaded
        root.ready = true
        if (pending.length > 0)
            root.saver.restart()
    }

    function entry(key: string): var {
        return root.notes.find(note => note.key === key) ?? null
    }

    function noteFor(row: var): var {
        const key = row && typeof row.note === "string" ? row.note : ""
        const named = key !== "" ? root.entry(key) : null
        return named && !named.archived ? named : root.newest
    }

    function titleOf(note: var): string {
        if (!note)
            return ""
        const title = (note.title ?? "").trim()
        if (title !== "")
            return title
        const line = root.firstLine(note.text)
        return line !== "" ? line : "Untitled"
    }

    function isEmpty(note: var): bool {
        return !note || ((note.title ?? "").trim() === "" && (note.text ?? "").trim() === "")
    }

    function newKey(): string {
        const stamp = Date.now().toString(36)
        let key = `note-${stamp}`
        for (let number = 2; root.entry(key); number++)
            key = `note-${stamp}-${number}`
        return key
    }

    function write(next: var): void {
        root.notes = next
        if (root.ready)
            root.saver.restart()
    }

    function add(title: string, text = "", tint = "yellow"): string {
        const now = Date.now()
        const key = root.newKey()
        const noteTint = root.tints.indexOf(tint) >= 0 ? tint : "yellow"
        root.write(root.notes.concat([{
            key: key, title: title ?? "", text: text ?? "", tint: noteTint,
            created: now, edited: now, archived: false
        }]))
        DesktopWidgetService.noteAdded(key)
        root.added(key)
        return key
    }

    function create(tint = "yellow", fromDeck = false): string {
        const key = root.add("", "", tint)
        root.opened = key
        root.direct = !fromDeck
        return key
    }

    function update(key: string, changes: var): void {
        const current = root.entry(key)
        if (!current || !changes || typeof changes !== "object")
            return
        root.write(root.notes.map(note => {
            if (note.key !== key)
                return note
            const next = Object.assign({}, note, changes)
            if ((changes.text !== undefined && changes.text !== current.text)
                    || (changes.title !== undefined && changes.title !== current.title))
                next.edited = Date.now()
            return next
        }))
    }

    function setTint(key: string, tint: string): void {
        if (root.tints.indexOf(tint) >= 0)
            root.update(key, { tint: tint })
    }

    function archive(key: string, on = true): void {
        if (!root.entry(key))
            return
        root.update(key, { archived: on })
        if (on)
            DesktopWidgetService.removeNote(key)
    }

    function remove(key: string): void {
        if (!root.entry(key))
            return
        DesktopWidgetService.removeNote(key)
        root.write(root.notes.filter(note => note.key !== key))
        if (root.opened === key)
            root.opened = ""
    }

    function firstLine(text: string): string {
        for (const line of (text ?? "").split("\n")) {
            const trimmed = line.trim()
            if (trimmed !== "")
                return trimmed
        }
        return ""
    }

    function display(text: string): string {
        return (text ?? "")
            .replace(/^\[x\] ?/gim, "󰄲 ")
            .replace(/^\[ \] ?/gm, "󰄱 ")
    }

    function ageOf(when: real): string {
        const seconds = Math.max(0, (Date.now() - when) / 1000)
        if (seconds < 60)
            return "just now"
        if (seconds < 3600)
            return `${Math.floor(seconds / 60)} min`
        if (seconds < 86400)
            return `${Math.floor(seconds / 3600)} h`
        if (seconds < 7 * 86400)
            return `${Math.floor(seconds / 86400)} d`
        return Qt.formatDate(new Date(when), "d MMM")
    }

    function open(key: string, fromDeck = false): void {
        root.opened = root.entry(key) ? key : ""
        root.direct = !fromDeck
    }

    function leave(): void {
        const note = root.entry(root.opened)
        root.opened = ""
        root.direct = false
        if (note && root.isEmpty(note))
            root.remove(note.key)
    }

    readonly property Timer saver: Timer {
        interval: 120
        onTriggered: {
            if (!root.ready)
                return
            state.notes = root.notes
            root.file.writeAdapter()
        }
    }

    readonly property FileView file: FileView {
        path: Quickshell.statePath("desktop-notes.json")
        atomicWrites: true
        onLoaded: root.hydrate(state.notes)
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.hydrate([])
        }

        JsonAdapter {
            id: state
            property list<var> notes: []
        }
    }
}
