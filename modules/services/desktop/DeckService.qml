pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme

Singleton {
    id: root

    readonly property var decks: DesktopWidgetService.widgets
        .filter(widget => widget.id === "notes" && root.isDeck(widget))
        .map(widget => ({
            key: widget.key,
            edge: widget.edge,
            screen: DesktopWidgetService.nameOf(widget),
            along: root.alongOf(widget),
            notes: root.deckNotes(widget).map(key => NotesService.entry(key)).filter(note => note !== null)
        }))

    readonly property int count: root.decks.reduce((sum, deck) => sum + deck.notes.length, 0)
    readonly property bool onEmptyOnly: Config.desktop.deckOnEmpty

    readonly property real sliver: Math.max(Styling.fontSize(-8), Styling.fontSize(0) * 0.35)
    readonly property real tabDepth: Styling.fontSize(0) * 1.85
    readonly property real tabLength: Styling.fontSize(0) * 8
    readonly property real tabGap: Styling.fontSize(-1)
    readonly property real peekWidth: Styling.fontSize(0) * 18
    readonly property real peekHeight: Styling.fontSize(0) * 14
    readonly property real margin: DesktopWidgetService.gutter
    readonly property real reach: Styling.fontSize(0) * 5
    readonly property real grip: Styling.fontSize(0) * 1.8

    property bool revealed: false
    property string revealedScreen: ""
    property string peekedScreen: ""
    property string draggingScreen: ""
    property string slidingScreen: ""
    property string heldScreen: ""
    property string peeked: ""
    property string dragging: ""
    property string sliding: ""
    property string held: ""
    property string receiving: ""
    property string receivingScreen: ""
    property var surfaces: ({})

    readonly property var windows: {
        const result = []
        for (const name in root.surfaces)
            result.push(root.surfaces[name])
        return result
    }

    function isDeck(row: var): bool {
        return !!row && row.id === "notes" && typeof row.edge === "string"
            && ["left", "right", "bottom"].indexOf(row.edge) >= 0
            && Array.isArray(row.notes)
    }

    function decksOn(name: string): var {
        return root.decks.filter(deck => deck.screen === name)
    }

    function deckOn(name: string, edge: string): var {
        return DesktopWidgetService.widgets.find(row =>
            root.isDeck(row) && row.edge === edge
                && DesktopWidgetService.nameOf(row) === name) ?? null
    }

    function deckNotes(deck: var): var {
        const list = deck && Array.isArray(deck.notes) ? deck.notes : []
        return list.filter(key => {
            if (typeof key !== "string")
                return false
            const note = NotesService.entry(key)
            return !!note && !note.archived
        })
    }

    function alongOf(deck: var): real {
        const own = deck?.along
        return typeof own === "number" && Number.isFinite(own)
            ? Math.max(0, Math.min(1, own)) : 0
    }

    function setDeckAlong(key: string, along: real): void {
        if (root.isDeck(DesktopWidgetService.entryOf(key)))
            DesktopWidgetService.update(key, { along: Math.max(0, Math.min(1, along)) })
    }

    function publish(name: string, window: var): void {
        const next = Object.assign({}, root.surfaces)
        if (window === null)
            delete next[name]
        else
            next[name] = window
        root.surfaces = next
    }

    function occupiedOn(name: string): bool {
        const workspace = NiriService.monitorFor(name)?.activeWorkspace
        if (!workspace || workspace.id === undefined || workspace.id === null)
            return false
        return NiriService.windowsForWorkspace(Number(workspace.id)).length > 0
    }

    function awayOn(name: string): bool {
        if (NiriService.overviewOpen || DesktopWidgetService.isFullscreen(name))
            return true
        return root.onEmptyOnly && root.occupiedOn(name)
    }

    function spectrumAwayOn(name: string): bool {
        if (NiriService.overviewOpen || DesktopWidgetService.isFullscreen(name))
            return true
        return Config.desktop.spectrumOnEmpty && root.occupiedOn(name)
    }

    function vertical(edge: string): bool { return edge !== "bottom" }

    function stripLength(count: int): real {
        return Math.max(0, count * (root.tabLength + root.tabGap) - root.tabGap)
    }

    function leadOf(edge: string, screenName: string): real {
        return edge === "bottom" ? 0 : DesktopWidgetService.insetsFor(screenName).top
    }

    function runOf(edge: string, count: int, width: real, height: real, screenName: string): real {
        const length = edge === "bottom" ? width : height + root.leadOf(edge, screenName)
        return Math.max(0, length - root.stripLength(count) - 2 * root.margin)
    }

    function startOf(edge: string, count: int, along: real, width: real, height: real, screenName: string): real {
        return root.margin - root.leadOf(edge, screenName)
            + Math.max(0, Math.min(1, along)) * root.runOf(edge, count, width, height, screenName)
    }

    function alongAt(edge: string, count: int, start: real, width: real, height: real, screenName: string): real {
        const run = root.runOf(edge, count, width, height, screenName)
        return run <= 0 ? 0
            : Math.max(0, Math.min(1, (start + root.leadOf(edge, screenName) - root.margin) / run))
    }

    function tabAt(start: real, index: int): real {
        return start + index * (root.tabLength + root.tabGap)
    }

    function tabBox(edge: string, index: int, start: real, depth: real, width: real, height: real): var {
        if (edge === "bottom")
            return { x: root.tabAt(start, index), y: height - depth, width: root.tabLength, height: depth }
        return {
            x: edge === "right" ? width - depth : 0,
            y: root.tabAt(start, index), width: depth, height: root.tabLength
        }
    }

    function stripBox(edge: string, count: int, start: real, width: real, height: real): var {
        const length = root.stripLength(count)
        if (edge === "bottom")
            return { x: start, y: height - root.tabDepth, width: length, height: root.tabDepth }
        return {
            x: edge === "right" ? width - root.tabDepth : 0,
            y: start, width: root.tabDepth, height: length
        }
    }

    function gripBox(edge: string, start: real, width: real, height: real): var {
        const before = start - root.grip / 2 - root.tabGap / 2
        if (edge === "bottom")
            return { x: before, y: height - root.tabDepth / 2 - root.grip / 2, width: root.grip, height: root.grip }
        return {
            x: edge === "right" ? width - root.tabDepth / 2 - root.grip / 2 : root.tabDepth / 2 - root.grip / 2,
            y: before, width: root.grip, height: root.grip
        }
    }

    function peekBox(edge: string, index: int, start: real, width: real, height: real): var {
        const gap = root.tabGap
        if (edge === "bottom") {
            const x = root.tabAt(start, index) + root.tabLength / 2 - root.peekWidth / 2
            return {
                x: Math.max(root.margin, Math.min(width - root.margin - root.peekWidth, x)),
                y: height - root.tabDepth - gap - root.peekHeight,
                width: root.peekWidth, height: root.peekHeight
            }
        }
        const y = root.tabAt(start, index)
        return {
            x: edge === "right" ? width - root.tabDepth - gap - root.peekWidth : root.tabDepth + gap,
            y: Math.max(root.margin, Math.min(height - root.margin - root.peekHeight, y)),
            width: root.peekWidth, height: root.peekHeight
        }
    }

    function edgeAt(x: real, y: real, width: real, height: real): string {
        if (x <= root.reach)
            return "left"
        if (x >= width - root.reach)
            return "right"
        if (y >= height - root.reach)
            return "bottom"
        return ""
    }

    function indexAt(edge: string, x: real, y: real, count: int, start: real): int {
        const position = edge === "bottom" ? x : y
        return Math.max(0, Math.min(count,
            Math.round((position - start - root.tabLength / 2) / (root.tabLength + root.tabGap))))
    }

    function withoutNote(noteKey: string): var {
        const kept = []
        for (const row of DesktopWidgetService.widgets) {
            if (!root.isDeck(row)) {
                if (!(row.id === "notes" && row.note === noteKey))
                    kept.push(row)
                continue
            }
            const notes = root.deckNotes(row).filter(key => key !== noteKey)
            if (notes.length > 0)
                kept.push(Object.assign({}, row, { notes: notes }))
        }
        return kept
    }

    function removeNote(noteKey: string): void {
        const placed = DesktopWidgetService.widgets.some(row => row.id === "notes" && (
            root.isDeck(row)
                ? row.notes.indexOf(noteKey) >= 0
                : row.note === noteKey
        ))
        if (!placed)
            return
        const kept = root.withoutNote(noteKey)
        if (DesktopWidgetService.selected !== ""
                && !kept.some(row => row.key === DesktopWidgetService.selected))
            DesktopWidgetService.selected = ""
        if (DesktopWidgetService.detailModuleId === "notes"
                && (DesktopWidgetService.detailKey === noteKey
                    || DesktopWidgetService.detailRow?.note === noteKey))
            DesktopWidgetService.closeDetail()
        DesktopWidgetService.write(kept)
    }

    function noteAdded(noteKey: string): void {
        const deck = DesktopWidgetService.widgets.find(row =>
            root.isDeck(row) && row.takesNew === true)
        if (deck)
            root.placeNote(noteKey, DesktopWidgetService.nameOf(deck), deck.edge)
    }

    function setTakesNew(key: string, on: bool): void {
        if (!root.isDeck(DesktopWidgetService.entryOf(key)))
            return
        DesktopWidgetService.write(DesktopWidgetService.widgets.map(row => {
            if (!root.isDeck(row))
                return row
            const next = Object.assign({}, row)
            if (on && row.key === key)
                next.takesNew = true
            else
                delete next.takesNew
            return next
        }))
    }

    function placeNote(noteKey: string, screenName: string, edge: string, index = -1): void {
        const note = NotesService.entry(noteKey)
        if (!note || note.archived || !DesktopWidgetService.screenExists(screenName)
                || ["left", "right", "bottom"].indexOf(edge) < 0)
            return
        const target = root.deckOn(screenName, edge)
        const notes = target ? root.deckNotes(target).filter(key => key !== noteKey) : []
        const at = index < 0 ? notes.length : Math.max(0, Math.min(notes.length, index))
        notes.splice(at, 0, noteKey)
        const rows = root.withoutNote(noteKey)
        if (target) {
            const kept = rows.filter(row => row.key !== target.key)
            kept.push(Object.assign({}, target, { notes: notes }))
            DesktopWidgetService.write(kept)
            return
        }
        rows.push({
            key: DesktopWidgetService.newKey("notes"), id: "notes", edge: edge,
            notes: notes, along: 0, screen: screenName
        })
        DesktopWidgetService.write(rows)
    }

    function noteToGrid(noteKey: string, screenName: string, col: int, row: int): bool {
        const note = NotesService.entry(noteKey)
        if (!note || note.archived || !DesktopWidgetService.screenExists(screenName))
            return false
        const spot = DesktopWidgetService.nearestFree(screenName, col, row, "2x2", "")
        if (!spot)
            return false
        const rows = root.withoutNote(noteKey)
        rows.push({
            key: DesktopWidgetService.newKey("notes"), id: "notes",
            col: spot.col, row: spot.row, family: "2x2", note: noteKey, screen: screenName
        })
        DesktopWidgetService.write(rows)
        return true
    }

    function noteToEdge(key: string, screenName: string, edge: string): void {
        const widget = DesktopWidgetService.entryOf(key)
        if (!widget || widget.id !== "notes" || root.isDeck(widget)
                || !DesktopWidgetService.screenExists(screenName)
                || ["left", "right", "bottom"].indexOf(edge) < 0)
            return
        const note = NotesService.noteFor(widget)
        const noteKey = note?.key ?? NotesService.add("", "", "yellow")
        const target = root.deckOn(screenName, edge)
        const notes = target ? root.deckNotes(target).filter(item => item !== noteKey) : []
        notes.push(noteKey)
        const rows = root.withoutNote(noteKey).filter(row => row.key !== key)
        if (DesktopWidgetService.selected === key)
            DesktopWidgetService.selected = ""
        if (target) {
            rows.push(Object.assign({}, target, { notes: notes }))
        } else {
            rows.push({
                key: DesktopWidgetService.newKey("notes"), id: "notes", edge: edge,
                notes: notes, along: 0, screen: screenName
            })
        }
        DesktopWidgetService.write(rows)
    }

    function setDeckEdge(key: string, screenName: string, edge: string): void {
        const deck = DesktopWidgetService.entryOf(key)
        if (!root.isDeck(deck) || !DesktopWidgetService.screenExists(screenName)
                || ["left", "right", "bottom"].indexOf(edge) < 0)
            return
        if (deck.edge === edge && DesktopWidgetService.nameOf(deck) === screenName)
            return
        const other = root.deckOn(screenName, edge)
        if (!other) {
            DesktopWidgetService.update(key, { edge: edge, screen: screenName })
            return
        }
        const notes = root.deckNotes(other).concat(
            root.deckNotes(deck).filter(note => root.deckNotes(other).indexOf(note) < 0))
        const rows = DesktopWidgetService.widgets.filter(row => row.key !== key)
            .map(row => row.key === other.key ? Object.assign({}, row, { notes: notes }) : row)
        if (DesktopWidgetService.selected === key)
            DesktopWidgetService.selected = other.key
        DesktopWidgetService.write(rows)
    }

    function freeDeckEdge(screenName: string): string {
        return ["right", "left", "bottom"]
            .find(edge => root.deckOn(screenName, edge) === null) ?? ""
    }

    function addDeck(screenName: string, edge = ""): void {
        const target = edge !== "" ? edge : root.freeDeckEdge(screenName)
        if (!DesktopWidgetService.screenExists(screenName)
                || ["left", "right", "bottom"].indexOf(target) < 0)
            return
        const note = NotesService.newest
        const noteKey = note?.key ?? NotesService.add("", "", "yellow")
        root.placeNote(noteKey, screenName, target)
    }

    function spectrumOn(screenName: string, edge: string): var {
        return DesktopWidgetService.widgets.find(row => row.id === "spectrum"
            && row.edge === edge && DesktopWidgetService.nameOf(row) === screenName) ?? null
    }
    function spectrumReach(row: var): real {
        return DesktopWidgetService.spectrumOf(row).reach
    }

    function spectrumBox(screenName: string, row: var, boardWidth: real, boardHeight: real): var {
        const insets = DesktopWidgetService.insetsFor(screenName)
        const reach = root.spectrumReach(row)
        const left = -insets.left
        const top = -insets.top
        const width = boardWidth + insets.left + insets.right
        const height = boardHeight + insets.bottom

        if (row.edge === "bottom")
            return { x: left, y: height - reach, width: width, height: reach }

        const bottom = root.spectrumOn(screenName, "bottom")
        const bottomReach = bottom ? root.spectrumReach(bottom) : 0
        return {
            x: row.edge === "right" ? left + width - reach : left,
            y: top,
            width: reach,
            height: height - bottomReach - top
        }
    }

    function spectrumTakes(screenName: string, edge: string): bool {
        return DesktopWidgetService.screenExists(screenName)
            && ["left", "right", "bottom"].indexOf(edge) >= 0
            && root.spectrumOn(screenName, edge) === null
    }

    function freeSpectrumEdge(screenName: string): string {
        return ["bottom", "left", "right"].find(edge => root.spectrumOn(screenName, edge) === null) ?? ""
    }

    function addSpectrum(screenName: string, edge = ""): string {
        const target = edge !== "" ? edge : root.freeSpectrumEdge(screenName)
        if (!DesktopWidgetService.screenExists(screenName) || !root.spectrumTakes(screenName, target))
            return ""
        const key = DesktopWidgetService.newKey("spectrum")
        DesktopWidgetService.write(DesktopWidgetService.widgets.concat([{
            key: key, id: "spectrum", edge: target, screen: screenName
        }]))
        return key
    }

    function setSpectrumEdge(key: string, screenName: string, edge: string): void {
        const row = DesktopWidgetService.entryOf(key)
        if (!row || row.id !== "spectrum" || !DesktopWidgetService.isEdge(row)
                || !root.spectrumTakes(screenName, edge))
            return
        DesktopWidgetService.update(key, { edge: edge, screen: screenName })
    }

    function spectrumToEdge(key: string, screenName: string, edge: string): void {
        const row = DesktopWidgetService.entryOf(key)
        if (!row || row.id !== "spectrum" || DesktopWidgetService.isEdge(row)
                || !root.spectrumTakes(screenName, edge))
            return
        if (DesktopWidgetService.selected === key)
            DesktopWidgetService.selected = ""
        DesktopWidgetService.update(key, {
            edge: edge, screen: screenName, col: null, row: null, family: null,
            theme: null, style: null, opacity: null
        })
    }

    function spectrumToGrid(key: string, screenName: string, col = -1, row = -1): bool {
        const widget = DesktopWidgetService.entryOf(key)
        if (!DesktopWidgetService.screenExists(screenName)
                || !widget || widget.id !== "spectrum" || !DesktopWidgetService.isEdge(widget))
            return false
        const family = DesktopWidgetService.familiesFor("spectrum")[0] ?? "4x2"
        const spot = col >= 0
            ? DesktopWidgetService.nearestFree(screenName, col, row, family, "")
            : DesktopWidgetService.firstFree(screenName, family, "")
        if (!spot)
            return false
        if (DesktopWidgetService.selected === key)
            DesktopWidgetService.selected = ""
        DesktopWidgetService.update(key, {
            col: spot.col, row: spot.row, family: family, screen: screenName,
            edge: null, along: null, reach: null, opacity: null
        })
        return true
    }
}