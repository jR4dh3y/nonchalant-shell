pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme

Singleton {
    id: root

    readonly property int cellSize: 86
    readonly property int cellLargest: 108
    readonly property int gutter: 18
    readonly property int stride: cellSize + gutter

    readonly property list<var> families: [
        { id: "2x2", cols: 2, rows: 2, label: "Small" },
        { id: "4x2", cols: 4, rows: 2, label: "Wide" },
        { id: "4x4", cols: 4, rows: 4, label: "Large" },
        { id: "8x2", cols: 8, rows: 2, label: "Band" }
    ]

    readonly property list<var> themes: [
        { id: "modern", label: "Modern" },
        { id: "analogue", label: "Analogue" },
        { id: "sticker", label: "Sticker" }
    ]

    readonly property list<var> catalogue: [
        { id: "media", name: "Media" },
        { id: "timer", name: "Timer" },
        { id: "claude", name: "Claude" },
        { id: "codex", name: "Codex" },
        { id: "battery", name: "Battery" },
        { id: "volume", name: "Volume" },
        { id: "brightness", name: "Brightness" },
        { id: "network", name: "Network" },
        { id: "bluetooth", name: "Bluetooth" },
        { id: "weather", name: "Weather" },
        { id: "github", name: "GitHub" },
        { id: "stats", name: "System" },
        { id: "updates", name: "Updates" },
        { id: "pet", name: "Pet" },
        { id: "games", name: "Games" },
        { id: "calendar", name: "Calendar" },
        { id: "notes", name: "Notes" },
        { id: "tasks", name: "Tasks" },
        { id: "photo", name: "Photo" },
        { id: "spectrum", name: "Spectrum" },
        { id: "lyrics", name: "Lyrics" },
        { id: "clock", name: "Clock" }
    ]

    // This is the upstream DesktopService.faces matrix. Keep it aligned with Face.qml.
    readonly property var faceFamilies: ({
        modern: {
            media: ["2x2", "4x2", "4x4"], timer: ["2x2", "4x2"],
            claude: ["2x2", "4x2", "4x4"], codex: ["2x2", "4x2", "4x4"],
            battery: ["2x2", "4x2"], volume: ["2x2", "4x2"],
            brightness: ["2x2", "4x2"], network: ["2x2", "4x2"], bluetooth: ["2x2", "4x2"],
            weather: ["2x2", "4x2", "4x4", "8x2"], stats: ["2x2", "4x2", "4x4"],
            github: ["2x2", "4x2", "8x2"], updates: ["2x2", "4x2"], pet: ["2x2", "4x2"],
            games: ["2x2", "4x2"], calendar: ["2x2", "4x2", "4x4"],
            notes: ["2x2", "4x2", "4x4", "8x2"], tasks: ["2x2", "4x2", "4x4"],
            clock: ["2x2", "4x2", "8x2"], photo: ["2x2", "4x2", "4x4", "8x2"],
            spectrum: ["4x2", "8x2", "4x4"]
        },
        analogue: {
            media: ["2x2", "4x2", "4x4"], timer: ["2x2", "4x2"],
            claude: ["2x2", "4x2"], codex: ["2x2", "4x2"],
            battery: ["2x2", "4x2"], volume: ["2x2", "4x2"],
            brightness: ["2x2", "4x2"], network: ["2x2", "4x2"], bluetooth: ["2x2", "4x2"],
            weather: ["2x2", "4x2", "4x4", "8x2"], stats: ["2x2", "4x2", "4x4"],
            github: ["2x2", "4x2", "8x2"], updates: ["2x2", "4x2"], pet: ["2x2", "4x2"],
            games: ["2x2", "4x2"], calendar: ["2x2", "4x2", "4x4"],
            notes: ["2x2", "4x2", "4x4", "8x2"], tasks: ["2x2", "4x2", "4x4"],
            clock: ["2x2", "4x2", "4x4", "8x2"], photo: ["2x2", "4x2", "4x4", "8x2"],
            spectrum: ["4x2", "8x2", "4x4"]
        },
        lyrics: { lyrics: ["2x2", "4x2", "8x2", "4x4"] },
        sticker: {
            media: ["2x2", "4x2", "4x4"], timer: ["2x2", "4x2"],
            claude: ["2x2", "4x2"], codex: ["2x2", "4x2"],
            battery: ["2x2", "4x2"], volume: ["2x2", "4x2"],
            brightness: ["2x2", "4x2"], network: ["2x2", "4x2"], bluetooth: ["2x2", "4x2"],
            weather: ["2x2", "4x2", "8x2"], stats: ["2x2", "4x2"],
            github: ["2x2", "4x2", "8x2"], updates: ["2x2", "4x2"], pet: ["2x2", "4x2"],
            games: ["2x2", "4x2"], calendar: ["2x2", "4x2", "4x4"],
            notes: ["2x2", "4x2", "4x4", "8x2"], tasks: ["2x2", "4x2", "4x4"],
            clock: ["2x2", "4x2", "4x4", "8x2"], photo: ["2x2", "4x2", "4x4", "8x2"],
            spectrum: ["4x2", "8x2", "4x4"]
        }
    })

    property list<var> widgets: []
    property var boards: ({})
    property var spots: ({})
    property var keysByScreen: ({})
    property string persistedWidgets: ""

    property bool editing: false
    property string editingScreen: ""
    property int editingWorkspaceId: -1
    property string editorGrabId: ""
    property int grabSerial: 0
    property string galleryScreen: ""
    property string selected: ""
    property string picking: ""
    property string dragging: ""
    property string draggingModuleId: ""
    property bool inHand: false
    property var landing: null
    property var galleryPositions: ({})
    property var gallerySizes: ({})
    property var galleryBoxes: ({})

    property string detailKey: ""
    property string detailModuleId: ""
    property string detailScreen: ""
    property var detailRow: null
    property int detailWorkspaceId: -1
    property string detailGrabId: ""
    readonly property list<var> spectrumLooks: [
        { id: "rounded", label: "Rounded columns" },
        { id: "square", label: "Square columns" },
        { id: "segments", label: "Segments" },
        { id: "dots", label: "Dots" },
        { id: "wave", label: "Wave" }
    ]
    readonly property list<var> spectrumFills: [
        { id: "fade", label: "Fading to the tip" },
        { id: "solid", label: "Solid" },
        { id: "blend", label: "Two colours" }
    ]
    readonly property var spectrumRanges: ({
        reach: { from: 60, to: 400 },
        bar: { from: 2, to: 24 },
        gap: { from: 1, to: 16 },
        opacity: { from: 20, to: 100 }
    })
    readonly property list<var> spectrumColours: [
        { id: "palette", label: "Wallpaper accent" },
        { id: "white", label: "White" },
        { id: "red", label: "Red" },
        { id: "green", label: "Green" },
        { id: "yellow", label: "Yellow" },
        { id: "blue", label: "Blue" }
    ]


    readonly property list<string> pictureTypes: ["png", "jpg", "jpeg", "webp", "bmp", "gif"]
    readonly property real handleInset: 0.35

    readonly property Timer saver: Timer {
        interval: 120
        repeat: false
        onTriggered: {
            root.persistedWidgets = root.fingerprint(root.widgets)
            Config.desktop.widgets = root.widgets
        }
    }

    Connections {
        target: Config.desktop

        function onWidgetsChanged(): void {
            const incoming = root.normalise(Config.desktop.widgets)
            if (root.fingerprint(incoming) === root.fingerprint(root.widgets))
                return
            root.saver.stop()
            root.widgets = incoming
            root.persistedWidgets = root.fingerprint(incoming)
            root.conform()
        }

        function onThemeChanged(): void { root.conform() }
        function onHiddenChanged(): void {
            if (Config.desktop.hidden) {
                root.closeEditor()
                root.closeDetail()
            }
        }
    }

    Connections {
        target: NiriService

        function onOverviewOpenChanged(): void {
            if (NiriService.overviewOpen) {
                if (root.editing)
                    root.closeEditor()
                if (root.detailModuleId !== "")
                    root.closeDetail()
            }
        }

        function onFullscreenOutputsChanged(): void {
            if (root.editing && root.isFullscreen(root.editingScreen))
                root.closeEditor()
            if (root.detailModuleId !== "" && root.isFullscreen(root.detailScreen))
                root.closeDetail()
        }

        function onFocusedWorkspaceChanged(): void {
            const current = Number(NiriService.monitorFor(root.editingScreen)?.activeWorkspace?.id ?? -1)
            if (root.editing && root.editingWorkspaceId >= 0
                    && current !== root.editingWorkspaceId)
                root.closeEditor()
            const detailWorkspace = Number(NiriService.monitorFor(root.detailScreen)?.activeWorkspace?.id ?? -1)
            if (root.detailModuleId !== "" && root.detailWorkspaceId >= 0
                    && detailWorkspace !== root.detailWorkspaceId)
                root.closeDetail()
        }

        function onRawEvent(event: var): void {
            if (event.WorkspaceActivated) {
                const workspace = NiriService.workspaceById(event.WorkspaceActivated.id)
                if (root.editing && workspace?.output === root.editingScreen
                        && Number(workspace.id) !== root.editingWorkspaceId)
                    root.closeEditor()
                if (root.detailModuleId !== "" && workspace?.output === root.detailScreen
                        && Number(workspace.id) !== root.detailWorkspaceId)
                    root.closeDetail()
            }
            if (event.OverviewOpenedOrClosed?.is_open === true) {
                root.closeEditor()
                root.closeDetail()
            }
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void { root.syncKeys() }
    }

    Component.onCompleted: {
        root.widgets = root.normalise(Config.desktop.widgets)
        root.persistedWidgets = root.fingerprint(root.widgets)
        root.conform()
        root.syncKeys()
    }

    onWidgetsChanged: {
        root.spots = root.calculateSpots()
        root.syncKeys()
    }

    onBoardsChanged: {
        root.spots = root.calculateSpots()
        root.syncKeys()
    }
    onEditingChanged: root.syncKeys()

    onGalleryScreenChanged: {
        if (root.editing && root.screenExists(root.galleryScreen)) {
            root.editingScreen = root.galleryScreen
            root.editingWorkspaceId = Number(NiriService.monitorFor(root.galleryScreen)?.activeWorkspace?.id ?? -1)
        }
    }

    function fingerprint(value: var): string {
        return JSON.stringify(value ?? [])
    }

    function normalise(value: var): list<var> {
        const incoming = value && typeof value.length === "number" ? value : []
        const rows = []
        const used = ({})
        for (let index = 0; index < incoming.length; index++) {
            const source = incoming[index]
            if (!source || typeof source.id !== "string" || source.id === "")
                continue
            const row = Object.assign({}, source)
            let key = typeof row.key === "string" && row.key !== "" ? row.key : row.id
            if (used[key]) {
                let suffix = 2
                while (used[`${row.id}-${suffix}`])
                    suffix++
                key = `${row.id}-${suffix}`
            }
            used[key] = true
            row.key = key
            if (typeof row.col !== "number" || !Number.isFinite(row.col))
                row.col = 0
            if (typeof row.row !== "number" || !Number.isFinite(row.row))
                row.row = 0
            if (typeof row.family !== "string" || !root.family(row.family))
                row.family = "4x2"
            rows.push(row)
        }
        return rows
    }

    function family(id: string): var {
        return root.families.find(entry => entry.id === id) ?? null
    }

    function catalogueEntry(id: string): var {
        return root.catalogue.find(entry => entry.id === id) ?? null
    }

    function configuredTheme(): string {
        const id = Config.desktop?.theme ?? "modern"
        return root.themes.some(entry => entry.id === id) ? id : "modern"
    }

    function themeOf(widget: var): string {
        if (widget && widget.id === "lyrics")
            return "lyrics"
        const own = widget && typeof widget.theme === "string" ? widget.theme : ""
        return root.themes.some(entry => entry.id === own) ? own : root.configuredTheme()
    }

    function familiesFor(id: string, theme = ""): list<string> {
        if (id === "lyrics")
            return root.faceFamilies.lyrics.lyrics
        const chosen = theme !== "" ? theme : root.configuredTheme()
        const registry = root.faceFamilies[chosen] ?? root.faceFamilies.modern
        return registry[id] ?? []
    }

    function offers(id: string, familyId: string, theme = ""): bool {
        return root.familiesFor(id, theme).indexOf(familyId) >= 0
    }

    function drawnFamily(id: string, familyId: string, theme: string): string {
        if (root.offers(id, familyId, theme))
            return familyId
        const wanted = root.family(familyId) ?? root.family("4x2")
        let best = ""
        let bestArea = 0
        for (const offered of root.familiesFor(id, theme)) {
            const shape = root.family(offered)
            const area = shape.cols * shape.rows
            if (shape.cols <= wanted.cols && shape.rows <= wanted.rows && area > bestArea) {
                best = offered
                bestArea = area
            }
        }
        return best || root.familiesFor(id, theme)[0] || "4x2"
    }

    function familyOf(widget: var): string {
        const desired = widget && typeof widget.family === "string" ? widget.family : "4x2"
        return root.drawnFamily(widget?.id ?? "", desired, root.themeOf(widget))
    }

    function conform(): void {
        const changes = []
        for (const widget of root.widgets) {
            const kept = widget.family ?? "4x2"
            const drawn = root.drawnFamily(widget.id, kept, root.themeOf(widget))
            if (drawn !== kept)
                changes.push({ key: widget.key, family: drawn })
        }
        if (changes.length === 0)
            return
        root.write(root.widgets.map(widget => {
            const change = changes.find(entry => entry.key === widget.key)
            return change ? Object.assign({}, widget, { family: change.family }) : widget
        }))
    }

    function fallbackScreenName(): string {
        const focused = NiriService.focusedMonitor?.name ?? ""
        if (focused !== "" && Quickshell.screens.some(screen => screen.name === focused))
            return focused
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    }

    function screenExists(name: string): bool {
        return name !== "" && Quickshell.screens.some(screen => screen.name === name)
    }

    function nameOf(widget: var): string {
        const saved = widget && typeof widget.screen === "string" ? widget.screen : ""
        return root.screenExists(saved) ? saved : root.fallbackScreenName()
    }

    function screenField(name: string): var {
        return name !== "" ? name : null
    }

    function isFullscreen(name: string): bool {
        return name !== "" && NiriService.fullscreenOutputs.indexOf(name) >= 0
    }

    function insetsFor(name: string): var {
        const panel = Visibilities.getBarPanelForScreen(name)
        const reserve = panel
            ? Math.max(0, Number(panel.totalBarHeight ?? 0) + Number(panel.barOuterMargin ?? 0))
            : 0
        const position = Config.bar?.position ?? "top"
        return {
            top: position === "top" ? reserve : 0,
            right: 0,
            bottom: position === "bottom" ? reserve : 0,
            left: 0
        }
    }

    function setBoard(name: string, width: real, height: real): void {
        if (name === "")
            return
        const old = root.boards[name]
        if (old && old.width === width && old.height === height)
            return
        const next = Object.assign({}, root.boards)
        next[name] = { width: width, height: height }
        root.boards = next
    }

    function boardOn(name: string): var {
        return root.boards[name] ?? { width: 0, height: 0 }
    }

    function gridFor(width: real, height: real): var {
        if (width <= 0 || height <= 0)
            return { stride: root.stride, columns: 8, rows: 6, originX: root.gutter, originY: root.gutter }
        const shortest = Math.min(width, height)
        const difference = Math.abs(width - height)
        const apart = Math.floor(difference / root.stride)
        const even = apart > 0 && difference / apart - root.gutter <= root.cellLargest
        const stride = even ? difference / apart : root.stride
        let across = Math.max(1, Math.round((shortest - root.gutter) / stride))
        if (across > 1 && across * stride > shortest)
            across -= 1
        const count = length => even
            ? across + Math.round((length - shortest) / stride)
            : Math.max(1, Math.floor(length / stride))
        const columns = count(width)
        const rows = count(height)
        return {
            stride: stride,
            columns: columns,
            rows: rows,
            originX: (width + root.gutter - columns * stride) / 2,
            originY: (height + root.gutter - rows * stride) / 2
        }
    }

    function gridOn(name: string): var {
        const board = root.boardOn(name)
        return root.gridFor(board.width, board.height)
    }

    function columnsOn(name: string): int { return root.gridOn(name).columns }
    function rowsOn(name: string): int { return root.gridOn(name).rows }

    function offsetX(name: string, col: int): real {
        const grid = root.gridOn(name)
        return Math.round(grid.originX + col * grid.stride)
    }

    function offsetY(name: string, row: int): real {
        const grid = root.gridOn(name)
        return Math.round(grid.originY + row * grid.stride)
    }

    function span(name: string, count: int): real {
        return Math.round(count * root.gridOn(name).stride - root.gutter)
    }

    function cellX(name: string, x: real): int {
        const grid = root.gridOn(name)
        return Math.round((x - grid.originX) / grid.stride)
    }

    function cellY(name: string, y: real): int {
        const grid = root.gridOn(name)
        return Math.round((y - grid.originY) / grid.stride)
    }

    function sizeFor(familyId: string, name = ""): var {
        const shape = root.family(familyId) ?? root.family("4x2")
        const on = name !== "" ? name : root.fallbackScreenName()
        if (on === "")
            return { width: shape.cols * root.stride - root.gutter, height: shape.rows * root.stride - root.gutter }
        return {
            width: root.offsetX(on, shape.cols) - root.gutter - root.offsetX(on, 0),
            height: root.offsetY(on, shape.rows) - root.gutter - root.offsetY(on, 0)
        }
    }

    function isEdge(widget: var): bool {
        return !!widget && typeof widget.edge === "string" && widget.edge !== ""
    }

    function widgetsOn(name: string): list<var> {
        return root.widgets.filter(widget => root.nameOf(widget) === name)
    }

    function gridWidgetsOn(name: string): list<var> {
        return root.widgets.filter(widget => !root.isEdge(widget) && root.nameOf(widget) === name)
    }

    function entryOf(key: string): var {
        return root.widgets.find(widget => widget.key === key) ?? null
    }

    function countOf(id: string): int {
        return root.widgets.filter(widget => widget.id === id).length
    }

    function placed(id: string): bool { return root.countOf(id) > 0 }

    function calculateSpots(): var {
        const grouped = ({})
        const result = ({})
        for (const widget of root.widgets) {
            if (root.isEdge(widget))
                continue
            const name = root.nameOf(widget)
            grouped[name] = (grouped[name] ?? []).concat([widget])
        }
        for (const name in grouped) {
            const grid = root.gridOn(name)
            const rows = grouped[name].slice().sort((left, right) => {
                const leftShape = root.family(root.familyOf(left))
                const rightShape = root.family(root.familyOf(right))
                const leftRight = (left.col ?? 0) + leftShape.cols
                const rightRight = (right.col ?? 0) + rightShape.cols
                const leftBottom = (left.row ?? 0) + leftShape.rows
                const rightBottom = (right.row ?? 0) + rightShape.rows
                return rightRight - leftRight || rightBottom - leftBottom
            })
            const occupied = []
            for (const widget of rows) {
                const shape = root.family(root.familyOf(widget))
                const home = root.clamped(widget, shape, name)
                let spot = root.freeAgainst(occupied, home.col, home.row, shape, grid)
                    ? home : root.nearestAgainst(occupied, home.col, home.row, shape, grid)
                if (!spot)
                    spot = home
                result[widget.key] = spot
                if (shape.cols <= grid.columns && shape.rows <= grid.rows)
                    occupied.push({ col: spot.col, row: spot.row, cols: shape.cols, rows: shape.rows })
            }
        }
        return result
    }

    function clamped(widget: var, shape: var, name: string): var {
        const grid = root.gridOn(name)
        return {
            col: Math.max(0, Math.min(Math.max(0, grid.columns - shape.cols), Number(widget.col ?? 0))),
            row: Math.max(0, Math.min(Math.max(0, grid.rows - shape.rows), Number(widget.row ?? 0)))
        }
    }

    function clashes(occupied: var, col: int, row: int, shape: var): bool {
        return occupied.some(other => col < other.col + other.cols && other.col < col + shape.cols
            && row < other.row + other.rows && other.row < row + shape.rows)
    }

    function freeAgainst(occupied: var, col: int, row: int, shape: var, grid: var): bool {
        return col >= 0 && row >= 0 && col + shape.cols <= grid.columns && row + shape.rows <= grid.rows
            && !root.clashes(occupied, col, row, shape)
    }

    function nearestAgainst(occupied: var, col: int, row: int, shape: var, grid: var): var {
        let found = null
        let distance = Infinity
        for (let y = 0; y + shape.rows <= grid.rows; y++) {
            for (let x = 0; x + shape.cols <= grid.columns; x++) {
                if (!root.freeAgainst(occupied, x, y, shape, grid))
                    continue
                const next = (x - col) ** 2 + (y - row) ** 2
                if (next < distance) {
                    found = { col: x, row: y }
                    distance = next
                }
            }
        }
        return found
    }

    function spotOf(widget: var): var {
        return root.spots[widget?.key ?? ""]
            ?? root.clamped(widget ?? ({}), root.family(root.familyOf(widget)), root.nameOf(widget))
    }

    function geometry(widget: var, boardWidth: real, boardHeight: real): var {
        const name = root.nameOf(widget)
        const shape = root.family(root.familyOf(widget))
        const spot = root.spotOf(widget)
        const grid = root.gridOn(name)
        const x = root.offsetX(name, spot.col)
        const y = root.offsetY(name, spot.row)
        return {
            x: x,
            y: y,
            width: root.offsetX(name, spot.col + shape.cols) - root.gutter - x,
            height: root.offsetY(name, spot.row + shape.rows) - root.gutter - y,
            valid: shape.cols <= grid.columns && shape.rows <= grid.rows
        }
    }

    function overlaps(name: string, col: int, row: int, familyId: string, exceptKey: string): bool {
        const shape = root.family(familyId)
        return root.gridWidgetsOn(name).some(other => {
            if (other.key === exceptKey)
                return false
            const theirs = root.family(root.familyOf(other))
            const spot = root.spotOf(other)
            return col < spot.col + theirs.cols && spot.col < col + shape.cols
                && row < spot.row + theirs.rows && spot.row < row + shape.rows
        })
    }

    function onBoard(name: string, col: int, row: int, familyId: string): bool {
        const shape = root.family(familyId)
        const grid = root.gridOn(name)
        return col >= 0 && row >= 0 && col + shape.cols <= grid.columns && row + shape.rows <= grid.rows
    }

    function free(name: string, col: int, row: int, familyId: string, exceptKey: string): bool {
        return root.onBoard(name, col, row, familyId)
            && !root.overlaps(name, col, row, familyId, exceptKey)
    }

    function nearestFree(name: string, col: int, row: int, familyId: string, exceptKey = ""): var {
        if (root.free(name, col, row, familyId, exceptKey))
            return { col: col, row: row }
        const shape = root.family(familyId)
        const grid = root.gridOn(name)
        let best = null
        let bestDistance = Infinity
        for (let y = 0; y + shape.rows <= grid.rows; y++) {
            for (let x = 0; x + shape.cols <= grid.columns; x++) {
                if (!root.free(name, x, y, familyId, exceptKey))
                    continue
                const distance = (x - col) ** 2 + (y - row) ** 2
                if (distance < bestDistance) {
                    best = { col: x, row: y }
                    bestDistance = distance
                }
            }
        }
        return best
    }

    function firstFree(name: string, familyId: string, exceptKey = ""): var {
        const shape = root.family(familyId)
        const grid = root.gridOn(name)
        for (let y = 0; y + shape.rows <= grid.rows; y++) {
            for (let x = 0; x + shape.cols <= grid.columns; x++) {
                if (root.free(name, x, y, familyId, exceptKey))
                    return { col: x, row: y }
            }
        }
        return null
    }

    function fingerprintKeys(map: var, next: var): var {
        let same = true
        for (const name in next) {
            const before = map[name]
            if (before && before.length === next[name].length
                    && before.every((key, index) => key === next[name][index]))
                next[name] = before
            else
                same = false
        }
        for (const name in map) {
            if (!next[name])
                same = false
        }
        return same ? map : next
    }

    function syncKeys(): void {
        const grouped = ({})
        for (const screen of Quickshell.screens)
            grouped[screen.name] = []
        for (const widget of root.widgets) {
            if (root.isEdge(widget))
                continue
            const name = root.nameOf(widget)
            grouped[name] = (grouped[name] ?? []).concat([widget.key])
        }
        root.keysByScreen = root.fingerprintKeys(root.keysByScreen, grouped)
    }

    function keysOn(name: string): list<string> {
        return root.keysByScreen[name] ?? []
    }

    function write(next: list<var>): void {
        root.widgets = next
        root.saver.restart()
    }

    function update(key: string, changes: var): void {
        if (!root.entryOf(key))
            return
        root.write(root.widgets.map(widget => {
            if (widget.key !== key)
                return widget
            const next = Object.assign({}, widget, changes)
            for (const field in changes) {
                if (changes[field] === null || changes[field] === undefined)
                    delete next[field]
            }
            return next
        }))
    }

    function newKey(id: string): string {
        for (let suffix = 1; ; suffix++) {
            const key = `${id}-${suffix}`
            if (!root.entryOf(key))
                return key
        }
    }

    function add(id: string, screenName: string, col = -1, row = -1): string {
        if (!root.catalogueEntry(id) || !root.screenExists(screenName))
            return ""
        const familyId = root.familiesFor(id)[0] ?? ""
        if (familyId === "")
            return ""
        const spot = col >= 0
            ? root.nearestFree(screenName, col, row, familyId)
            : root.firstFree(screenName, familyId)
        if (!spot)
            return ""
        const made = {
            key: root.newKey(id), id: id, screen: root.screenField(screenName),
            col: spot.col, row: spot.row, family: familyId
        }
        root.write(root.widgets.concat([made]))
        return made.key
    }

    function remove(key: string): void {
        if (root.selected === key)
            root.selected = ""
        if (root.detailKey === key)
            root.closeDetail()
        root.write(root.widgets.filter(widget => widget.key !== key))
    }
    function removeNote(noteKey: string): void {
        DeckService.removeNote(noteKey)
    }

    function noteAdded(noteKey: string): void {
        DeckService.noteAdded(noteKey)
    }

    function place(key: string, screenName: string, col: int, row: int): bool {
        const widget = root.entryOf(key)
        if (!widget || root.isEdge(widget) || !root.screenExists(screenName))
            return false
        const exceptKey = root.nameOf(widget) === screenName ? key : ""
        const spot = root.nearestFree(screenName, col, row, root.familyOf(widget), exceptKey)
        if (!spot)
            return false
        root.update(key, { col: spot.col, row: spot.row, screen: root.screenField(screenName) })
        return true
    }

    function setFamily(key: string, familyId: string): bool {
        const widget = root.entryOf(key)
        if (!widget || !root.offers(widget.id, familyId, root.themeOf(widget)))
            return false
        if (root.familyOf(widget) === familyId)
            return true
        const name = root.nameOf(widget)
        const spot = root.nearestFree(name, root.spotOf(widget).col, root.spotOf(widget).row, familyId, key)
        if (!spot)
            return false
        root.update(key, { family: familyId, col: spot.col, row: spot.row })
        return true
    }

    function cycleFamily(key: string, direction: int): void {
        const widget = root.entryOf(key)
        if (!widget || direction === 0)
            return
        const available = root.familiesFor(widget.id, root.themeOf(widget))
        const current = available.indexOf(root.familyOf(widget))
        const spot = root.spotOf(widget)
        for (let step = 1; step < available.length; step++) {
            const index = (current + direction * step % available.length + available.length) % available.length
            if (root.nearestFree(root.nameOf(widget), spot.col, spot.row, available[index], key)) {
                root.setFamily(key, available[index])
                return
            }
        }
    }

    function familyNearest(id: string, cols: real, rows: real, theme = ""): string {
        const available = root.familiesFor(id, theme)
        const x = cols - root.handleInset
        const y = rows - root.handleInset
        let best = ""
        let bestArea = Infinity
        for (const id_ of available) {
            const shape = root.family(id_)
            const area = shape.cols * shape.rows
            if (x <= shape.cols && y <= shape.rows && area < bestArea) {
                best = id_
                bestArea = area
            }
        }
        if (best !== "")
            return best
        let distance = Infinity
        for (const id_ of available) {
            const shape = root.family(id_)
            const next = (shape.cols - cols) ** 2 + (shape.rows - rows) ** 2
            if (next < distance) {
                distance = next
                best = id_
            }
        }
        return best
    }

    function setTheme(key: string, theme: string): void {
        const widget = root.entryOf(key)
        if (!widget || (theme !== "" && !root.themes.some(entry => entry.id === theme)))
            return
        root.update(key, { theme: theme === "" ? null : theme })
        root.conform()
    }

    function opacityOf(widget: var): int {
        const own = widget && typeof widget.opacity === "number" ? widget.opacity : Config.desktop.opacity
        return Math.max(0, Math.min(100, Math.round(Number(own ?? 100))))
    }

    function setOpacity(key: string, value: int): void {
        root.update(key, value < 0 ? { opacity: null } : { opacity: Math.max(0, Math.min(100, value)) })
    }

    function styleOf(widget: var): string {
        const own = widget && typeof widget.style === "string" ? widget.style : ""
        if (own === "glass" || own === "solid")
            return own
        const global = Config.desktop.ground ?? ""
        return global === "glass" || global === "solid" ? global : ""
    }

    function setStyle(key: string, style: string): void {
        if (style !== "" && style !== "glass" && style !== "solid")
            return
        root.update(key, { style: style === "" ? null : style })
    }

    function inkFor(widget: var): var {
        const glass = root.styleOf(widget) === "glass"
        return {
            ground: glass ? Colors.surfaceContainerLow : Colors.surfaceContainerLowest,
            border: Colors.outlineVariant,
            text: Colors.overBackground,
            muted: Colors.outline,
            accent: Colors.primary,
            accentText: Colors.overPrimary,
            raised: Colors.surfaceContainerHigh,
            dim: Colors.outlineVariant,
            red: Colors.error,
            green: Colors.green,
            yellow: Colors.yellow,
            blue: Colors.blue,
            paper: Colors.surfaceContainerHigh
        }
    }

    function setPicture(key: string, value: string): bool {
        const text = String(value ?? "").trim()
        const path = text.startsWith("file://") ? decodeURIComponent(text.slice(7)) : text
        const extension = path.slice(path.lastIndexOf(".") + 1).toLowerCase()
        if (path === "" || root.pictureTypes.indexOf(extension) < 0 || !root.entryOf(key))
            return false
        root.update(key, { picture: path })
        return true
    }

    function urlOf(path: string): string {
        return "file://" + path.split("/").map(segment => encodeURIComponent(segment)).join("/")
    }

    function pictureOf(widget: var): string {
        const path = widget && typeof widget.picture === "string" ? widget.picture : ""
        return path === "" ? "" : root.urlOf(path)
    }

    function setCaption(key: string, value: string): void {
        const caption = String(value ?? "").slice(0, 40)
        root.update(key, { caption: caption === "" ? null : caption })
    }
    function openPicture(widget: var): void {
        const path = widget && typeof widget.picture === "string" ? widget.picture : ""
        if (path !== "")
            Quickshell.execDetached(["imv", path])
    }

    function chooseScreen(screenName: string): string {
        return root.screenExists(screenName) ? screenName : root.fallbackScreenName()
    }

    function openEditor(screenName = ""): bool {
        const name = root.chooseScreen(screenName)
        if (name === "" || root.isFullscreen(name))
            return false
        root.closeEditor()
        root.closeDetail()
        FocusGrabManager.clearTopGrab()
        Visibilities.closeActiveBarPopup()
        Visibilities.setActiveModule("")
        Visibilities.clearAll()
        Visibilities.collapseOtherIslands(null)
        GlobalStates.settingsWindowVisible = false
        root.editing = true
        root.editingScreen = name
        root.galleryScreen = name
        root.editingWorkspaceId = Number(NiriService.monitorFor(name)?.activeWorkspace?.id ?? -1)
        root.selected = ""
        root.picking = ""
        root.dragging = ""
        root.draggingModuleId = ""
        root.inHand = false
        root.landing = null
        const grabId = "desktop-editor-" + ++root.grabSerial
        root.editorGrabId = grabId
        FocusGrabManager.requestGrab(grabId, () => {
            if (root.editorGrabId === grabId)
                root.closeEditor()
        })
        return true
    }

    function closeEditor(): void {
        FocusGrabManager.releaseGrab(root.editorGrabId)
        root.editorGrabId = ""
        root.editing = false
        root.editingScreen = ""
        root.galleryScreen = ""
        root.editingWorkspaceId = -1
        root.selected = ""
        root.picking = ""
        root.dragging = ""
        root.draggingModuleId = ""
        root.inHand = false
        root.landing = null
        root.galleryPositions = ({})
        root.gallerySizes = ({})
        root.galleryBoxes = ({})
    }

    function spectrumColourName(value: var, fallback: string): string {
        const name = String(value ?? "")
        if (root.spectrumColours.some(entry => entry.id === name)
                || /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(name))
            return name
        return fallback
    }

    function spectrumColour(name: string): color {
        switch (name) {
        case "palette": return Colors.primary
        case "white": return Colors.overBackground
        case "red": return Colors.error
        case "green": return Colors.green
        case "yellow": return Colors.yellow
        case "blue": return Colors.blue
        default: return Qt.color(name)
        }
    }

    function spectrumOf(row: var): var {
        const own = row ?? ({})
        const pick = (value, list, fallback) =>
            list.some(entry => (entry.id ?? entry) === value) ? value : fallback
        const within = (field, fallback) => {
            const range = root.spectrumRanges[field]
            const value = own[field]
            return typeof value === "number"
                ? Math.max(range.from, Math.min(range.to, Math.round(value))) : fallback
        }
        const colorName = root.spectrumColourName(own.color, "palette")
        const color2Name = root.spectrumColourName(own.color2, "white")
        return {
            look: pick(own.look, root.spectrumLooks, "rounded"),
            fill: pick(own.fill, root.spectrumFills, "fade"),
            colorName: colorName,
            color2Name: color2Name,
            color: root.spectrumColour(colorName),
            color2: root.spectrumColour(color2Name),
            reach: within("reach", 180),
            bar: within("bar", 6),
            gap: within("gap", 4),
            lows: pick(own.lows, ["corners", "along"], "corners"),
            peaks: own.peaks === true,
            opacity: within("opacity", root.opacityOf(row))
        }
    }

    function setSpectrum(key: string, changes: var): void {
        const widget = root.entryOf(key)
        if (widget && widget.id === "spectrum")
            root.update(key, changes)
    }


    function spectrumAwayOn(name: string): bool {
        if (!root.screenExists(name) || root.isFullscreen(name) || NiriService.overviewOpen)
            return true
        if (!Config.desktop.spectrumOnEmpty)
            return false
        const workspace = NiriService.monitorFor(name)?.activeWorkspace
        return !!workspace && NiriService.windowsForWorkspace(workspace.id).length > 0
    }
    function openDetail(moduleId: string, row: var): bool {
        if (["notes", "tasks", "calendar", "timer", "pet", "games"].indexOf(moduleId) < 0 || !row)
            return false
        const name = root.nameOf(row)
        if (name === "" || root.isFullscreen(name) || NiriService.overviewOpen)
            return false
        root.closeEditor()
        root.closeDetail()
        FocusGrabManager.clearTopGrab()
        Visibilities.closeActiveBarPopup()
        Visibilities.setActiveModule("")
        Visibilities.collapseOtherIslands(null)
        GlobalStates.settingsWindowVisible = false
        root.detailRow = Object.assign({}, row)
        root.detailKey = typeof row.key === "string" ? row.key : ""
        root.detailScreen = name
        root.detailWorkspaceId = Number(NiriService.monitorFor(name)?.activeWorkspace?.id ?? -1)
        root.detailModuleId = moduleId
        const grabId = "desktop-detail-" + ++root.grabSerial
        root.detailGrabId = grabId
        FocusGrabManager.requestGrab(grabId, () => {
            if (root.detailGrabId === grabId)
                root.closeDetail()
        })
        return true
    }

    function closeDetail(): void {
        FocusGrabManager.releaseGrab(root.detailGrabId)
        root.detailGrabId = ""
        root.detailModuleId = ""
        root.detailKey = ""
        root.detailScreen = ""
        root.detailRow = null
        root.detailWorkspaceId = -1
    }

    function beginWidgetDrag(key: string): void {
        if (!root.editing || !root.entryOf(key))
            return
        root.selected = ""
        root.picking = ""
        root.dragging = key
        root.inHand = true
        root.landing = null
    }

    function endWidgetDrag(): void {
        root.dragging = ""
        root.inHand = false
        root.landing = null
    }

    function beginGalleryDrag(id: string): void {
        if (!root.editing || !root.catalogueEntry(id))
            return
        root.selected = ""
        root.draggingModuleId = id
        root.inHand = true
        root.landing = null
    }

    function endGalleryDrag(): void {
        root.draggingModuleId = ""
        root.inHand = false
        root.landing = null
    }

    function gallerySizeOn(name: string, boardWidth: real, boardHeight: real): var {
        const kept = root.gallerySizes[name]
        if (kept)
            return kept
        return {
            width: Math.max(160, Math.min(520, boardWidth - root.gutter * 2)),
            height: Math.max(180, Math.min(440, boardHeight - root.gutter * 2))
        }
    }

    function galleryAtOn(name: string, boardWidth: real, boardHeight: real): var {
        const size = root.gallerySizeOn(name, boardWidth, boardHeight)
        const kept = root.galleryPositions[name]
        if (kept)
            return {
                x: Math.max(0, Math.min(boardWidth - size.width, kept.x)),
                y: Math.max(0, Math.min(boardHeight - size.height, kept.y))
            }
        return {
            x: Math.max(0, (boardWidth - size.width) / 2),
            y: Math.max(0, boardHeight - size.height - root.gutter)
        }
    }

    function setGalleryAt(name: string, x: real, y: real): void {
        const next = Object.assign({}, root.galleryPositions)
        next[name] = { x: x, y: y }
        root.galleryPositions = next
    }

    function setGallerySize(name: string, width: real, height: real): void {
        const next = Object.assign({}, root.gallerySizes)
        next[name] = { width: width, height: height }
        root.gallerySizes = next
    }

    function setGalleryBox(name: string, x: real, y: real, width: real, height: real): void {
        const next = Object.assign({}, root.galleryBoxes)
        next[name] = { x: x, y: y, width: width, height: height }
        root.galleryBoxes = next
    }

    function overGallery(name: string, x: real, y: real): bool {
        const box = root.galleryBoxes[name]
        return box !== undefined && name === root.galleryScreen
            && x >= box.x && x <= box.x + box.width
            && y >= box.y && y <= box.y + box.height
    }
    function overTray(name: string, x: real, y: real): bool {
        return root.overGallery(name, x, y)
    }

    function isVisibleOn(name: string): bool {
        return !root.isFullscreen(name) && (!Config.desktop.hidden || root.editing)
    }
}
