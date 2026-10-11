pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services as LocalServices
import qs.modules.services.desktop as Nonchalant
import qs.modules.widgets.desktop.impasto.theme as Impasto
import "."

Singleton {
    id: root

    readonly property var families: LocalServices.DesktopWidgetService.families
    readonly property var themes: LocalServices.DesktopWidgetService.themes
    readonly property var edges: ["left", "right", "bottom"]
    readonly property var spectrumLooks: LocalServices.DesktopWidgetService.spectrumLooks
    readonly property var spectrumFills: LocalServices.DesktopWidgetService.spectrumFills
    readonly property var spectrumRanges: LocalServices.DesktopWidgetService.spectrumRanges
    readonly property var spectrumColours: LocalServices.DesktopWidgetService.spectrumColours
    readonly property var pictureTypes: LocalServices.DesktopWidgetService.pictureTypes
    readonly property real handleInset: LocalServices.DesktopWidgetService.handleInset
    readonly property var offerable: ModuleService.catalogue.filter(entry => entry.desk !== false)
    readonly property int cellSize: LocalServices.DesktopWidgetService.cellSize
    readonly property int cellLargest: LocalServices.DesktopWidgetService.cellLargest
    readonly property int gutter: LocalServices.DesktopWidgetService.gutter
    readonly property int stride: LocalServices.DesktopWidgetService.stride
    readonly property bool editing: LocalServices.DesktopWidgetService.editing
    readonly property string editingScreen: LocalServices.DesktopWidgetService.editingScreen
    readonly property int editingWorkspaceId: LocalServices.DesktopWidgetService.editingWorkspaceId

    property string selected: LocalServices.DesktopWidgetService.selected
    property string picking: LocalServices.DesktopWidgetService.picking
    property bool typing: LocalServices.DesktopWidgetService.typing
    property string dragging: LocalServices.DesktopWidgetService.dragging
    property bool inHand: LocalServices.DesktopWidgetService.inHand
    property var landing: LocalServices.DesktopWidgetService.landing
    property string galleryScreen: LocalServices.DesktopWidgetService.galleryScreen
    property var menu: LocalServices.DesktopWidgetService.menu
    property int menuWorkspaceId: LocalServices.DesktopWidgetService.menuWorkspaceId
    property var trayBox: null
    property var gallerySize: null
    property bool syncingGallerySize: false
    property bool syncingTrayBox: false
    property bool syncingGalleryScreen: false

    onSelectedChanged: if (LocalServices.DesktopWidgetService.selected !== selected)
        LocalServices.DesktopWidgetService.selected = selected
    onPickingChanged: if (LocalServices.DesktopWidgetService.picking !== picking)
        LocalServices.DesktopWidgetService.picking = picking
    onTypingChanged: if (LocalServices.DesktopWidgetService.typing !== typing)
        LocalServices.DesktopWidgetService.typing = typing
    onDraggingChanged: if (LocalServices.DesktopWidgetService.dragging !== dragging)
        LocalServices.DesktopWidgetService.dragging = dragging
    onInHandChanged: if (LocalServices.DesktopWidgetService.inHand !== inHand)
        LocalServices.DesktopWidgetService.inHand = inHand
    onLandingChanged: if (LocalServices.DesktopWidgetService.landing !== landing)
        LocalServices.DesktopWidgetService.landing = landing
    onGalleryScreenChanged: {
        if (syncingGalleryScreen)
            return
        syncingGalleryScreen = true
        if (LocalServices.DesktopWidgetService.galleryScreen !== galleryScreen)
            LocalServices.DesktopWidgetService.galleryScreen = galleryScreen
        syncingGalleryScreen = false
        syncGallerySize()
        syncTrayBox()
    }
    onMenuChanged: if (LocalServices.DesktopWidgetService.menu !== menu)
        LocalServices.DesktopWidgetService.menu = menu
    onMenuWorkspaceIdChanged: if (LocalServices.DesktopWidgetService.menuWorkspaceId !== menuWorkspaceId)
        LocalServices.DesktopWidgetService.menuWorkspaceId = menuWorkspaceId
    onTrayBoxChanged: storeTrayBox()
    onGallerySizeChanged: storeGallerySize()

    Connections {
        target: LocalServices.DesktopWidgetService
        function onSelectedChanged(): void { root.selected = target.selected }
        function onPickingChanged(): void { root.picking = target.picking }
        function onTypingChanged(): void { root.typing = target.typing }
        function onDraggingChanged(): void { root.dragging = target.dragging }
        function onInHandChanged(): void { root.inHand = target.inHand }
        function onLandingChanged(): void { root.landing = target.landing }
        function onGalleryScreenChanged(): void {
            root.syncingGalleryScreen = true
            root.galleryScreen = target.galleryScreen
            root.syncingGalleryScreen = false
            root.syncGallerySize()
            root.syncTrayBox()
        }
        function onMenuChanged(): void { root.menu = target.menu }
        function onMenuWorkspaceIdChanged(): void { root.menuWorkspaceId = target.menuWorkspaceId }
        function onGallerySizesChanged(): void { root.syncGallerySize() }
        function onGalleryBoxesChanged(): void { root.syncTrayBox() }
        function onBoardsChanged(): void { root.syncGallerySize() }
        function onEditingScreenChanged(): void {
            root.syncGallerySize()
            root.syncTrayBox()
        }
        function onFallbackOutputChanged(): void {
            root.syncGallerySize()
            root.syncTrayBox()
        }
    }

    Component.onCompleted: {
        syncGallerySize()
        syncTrayBox()
    }

    function galleryScreenName(): string {
        const desktop = LocalServices.DesktopWidgetService
        return galleryScreen || desktop.editingScreen || desktop.fallbackOutput
    }

    function sizeForGallery(name: string): var {
        const kept = LocalServices.DesktopWidgetService.gallerySizes[name]
        if (!kept)
            return null
        const unit = LocalServices.DesktopWidgetService.sizeFor("2x2", name)
        const factor = 0.75
        const gap = gutter
        return {
            columns: Math.max(1, Math.round(((kept.width - 48) / factor + gap) / (unit.width + gap))),
            rows: Math.max(1, Math.round(((kept.height - 48) / factor + gap) / (unit.height + gap)))
        }
    }

    function syncGallerySize(): void {
        syncingGallerySize = true
        gallerySize = sizeForGallery(galleryScreenName())
        syncingGallerySize = false
    }

    function storeGallerySize(): void {
        if (syncingGallerySize)
            return
        const name = galleryScreenName()
        if (name === "")
            return
        if (gallerySize === null) {
            const sizes = Object.assign({}, LocalServices.DesktopWidgetService.gallerySizes)
            delete sizes[name]
            LocalServices.DesktopWidgetService.gallerySizes = sizes
            return
        }
        const unit = LocalServices.DesktopWidgetService.sizeFor("2x2", name)
        const columns = gallerySize.columns
        const rows = gallerySize.rows
        const width = (columns * unit.width + (columns - 1) * gutter) * 0.75 + 48
        const height = (rows * unit.height + (rows - 1) * gutter) * 0.75 + 48
        LocalServices.DesktopWidgetService.setGallerySize(name, width, height)
    }

    function syncTrayBox(): void {
        syncingTrayBox = true
        trayBox = LocalServices.DesktopWidgetService.galleryBoxes[galleryScreenName()] ?? null
        syncingTrayBox = false
    }

    function storeTrayBox(): void {
        if (syncingTrayBox)
            return
        const name = galleryScreenName()
        if (name === "")
            return
        const boxes = Object.assign({}, LocalServices.DesktopWidgetService.galleryBoxes)
        if (trayBox === null)
            delete boxes[name]
        else
            boxes[name] = trayBox
        LocalServices.DesktopWidgetService.galleryBoxes = boxes
    }

    function entryOf(key: string): var { return LocalServices.DesktopWidgetService.entryOf(key) }
    function nameOf(widget: var): string { return LocalServices.DesktopWidgetService.nameOf(widget) }
    function sizeFor(familyId: string, name = ""): var {
        return LocalServices.DesktopWidgetService.sizeFor(familyId, name)
    }
    function geometry(widget: var, boardWidth: real, boardHeight: real): var {
        const name = nameOf(widget)
        if (isSpectrum(widget))
            return Nonchalant.DeckService.spectrumBox(name, widget, boardWidth, boardHeight)
        if (isDeck(widget)) {
            const count = deckNotes(widget).length
            const start = Nonchalant.DeckService.startOf(widget.edge, count, alongOf(widget),
                boardWidth, boardHeight, name)
            return Nonchalant.DeckService.stripBox(widget.edge, count, start, boardWidth, boardHeight)
        }
        return LocalServices.DesktopWidgetService.geometry(widget, boardWidth, boardHeight)
    }
    function family(id: string): var {
        return LocalServices.DesktopWidgetService.family(id)
            ?? LocalServices.DesktopWidgetService.family("4x2")
    }
    function familyOf(widget: var): string { return LocalServices.DesktopWidgetService.familyOf(widget) }
    function familiesFor(id: string, theme = ""): var {
        return LocalServices.DesktopWidgetService.familiesFor(id, theme)
    }
    function familyNearest(id: string, cols: real, rows: real, theme = ""): string {
        return LocalServices.DesktopWidgetService.familyNearest(id, cols, rows, theme)
    }
    function smallest(id: string): string { return familiesFor(id)[0] ?? "4x2" }
    function themeOf(widget: var): string { return LocalServices.DesktopWidgetService.themeOf(widget) }
    function setTheme(key: string, theme: string): void {
        LocalServices.DesktopWidgetService.setTheme(key, theme)
    }
    function setFamily(key: string, familyId: string): bool {
        return LocalServices.DesktopWidgetService.setFamily(key, familyId)
    }
    function cycleFamily(key: string, direction: int): void {
        LocalServices.DesktopWidgetService.cycleFamily(key, direction)
    }
    function cellX(name: string, x: real): int { return LocalServices.DesktopWidgetService.cellX(name, x) }
    function cellY(name: string, y: real): int { return LocalServices.DesktopWidgetService.cellY(name, y) }
    function strideOn(name: string): real { return LocalServices.DesktopWidgetService.gridOn(name).stride }
    function nearestFree(name: string, col: int, row: int, familyId: string, exceptKey = ""): var {
        return LocalServices.DesktopWidgetService.nearestFree(name, col, row, familyId, exceptKey)
    }
    function firstFree(name: string, familyId: string, exceptKey = ""): var {
        return LocalServices.DesktopWidgetService.firstFree(name, familyId, exceptKey)
    }
    function place(key: string, name: string, col: int, row: int): bool {
        return LocalServices.DesktopWidgetService.place(key, name, col, row)
    }
    function add(id: string, name: string, col = -1, row = -1): string {
        return LocalServices.DesktopWidgetService.add(id, name, col, row)
    }
    function update(key: string, changes: var): void { LocalServices.DesktopWidgetService.update(key, changes) }
    function remove(key: string): void { LocalServices.DesktopWidgetService.remove(key) }
    function removeNote(noteKey: string): void { LocalServices.DesktopWidgetService.removeNote(noteKey) }
    function pictureOf(widget: var): string { return LocalServices.DesktopWidgetService.pictureOf(widget) }
    function urlOf(path: string): string { return LocalServices.DesktopWidgetService.urlOf(path) }
    function setPicture(key: string, value: string): bool {
        return LocalServices.DesktopWidgetService.setPicture(key, value)
    }
    function openPicture(widget: var): void { LocalServices.DesktopWidgetService.openPicture(widget) }
    function setCaption(key: string, value: string): void {
        LocalServices.DesktopWidgetService.setCaption(key, value)
    }
    function opacityOf(widget: var): int { return LocalServices.DesktopWidgetService.opacityOf(widget) }
    function setOpacity(key: string, value: var): void {
        LocalServices.DesktopWidgetService.setOpacity(key, value === null ? -1 : Math.round(value))
    }
    function bare(widget: var): bool { return LocalServices.DesktopWidgetService.bare(widget) }
    function inkFor(widget: var): var { return LocalServices.DesktopWidgetService.inkFor(widget) }
    function openMenu(key: string, name: string, x: real, y: real): void {
        LocalServices.DesktopWidgetService.openMenu(key, name, x, y)
    }
    function closeMenu(): void { LocalServices.DesktopWidgetService.closeMenu() }
    function overTray(name: string, x: real, y: real): bool {
        return LocalServices.DesktopWidgetService.overTray(name, x, y)
    }
    function galleryAtOn(name: string): var {
        const board = LocalServices.DesktopWidgetService.boardOn(name)
        return LocalServices.DesktopWidgetService.galleryAtOn(name, board.width, board.height)
    }
    function gallerySizeOn(name: string): var { return sizeForGallery(name) }
    function setGalleryAt(name: string, x: real, y: real): void {
        LocalServices.DesktopWidgetService.setGalleryAt(name, x, y)
    }
    function setGalleryBox(name: string, box: var): void {
        const boxes = Object.assign({}, LocalServices.DesktopWidgetService.galleryBoxes)
        if (box === null)
            delete boxes[name]
        else
            boxes[name] = box
        LocalServices.DesktopWidgetService.galleryBoxes = boxes
    }
    function edgeAt(x: real, y: real, width: real, height: real, name = ""): string {
        const screen = name || galleryScreenName()
        const insets = LocalServices.DesktopWidgetService.insetsFor(screen)
        return Nonchalant.DeckService.edgeAt(x + insets.left, y,
            width + insets.left + insets.right, height + insets.bottom)
    }
    function insetsFor(name: string): var { return LocalServices.DesktopWidgetService.insetsFor(name) }

    function isDeck(widget: var): bool { return Nonchalant.DeckService.isDeck(widget) }
    function isSpectrum(widget: var): bool {
        return LocalServices.DesktopWidgetService.isEdge(widget) && widget.id === "spectrum"
    }
    function isEdge(widget: var): bool { return LocalServices.DesktopWidgetService.isEdge(widget) }
    function alongOf(deck: var): real { return Nonchalant.DeckService.alongOf(deck) }
    function setDeckAlong(key: string, along: real): void {
        Nonchalant.DeckService.setDeckAlong(key, along)
    }
    function deckNotes(deck: var): var { return Nonchalant.DeckService.deckNotes(deck) }
    function placementOf(noteKey: string): string {
        if (LocalServices.DesktopWidgetService.widgets.some(widget => widget.id === "notes"
                && !isDeck(widget) && widget.note === noteKey))
            return "grid"
        const deck = Nonchalant.DeckService.decks.find(item => deckNotes(item).indexOf(noteKey) >= 0)
        return deck ? deck.edge : ""
    }
    function noteToEdge(key: string, name: string, edge: string): void {
        Nonchalant.DeckService.noteToEdge(key, name, edge)
    }
    function setDeckEdge(key: string, name: string, edge: string): void {
        Nonchalant.DeckService.setDeckEdge(key, name, edge)
    }
    function setTakesNew(key: string, on: bool): void {
        Nonchalant.DeckService.setTakesNew(key, on)
    }
    function toggleDeckNote(key: string, noteKey: string): void {
        const deck = entryOf(key)
        if (!isDeck(deck))
            return
        const notes = deckNotes(deck)
        if (notes.indexOf(noteKey) >= 0) {
            const left = notes.filter(note => note !== noteKey)
            if (left.length === 0)
                remove(key)
            else
                update(key, { notes: left })
            return
        }
        Nonchalant.DeckService.placeNote(noteKey, nameOf(deck), deck.edge)
    }
    function addDeck(name: string, edge = ""): void { Nonchalant.DeckService.addDeck(name, edge) }
    function spectrumTakes(name: string, edge: string): bool {
        return Nonchalant.DeckService.spectrumTakes(name, edge)
    }
    function addSpectrum(name: string, edge = ""): string {
        return Nonchalant.DeckService.addSpectrum(name, edge)
    }
    function spectrumOf(row: var): var { return LocalServices.DesktopWidgetService.spectrumOf(row) }
    function spectrumToGrid(key: string, name: string, col = -1, row = -1): bool {
        return Nonchalant.DeckService.spectrumToGrid(key, name, col, row)
    }
    function spectrumToEdge(key: string, name: string, edge: string): void {
        Nonchalant.DeckService.spectrumToEdge(key, name, edge)
    }
    function setSpectrumEdge(key: string, name: string, edge: string): void {
        Nonchalant.DeckService.setSpectrumEdge(key, name, edge)
    }
    function setSpectrum(key: string, changes: var): void {
        LocalServices.DesktopWidgetService.setSpectrum(key, changes)
    }
    function spectrumAwayOn(name: string): bool {
        return LocalServices.DesktopWidgetService.spectrumAwayOn(name)
    }
}
