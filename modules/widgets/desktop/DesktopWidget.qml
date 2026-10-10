import QtQuick
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme

Item {
    id: root

    required property Item board
    required property string screenName
    required property string key

    readonly property var row: DesktopWidgetService.entryOf(key)
    readonly property string moduleId: row?.id ?? ""
    readonly property string family: DesktopWidgetService.familyOf(row)
    readonly property string theme: DesktopWidgetService.themeOf(row)
    readonly property var ink: DesktopWidgetService.inkFor(row)
    readonly property var box: DesktopWidgetService.geometry(row ?? ({}), board.width, board.height)
    readonly property bool editing: DesktopWidgetService.editing
    readonly property bool held: DesktopWidgetService.dragging === key
    readonly property bool selected: DesktopWidgetService.selected === key
    readonly property bool bare: moduleId === "notes" || moduleId === "photo"
        || moduleId === "spectrum" || theme === "sticker"
    readonly property bool faceActive: visible

    property var resizeBox: null

    function clearReceiving(): void {
        if (DeckService.receivingScreen === root.screenName) {
            DeckService.receiving = ""
            DeckService.receivingScreen = ""
        }
    }

    function aim(scene: point): void {
        const pointer = root.board.mapFromItem(null, scene.x, scene.y)
        root.x = pointer.x - root.width / 2
        root.y = pointer.y - root.height / 2
        if (DesktopWidgetService.overGallery(root.screenName, pointer.x, pointer.y)) {
            DesktopWidgetService.landing = null
            root.clearReceiving()
            return
        }

        const edge = root.moduleId === "notes" || root.moduleId === "spectrum"
            ? DeckService.edgeAt(pointer.x, pointer.y, root.board.width, root.board.height)
            : ""
        if (edge !== "") {
            DesktopWidgetService.landing = null
            root.clearReceiving()
            if (root.moduleId === "notes") {
                DeckService.receiving = edge
                DeckService.receivingScreen = root.screenName
            }
            return
        }

        root.clearReceiving()
        const spot = DesktopWidgetService.nearestFree(root.screenName,
            DesktopWidgetService.cellX(root.screenName, root.x),
            DesktopWidgetService.cellY(root.screenName, root.y), root.family, root.key)
        DesktopWidgetService.landing = spot
            ? { screen: root.screenName, col: spot.col, row: spot.row, family: root.family }
            : null
    }

    opacity: root.moduleId === "spectrum" ? 1 : DesktopWidgetService.opacityOf(root.row) / 100
    width: box.width
    height: box.height
    visible: box.valid && DesktopWidgetService.isVisibleOn(screenName)
    z: held ? 10 : (selected ? 8 : 4)

    Binding {
        target: root
        property: "x"
        value: root.box.x
        when: !move.active
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: root
        property: "y"
        value: root.box.y
        when: !move.active
        restoreMode: Binding.RestoreBindingOrValue
    }

    Behavior on x {
        enabled: !move.active
        NumberAnimation { duration: Config.animDuration > 0 ? Config.animDuration : 0 }
    }
    Behavior on y {
        enabled: !move.active
        NumberAnimation { duration: Config.animDuration > 0 ? Config.animDuration : 0 }
    }
    Behavior on width {
        NumberAnimation { duration: Config.animDuration > 0 ? Config.animDuration : 0 }
    }
    Behavior on height {
        NumberAnimation { duration: Config.animDuration > 0 ? Config.animDuration : 0 }
    }

    WidgetShadow {
        visible: !root.bare
    }

    StyledRect {
        anchors.fill: parent
        visible: !root.bare
        variant: DesktopWidgetService.styleOf(root.row) === "glass" ? "pane" : "common"
        backgroundOpacity: 1
        radius: Styling.radius(4)
        border.color: root.selected ? Colors.primary : root.ink.border
        border.width: root.selected ? 2 : 1
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: !root.editing
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            if (root.moduleId === "photo")
                DesktopWidgetService.openPicture(root.row)
            else
                DesktopWidgetService.openDetail(root.moduleId, root.row)
        }
    }

    Face {
        anchors.fill: parent
        moduleId: root.moduleId
        family: root.family
        theme: root.theme
        ink: root.ink
        row: root.row
        active: root.faceActive
    }

    StyledRect {
        anchors.fill: parent
        visible: root.editing && root.selected
        variant: "focus"
        backgroundOpacity: 0
        border.color: Colors.primary
        border.width: 2
        radius: Styling.radius(4)
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: root.editing
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: DesktopWidgetService.selected = root.selected ? "" : root.key
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            if (!root.editing)
                DesktopWidgetService.openEditor(root.screenName)
            DesktopWidgetService.selected = root.key
        }
    }

    Item {
        width: root.width - (root.selected ? resizeHandle.width / 2 : 0)
        height: root.height - (root.selected ? resizeHandle.height / 2 : 0)

        DragHandler {
            id: move
            enabled: root.editing
            target: null

            onActiveChanged: {
                if (active) {
                    DesktopWidgetService.beginWidgetDrag(root.key)
                    root.aim(centroid.scenePosition)
                    return
                }
                if (!root.editing || DesktopWidgetService.dragging !== root.key) {
                    root.clearReceiving()
                    return
                }

                const pointer = root.board.mapFromItem(null,
                    centroid.scenePosition.x, centroid.scenePosition.y)
                if (DesktopWidgetService.overGallery(root.screenName, pointer.x, pointer.y)) {
                    DesktopWidgetService.remove(root.key)
                } else {
                    const edge = root.moduleId === "notes" || root.moduleId === "spectrum"
                        ? DeckService.edgeAt(pointer.x, pointer.y, root.board.width, root.board.height)
                        : ""
                    if (edge !== "" && root.moduleId === "notes") {
                        DeckService.noteToEdge(root.key, root.screenName, edge)
                    } else if (edge !== "" && root.moduleId === "spectrum"
                            && DeckService.spectrumTakes(root.screenName, edge)) {
                        DeckService.spectrumToEdge(root.key, root.screenName, edge)
                    } else {
                        const landing = DesktopWidgetService.landing
                        if (landing && landing.screen === root.screenName)
                            DesktopWidgetService.place(root.key, landing.screen, landing.col, landing.row)
                    }
                }
                root.clearReceiving()
                DesktopWidgetService.endWidgetDrag()
            }

            onCentroidChanged: if (active) root.aim(centroid.scenePosition)
        }
    }

    WheelHandler {
        enabled: root.editing
        onWheel: event => {
            DesktopWidgetService.cycleFamily(root.key, event.angleDelta.y > 0 ? 1 : -1)
            event.accepted = true
        }
    }

    HoverHandler {
        cursorShape: root.editing ? (move.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
    }

    StyledRect {
        id: resizeHandle

        visible: root.editing && root.selected
        width: 24
        height: 24
        x: root.width - width / 2
        y: root.height - height / 2
        variant: "primary"
        radius: Styling.radius(4)
        z: 2

        Text {
            anchors.centerIn: parent
            text: "↘"
            font.family: Config.defaultFont
            font.pixelSize: Styling.fontSize(12)
            color: Colors.overPrimary
        }

        DragHandler {
            id: resize
            target: null

            onActiveChanged: {
                if (active) {
                    DesktopWidgetService.selected = root.key
                    root.resizeBox = DesktopWidgetService.geometry(root.row, root.board.width, root.board.height)
                    DesktopWidgetService.inHand = true
                } else {
                    DesktopWidgetService.inHand = false
                    root.resizeBox = null
                }
            }

            onCentroidChanged: {
                if (!active || !root.resizeBox)
                    return
                const pointer = root.board.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y)
                const grid = DesktopWidgetService.gridOn(root.screenName)
                const cols = Math.max(1, (pointer.x - root.resizeBox.x + DesktopWidgetService.gutter) / grid.stride)
                const rows = Math.max(1, (pointer.y - root.resizeBox.y + DesktopWidgetService.gutter) / grid.stride)
                const family = DesktopWidgetService.familyNearest(root.moduleId, cols, rows, root.theme)
                if (family !== "")
                    DesktopWidgetService.setFamily(root.key, family)
            }
        }
    }
}
