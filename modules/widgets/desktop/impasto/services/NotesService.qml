pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services.desktop as Nonchalant
import qs.modules.services as LocalServices
import qs.modules.widgets.desktop.impasto.theme as Impasto

Singleton {
    id: root

    readonly property bool ready: Nonchalant.NotesService.ready
    readonly property list<string> tints: Nonchalant.NotesService.tints
    readonly property list<var> live: Nonchalant.NotesService.live
    readonly property list<var> archived: Nonchalant.NotesService.archived
    readonly property int count: Nonchalant.NotesService.count
    readonly property var newest: Nonchalant.NotesService.newest
    readonly property int panelWidth: Nonchalant.NotesService.panelWidth
    readonly property int panelHeight: Nonchalant.NotesService.panelHeight
    readonly property string opened: Nonchalant.NotesService.opened
    readonly property bool direct: Nonchalant.NotesService.direct

    signal added(string key)

    Connections {
        target: Nonchalant.NotesService
        function onAdded(key: string): void { root.added(key) }
    }

    function tintColor(name: string): color {
        switch (name) {
        case "green": return Impasto.Theme.green
        case "yellow": return Impasto.Theme.yellow
        case "red": return Impasto.Theme.red
        case "blue": return Impasto.Theme.blue
        default: return Impasto.Theme.accent
        }
    }

    function paperOf(name: string): color {
        return Qt.tint(root.tintColor(name), Impasto.Theme.paperWash)
    }

    function entry(key: string): var { return Nonchalant.NotesService.entry(key) }
    function noteFor(row: var): var { return Nonchalant.NotesService.noteFor(row) }
    function titleOf(note: var): string { return Nonchalant.NotesService.titleOf(note) }
    function isEmpty(note: var): bool { return Nonchalant.NotesService.isEmpty(note) }
    function add(title: string, text = "", tint = "yellow"): string {
        return Nonchalant.NotesService.add(title, text, tint)
    }
    function create(tint = "yellow", fromDeck = false): string {
        return Nonchalant.NotesService.create(tint, fromDeck)
    }
    function update(key: string, changes: var): void {
        Nonchalant.NotesService.update(key, changes)
    }
    function setTint(key: string, tint: string): void {
        Nonchalant.NotesService.setTint(key, tint)
    }
    function archive(key: string, on = true): void {
        Nonchalant.NotesService.archive(key, on)
    }
    function remove(key: string): void { Nonchalant.NotesService.remove(key) }
    function firstLine(text: string): string { return Nonchalant.NotesService.firstLine(text) }
    function display(text: string): string { return Nonchalant.NotesService.display(text) }
    function ageOf(when: real): string { return Nonchalant.NotesService.ageOf(when) }
    function open(key: string, row = null): void {
        Nonchalant.NotesService.open(key, false)
        if (row)
            LocalServices.DesktopWidgetService.openDetail("notes", Object.assign({}, row, { note: key }))
    }
    function leave(): void { Nonchalant.NotesService.leave() }
}
