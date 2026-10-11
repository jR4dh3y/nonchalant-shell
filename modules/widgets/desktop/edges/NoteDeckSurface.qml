pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.widgets.desktop.impasto.components
import qs.modules.widgets.desktop.impasto.theme as Impasto
import qs.modules.widgets.desktop.impasto.services as ImpastoServices

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    readonly property string screenName: root.targetScreen?.name ?? ""
    readonly property bool editing: DesktopWidgetService.editing
    readonly property var decks: DeckService.decksOn(root.screenName)
    readonly property bool deaf: (DesktopWidgetService.inHand
        && DeckService.draggingScreen !== root.screenName
        && DeckService.slidingScreen !== root.screenName)
        || (DeckService.heldScreen !== "" && DeckService.heldScreen !== root.screenName)
    readonly property bool whole: (DeckService.heldScreen === root.screenName && DeckService.held !== "")
        || (DeckService.draggingScreen === root.screenName && DeckService.dragging !== "")
        || (DeckService.slidingScreen === root.screenName && DeckService.sliding !== "")
        || root.menu !== null
    readonly property string menuGrabId: `note-deck-menu-${root.screenName}`
    property var menu: null
    property real reveal: root.out ? 1 : 0
    readonly property bool out: root.editing
        || (DeckService.revealed && DeckService.revealedScreen === root.screenName)
        || (DeckService.peeked !== "" && DeckService.peekedScreen === root.screenName)
        || (DeckService.receiving !== "" && DeckService.receivingScreen === root.screenName)
    readonly property real depth: DeckService.sliver + (DeckService.tabDepth - DeckService.sliver) * root.reveal
    readonly property var peekedNote: DeckService.peekedScreen === root.screenName
        && DeckService.draggingScreen !== root.screenName && root.menu === null
        ? ImpastoServices.NotesService.entry(DeckService.peeked) : null
    readonly property var peekAt: DeckService.peekedScreen === root.screenName
        ? root.boxFor(DeckService.peeked) : null
    readonly property Timer retract: Timer {
        interval: 320
        onTriggered: {
            if (DeckService.revealedScreen === root.screenName) {
                DeckService.revealed = false
                DeckService.revealedScreen = ""
            }
            if (DeckService.peekedScreen === root.screenName) {
                DeckService.peeked = ""
                DeckService.peekedScreen = ""
            }
        }
    }

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    screen: root.targetScreen
    visible: !Config.desktop.hidden
        && (root.editing || !DeckService.awayOn(root.screenName))
        && (root.decks.length > 0
            || (DeckService.receiving !== "" && DeckService.receivingScreen === root.screenName)
            || root.editing)

    WlrLayershell.namespace: "nonchalant:desktop:note-decks"
    WlrLayershell.layer: root.editing ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: root.visible && root.menu !== null
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    Behavior on reveal {
        NumberAnimation { duration: Impasto.Theme.durationMedium; easing.type: Impasto.Theme.easing }
    }
    Item {
        anchors.fill: parent
        focus: root.visible && root.menu !== null
        Keys.onEscapePressed: event => {
            root.closeMenu()
            event.accepted = true
        }
    }

    onMenuChanged: {
        if (root.menu === null) {
            FocusGrabManager.releaseGrab(root.menuGrabId)
            return
        }
        const currentMenu = root.menu
        FocusGrabManager.requestGrab(root.menuGrabId, () => {
            if (root.menu === currentMenu)
                root.closeMenu()
        }, false)
    }
    onVisibleChanged: if (!root.visible) root.closeMenu()

    mask: Region {
        x: 0
        y: 0
        width: root.whole && !root.deaf ? root.width : 0
        height: root.whole && !root.deaf ? root.height : 0
        regions: root.whole || root.deaf ? [] : root.cutouts.concat(root.peekAt ? [peekRegion] : [])
    }

    readonly property var cutouts: {
        const regions = []
        for (let index = 0; index < strips.count; index++) {
            const region = strips.objectAt(index)
            if (region)
                regions.push(region)
        }
        return regions
    }

    Instantiator {
        id: strips
        model: root.decks

        delegate: Region {
            required property var modelData
            readonly property real start: root.startOf(modelData.edge, modelData.notes.length, modelData.along)
            readonly property var box: DeckService.stripBox(
                modelData.edge, modelData.notes.length, start, board.width, board.height)
            readonly property real gripReach: root.editing ? DeckService.grip + DeckService.tabGap : 0

            x: board.x + (modelData.edge === "right" ? board.width - root.depth
                : (modelData.edge === "bottom" ? box.x - gripReach : 0))
            y: board.y + (modelData.edge === "bottom" ? board.height - root.depth : box.y - gripReach)
            width: modelData.edge === "bottom" ? box.width + gripReach : root.depth
            height: modelData.edge === "bottom" ? root.depth : box.height + gripReach
        }
    }

    Region {
        id: peekRegion
        x: root.peekAt ? board.x + root.peekAt.x - 6 : 0
        y: root.peekAt ? board.y + root.peekAt.y - 6 : 0
        width: root.peekAt ? root.peekAt.width + 12 : 0
        height: root.peekAt ? root.peekAt.height + 12 : 0
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.menu !== null
        acceptedButtons: Qt.AllButtons
        onPressed: root.menu = null
    }

    Item {
        id: board
        anchors.fill: parent
        readonly property var insets: DesktopWidgetService.insetsFor(root.screenName)
        anchors.topMargin: insets.top
        anchors.leftMargin: insets.left
        anchors.rightMargin: insets.right
        anchors.bottomMargin: insets.bottom
        property string dropEdge: ""
        property int dropIndex: -1

        Repeater {
            model: root.decks

            Item {
                id: deck
                required property var modelData
                readonly property string deckKey: modelData.key
                readonly property var row: DesktopWidgetService.entryOf(deck.deckKey)
                readonly property string edge: deck.row?.edge ?? "right"
                readonly property real along: DeckService.alongOf(deck.row)
                readonly property var wanted: DeckService.deckNotes(deck.row)
                readonly property int count: deck.noteKeys.length
                readonly property real start: root.startOf(deck.edge, deck.count, deck.along)
                readonly property bool selected: DesktopWidgetService.selected === deck.deckKey
                readonly property bool receiving: board.dropEdge === deck.edge
                    || (DeckService.receiving === deck.edge && DeckService.receivingScreen === root.screenName)
                property var noteKeys: []
                anchors.fill: parent

                function syncNotes(): void {
                    const next = deck.wanted
                    if (next.length === deck.noteKeys.length
                            && next.every((key, index) => key === deck.noteKeys[index]))
                        return
                    deck.noteKeys = next
                }

                onWantedChanged: deck.syncNotes()
                Component.onCompleted: deck.syncNotes()

                Rectangle {
                    x: deck.edge === "right" ? board.width - 3 : 0
                    y: deck.edge === "bottom" ? board.height - 3 : 0
                    width: deck.edge === "bottom" ? board.width : 3
                    height: deck.edge === "bottom" ? 3 : board.height
                    color: Impasto.Theme.accent
                    opacity: deck.receiving ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: Impasto.Theme.durationFast } }
                }

                Rectangle {
                    id: grip
                    readonly property var box: DeckService.gripBox(
                        deck.edge, deck.start, board.width, board.height)
                    x: grip.box.x
                    y: grip.box.y
                    width: DeckService.grip
                    height: DeckService.grip
                    radius: width / 2
                    color: Impasto.Theme.island
                    border.color: slide.active ? Impasto.Theme.accent : Impasto.Theme.islandBorder
                    border.width: slide.active ? 2 : 1
                    visible: opacity > 0
                    opacity: root.editing ? 1 : 0
                    z: 2

                    Behavior on opacity {
                        NumberAnimation { duration: Impasto.Theme.durationFast }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: deck.edge === "bottom" ? "󰡏" : "󰡎"
                        font.family: Impasto.Theme.fontMono
                        font.pixelSize: 12
                        color: Impasto.Theme.scrimText
                    }

                    HoverHandler {
                        cursorShape: deck.edge === "bottom" ? Qt.SizeHorCursor : Qt.SizeVerCursor
                    }
                    TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds }
                    PointHandler {
                        id: gripHold
                        acceptedButtons: Qt.LeftButton
                        onActiveChanged: {
                            if (gripHold.active) {
                                DeckService.held = deck.deckKey
                                DeckService.heldScreen = root.screenName
                            } else if (DeckService.held === deck.deckKey
                                    && DeckService.heldScreen === root.screenName) {
                                DeckService.held = ""
                                DeckService.heldScreen = ""
                            }
                        }
                    }
                    Component.onDestruction: {
                        if (DeckService.held === deck.deckKey
                                && DeckService.heldScreen === root.screenName) {
                            DeckService.held = ""
                            DeckService.heldScreen = ""
                        }
                        if (DeckService.sliding === deck.deckKey
                                && DeckService.slidingScreen === root.screenName) {
                            DeckService.sliding = ""
                            DeckService.slidingScreen = ""
                        }
                    }
                    DragHandler {
                        id: slide
                        enabled: root.editing
                        target: null
                        onActiveChanged: {
                            if (slide.active) {
                                DesktopWidgetService.selected = ""
                                DeckService.sliding = deck.deckKey
                                DeckService.slidingScreen = root.screenName
                            } else if (DeckService.sliding === deck.deckKey
                                    && DeckService.slidingScreen === root.screenName) {
                                DeckService.sliding = ""
                                DeckService.slidingScreen = ""
                                if (DeckService.held === deck.deckKey
                                        && DeckService.heldScreen === root.screenName) {
                                    DeckService.held = ""
                                    DeckService.heldScreen = ""
                                }
                            }
                        }
                        onCentroidChanged: {
                            if (!slide.active)
                                return
                            const point = board.mapFromItem(null,
                                slide.centroid.scenePosition.x, slide.centroid.scenePosition.y)
                            const start = (deck.edge === "bottom" ? point.x : point.y)
                                + DeckService.grip / 2 + DeckService.tabGap / 2
                            DeckService.setDeckAlong(deck.deckKey, DeckService.alongAt(
                                deck.edge, deck.count, start, board.width, board.height, root.screenName))
                        }
                    }
                }

                Repeater {
                    model: deck.noteKeys
                    delegate: Item {
                        id: tab
                        required property string modelData
                        required property int index
                        readonly property string noteKey: tab.modelData
                        readonly property var note: ImpastoServices.NotesService.entry(tab.noteKey)
                        readonly property color paper: ImpastoServices.NotesService.paperOf(
                            tab.note ? tab.note.tint : "yellow")
                        readonly property bool held: DeckService.draggingScreen === root.screenName
                            && DeckService.dragging === tab.noteKey
                        readonly property bool peeking: DeckService.peekedScreen === root.screenName
                            && DeckService.peeked === tab.noteKey
                        readonly property int shown: {
                            if (DeckService.draggingScreen !== root.screenName
                                    || DeckService.dragging === "" || tab.held || board.dropEdge !== deck.edge)
                                return tab.index
                            const from = deck.noteKeys.indexOf(DeckService.dragging)
                            let at = tab.index
                            if (from >= 0 && from < tab.index)
                                at -= 1
                            if (board.dropIndex <= at)
                                at += 1
                            return at
                        }
                        readonly property var box: DeckService.tabBox(
                            deck.edge, tab.shown, deck.start, root.depth, board.width, board.height)

                        x: tab.box.x
                        y: tab.box.y
                        width: tab.box.width
                        height: tab.box.height
                        opacity: tab.held ? 0.3 : 1
                        z: tab.peeking ? 1 : 0

                        Behavior on x {
                            enabled: DeckService.draggingScreen === root.screenName
                            NumberAnimation {
                                duration: Impasto.Theme.durationFast
                                easing.type: Impasto.Theme.easing
                            }
                        }
                        Behavior on y {
                            enabled: DeckService.draggingScreen === root.screenName
                            NumberAnimation {
                                duration: Impasto.Theme.durationFast
                                easing.type: Impasto.Theme.easing
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: tab.paper
                            topLeftRadius: deck.edge === "left" ? 0 : Impasto.Theme.radiusSmall
                            bottomLeftRadius: deck.edge === "left" || deck.edge === "bottom"
                                ? 0 : Impasto.Theme.radiusSmall
                            topRightRadius: deck.edge === "right" ? 0 : Impasto.Theme.radiusSmall
                            bottomRightRadius: deck.edge === "right" || deck.edge === "bottom"
                                ? 0 : Impasto.Theme.radiusSmall
                            border.color: Impasto.Theme.accent
                            border.width: root.editing && deck.selected ? 2 : 0
                        }

                        Text {
                            anchors.centerIn: parent
                            width: DeckService.tabLength - 16
                            rotation: deck.edge === "right" ? 90 : (deck.edge === "left" ? -90 : 0)
                            text: tab.note ? ImpastoServices.NotesService.titleOf(tab.note).toUpperCase() : ""
                            color: Impasto.Theme.paperInk
                            opacity: root.reveal
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Impasto.Theme.fontFamily
                            font.pixelSize: Impasto.Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1
                        }

                        HoverHandler {
                            cursorShape: root.editing
                                ? (tab.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                                : Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered && !root.editing) {
                                    root.retract.stop()
                                    DeckService.peeked = tab.noteKey
                                    DeckService.peekedScreen = root.screenName
                                }
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                if (root.editing)
                                    DesktopWidgetService.selected = deck.selected ? "" : deck.deckKey
                                else
                                    root.openNote(tab.noteKey, deck.row)
                            }
                        }
                        TapHandler {
                            enabled: !root.editing
                            acceptedButtons: Qt.RightButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: eventPoint => {
                                const point = board.mapFromItem(null,
                                    eventPoint.scenePosition.x, eventPoint.scenePosition.y)
                                root.menu = {
                                    note: tab.noteKey, deck: deck.deckKey, row: deck.row,
                                    x: point.x, y: point.y
                                }
                            }
                        }
                        PointHandler {
                            id: tabHold
                            enabled: root.editing
                            acceptedButtons: Qt.LeftButton
                            onActiveChanged: {
                                if (tabHold.active) {
                                    DeckService.held = tab.noteKey
                                    DeckService.heldScreen = root.screenName
                                } else if (DeckService.held === tab.noteKey
                                        && DeckService.heldScreen === root.screenName) {
                                    DeckService.held = ""
                                    DeckService.heldScreen = ""
                                }
                            }
                        }
                        Component.onDestruction: {
                            if (DeckService.held === tab.noteKey
                                    && DeckService.heldScreen === root.screenName) {
                                DeckService.held = ""
                                DeckService.heldScreen = ""
                            }
                            if (DeckService.dragging === tab.noteKey
                                    && DeckService.draggingScreen === root.screenName) {
                                DeckService.dragging = ""
                                DeckService.draggingScreen = ""
                            }
                        }
                        DragHandler {
                            id: pull
                            enabled: root.editing
                            target: null
                            onActiveChanged: {
                                if (pull.active) {
                                    DeckService.dragging = tab.noteKey
                                    DeckService.draggingScreen = root.screenName
                                    DeckService.peeked = ""
                                    DeckService.peekedScreen = ""
                                    DesktopWidgetService.selected = ""
                                    root.aim(pull.centroid.scenePosition)
                                    return
                                }
                                root.drop(tab.noteKey, pull.centroid.scenePosition)
                            }
                            onCentroidChanged: if (pull.active) root.aim(pull.centroid.scenePosition)
                        }
                    }
                }
            }
        }

        Repeater {
            model: ["left", "right", "bottom"].filter(
                edge => !root.decks.some(deck => deck.edge === edge))
            Rectangle {
                required property string modelData
                x: modelData === "right" ? board.width - 3 : 0
                y: modelData === "bottom" ? board.height - 3 : 0
                width: modelData === "bottom" ? board.width : 3
                height: modelData === "bottom" ? 3 : board.height
                color: Impasto.Theme.accent
                opacity: (DeckService.receiving === modelData
                    && DeckService.receivingScreen === root.screenName)
                    || board.dropEdge === modelData ? 1 : 0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: Impasto.Theme.durationFast } }
            }
        }
    }

    Item {
        id: peek
        parent: board
        readonly property bool showing: root.peekedNote !== null && !root.editing
        property string key: ""
        property var box: null
        readonly property string live: DeckService.peekedScreen === root.screenName ? DeckService.peeked : ""

        onLiveChanged: {
            if (peek.live !== "") {
                peek.key = peek.live
                peek.box = root.boxFor(peek.live)
            }
        }

        x: peek.box ? peek.box.x : 0
        y: peek.box ? peek.box.y : 0
        width: DeckService.peekWidth
        height: DeckService.peekHeight
        visible: opacity > 0
        opacity: peek.showing ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Impasto.Theme.durationFast
                easing.type: Impasto.Theme.easing
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowOpacity: 0.5
            shadowVerticalOffset: 3
            shadowColor: Impasto.Theme.island
        }

        Sticky {
            anchors.fill: parent
            note: ImpastoServices.NotesService.entry(peek.key)
            padding: 14
            titleSize: Impasto.Theme.fontSizeRegular
            bodySize: 17
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: if (hovered) root.retract.stop()
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.openNote(peek.key, DesktopWidgetService.entryOf(
                root.decks.find(deck => deck.notes.some(note => note.key === peek.key))?.key ?? ""))
        }
    }

    Item {
        id: ghost
        parent: board
        readonly property var note: DeckService.draggingScreen === root.screenName
            ? ImpastoServices.NotesService.entry(DeckService.dragging) : null
        z: 10
        visible: DeckService.draggingScreen === root.screenName && DeckService.dragging !== ""
        width: 72
        height: 72
        opacity: 0.94

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowOpacity: 0.5
            shadowVerticalOffset: 3
            shadowColor: Impasto.Theme.island
        }

        Sticky {
            anchors.fill: parent
            note: ghost.note
            padding: 8
            titleSize: Impasto.Theme.fontSizeLabel
            bodySize: 11
            showAge: false
        }
    }
    Loader {
        parent: board
        active: root.menu !== null
        x: root.menu ? Math.max(Impasto.Theme.desktopGutter,
            Math.min(board.width - Impasto.Theme.desktopGutter - width, root.menu.x)) : 0
        y: root.menu ? Math.max(Impasto.Theme.desktopGutter,
            Math.min(board.height - Impasto.Theme.desktopGutter - height, root.menu.y)) : 0
        z: 20

        sourceComponent: PopMenu {
            rows: [
                { id: "open", label: "Open", icon: "󰏫", warn: false },
                { id: "edit", label: "Edit", icon: "󰆾", warn: false }
            ]
            onChosen: id => {
                const chosenMenu = root.menu
                root.menu = null
                if (!chosenMenu)
                    return
                if (id === "open")
                    root.openNote(chosenMenu.note, chosenMenu.row)
                else if (id === "edit" && DesktopWidgetService.openEditor(root.screenName))
                    DesktopWidgetService.selected = chosenMenu.deck
            }
        }
    }

    HoverHandler {
        id: pointerOn
        onHoveredChanged: {
            if (pointerOn.hovered) {
                root.retract.stop()
                DeckService.revealed = true
                DeckService.revealedScreen = root.screenName
            } else {
                root.retract.restart()
            }
        }
    }

    Component.onCompleted: DeckService.publish(root.screenName, root)
    Component.onDestruction: {
        DeckService.publish(root.screenName, null)
        root.clearScreenState()
    }
    onEditingChanged: root.clearScreenState()

    function closeMenu(): void {
        root.menu = null
    }

    function clearScreenState(): void {
        if (DeckService.heldScreen === root.screenName) {
            DeckService.held = ""
            DeckService.heldScreen = ""
        }
        if (DeckService.draggingScreen === root.screenName) {
            DeckService.dragging = ""
            DeckService.draggingScreen = ""
        }
        if (DeckService.slidingScreen === root.screenName) {
            DeckService.sliding = ""
            DeckService.slidingScreen = ""
        }
        if (DeckService.peekedScreen === root.screenName) {
            DeckService.peeked = ""
            DeckService.peekedScreen = ""
        }
        if (DeckService.revealedScreen === root.screenName) {
            DeckService.revealed = false
            DeckService.revealedScreen = ""
        }
        if (DeckService.receivingScreen === root.screenName) {
            DeckService.receiving = ""
            DeckService.receivingScreen = ""
        }
        if (DesktopWidgetService.landing?.screen === root.screenName)
            DesktopWidgetService.landing = null
        root.menu = null
    }

    function startOf(edge: string, count: int, along: real): real {
        return DeckService.startOf(edge, count, along, board.width, board.height, root.screenName)
    }

    function boxFor(key: string): var {
        for (const deck of root.decks) {
            const index = deck.notes.findIndex(note => note.key === key)
            if (index >= 0)
                return DeckService.peekBox(deck.edge, index,
                    root.startOf(deck.edge, deck.notes.length, deck.along), board.width, board.height)
        }
        return null
    }

    function openNote(key: string, deckRow: var): void {
        const note = ImpastoServices.NotesService.entry(key)
        if (!note || !deckRow)
            return
        DeckService.peeked = ""
        DeckService.peekedScreen = ""
        if (DeckService.revealedScreen === root.screenName) {
            DeckService.revealed = false
            DeckService.revealedScreen = ""
        }
        ImpastoServices.NotesService.open(key, deckRow)
        ImpastoServices.ModuleService.requestPanel("notes", deckRow)
    }

    function aim(scene: point): void {
        const point = board.mapFromItem(null, scene.x, scene.y)
        ghost.x = point.x - ghost.width / 2
        ghost.y = point.y - ghost.height / 2
        if (DesktopWidgetService.overGallery(root.screenName, point.x, point.y)) {
            board.dropEdge = ""
            board.dropIndex = -1
            DesktopWidgetService.landing = null
            DeckService.receiving = ""
            DeckService.receivingScreen = ""
            return
        }
        const edge = DeckService.edgeAt(point.x, point.y, board.width, board.height)
        if (edge !== "") {
            const deck = root.decks.find(item => item.edge === edge)
            board.dropEdge = edge
            board.dropIndex = deck
                ? DeckService.indexAt(edge, point.x, point.y, deck.notes.length,
                    root.startOf(deck.edge, deck.notes.length, deck.along)) : 0
            DeckService.receiving = edge
            DeckService.receivingScreen = root.screenName
            DesktopWidgetService.landing = null
            return
        }
        board.dropEdge = ""
        board.dropIndex = -1
        DeckService.receiving = ""
        DeckService.receivingScreen = ""
        const face = DesktopWidgetService.sizeFor("2x2", root.screenName)
        const spot = DesktopWidgetService.nearestFree(root.screenName,
            DesktopWidgetService.cellX(root.screenName, point.x - face.width / 2),
            DesktopWidgetService.cellY(root.screenName, point.y - face.height / 2), "2x2", "")
        DesktopWidgetService.landing = spot
            ? { screen: root.screenName, col: spot.col, row: spot.row, family: "2x2" } : null
    }

    function drop(key: string, scene: point): void {
        const point = board.mapFromItem(null, scene.x, scene.y)
        const edge = board.dropEdge
        const index = board.dropIndex
        const overGallery = DesktopWidgetService.overGallery(root.screenName, point.x, point.y)
        DeckService.dragging = ""
        DeckService.draggingScreen = ""
        if (DeckService.heldScreen === root.screenName) {
            DeckService.held = ""
            DeckService.heldScreen = ""
        }
        board.dropEdge = ""
        board.dropIndex = -1
        DesktopWidgetService.landing = null
        DeckService.receiving = ""
        DeckService.receivingScreen = ""
        if (overGallery) {
            DeckService.removeNote(key)
            return
        }
        if (edge !== "") {
            DeckService.placeNote(key, root.screenName, edge, index)
            return
        }
        const face = DesktopWidgetService.sizeFor("2x2", root.screenName)
        DeckService.noteToGrid(key, root.screenName,
            DesktopWidgetService.cellX(root.screenName, point.x - face.width / 2),
            DesktopWidgetService.cellY(root.screenName, point.y - face.height / 2))
    }
}