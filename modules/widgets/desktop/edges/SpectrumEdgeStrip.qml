pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components
import qs.modules.services.desktop
import qs.modules.theme

Item {
    id: root

    required property Item board
    required property string screenName
    required property var row
    required property bool editing
    required property bool listening

    readonly property string edge: root.row?.edge ?? "bottom"
    readonly property bool selected: DesktopWidgetService.selected === root.row.key
    readonly property var box: DeckService.spectrumBox(
        root.screenName, root.row, root.board.width, root.board.height)

    x: root.board.x + root.box.x
    y: root.board.y + root.box.y
    width: root.box.width
    height: root.box.height
    z: root.editing ? 10 : 0

    StyledRect {
        anchors.fill: parent
        visible: root.editing
        variant: root.selected ? "focus" : "common"
        opacity: 0.35
    }

    SpectrumBars {
        anchors.fill: parent
        edge: root.edge
        row: root.row
        listening: root.listening
    }

    TapHandler {
        enabled: root.editing
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: DesktopWidgetService.selected = root.selected ? "" : root.row.key
    }

    DragHandler {
        id: carry
        enabled: root.editing
        target: null

        onActiveChanged: {
            if (carry.active) {
                DesktopWidgetService.beginWidgetDrag(root.row.key)
                root.aim(carry.centroid.scenePosition)
                return
            }
            root.drop(carry.centroid.scenePosition)
        }
        onCentroidChanged: if (carry.active) root.aim(carry.centroid.scenePosition)
    }

    Component.onDestruction: {
        if (DesktopWidgetService.dragging === root.row.key) {
            DeckService.receiving = ""
            DeckService.receivingScreen = ""
            DesktopWidgetService.endWidgetDrag()
        }
    }

    function aim(scene: point): void {
        const point = root.board.mapFromItem(null, scene.x, scene.y)
        if (DesktopWidgetService.overGallery(root.screenName, point.x, point.y)) {
            DesktopWidgetService.landing = null
            DeckService.receiving = ""
            DeckService.receivingScreen = ""
            return
        }

        const edge = DeckService.edgeAt(point.x, point.y, root.board.width, root.board.height)
        if (edge !== "") {
            if (DeckService.spectrumTakes(root.screenName, edge)) {
                DeckService.receiving = edge
                DeckService.receivingScreen = root.screenName
            } else {
                DeckService.receiving = ""
                DeckService.receivingScreen = ""
            }
            DesktopWidgetService.landing = null
            return
        }


        DeckService.receiving = ""
        DeckService.receivingScreen = ""
        const family = DesktopWidgetService.familiesFor("spectrum")[0] ?? "4x2"
        const size = DesktopWidgetService.sizeFor(family, root.screenName)
        const spot = DesktopWidgetService.nearestFree(root.screenName,
            DesktopWidgetService.cellX(root.screenName, point.x - size.width / 2),
            DesktopWidgetService.cellY(root.screenName, point.y - size.height / 2), family, root.row.key)
        DesktopWidgetService.landing = spot
            ? { screen: root.screenName, col: spot.col, row: spot.row, family: family } : null
    }

    function drop(scene: point): void {
        const point = root.board.mapFromItem(null, scene.x, scene.y)
        const edge = DeckService.receivingScreen === root.screenName
            ? DeckService.receiving : ""
        const landing = DesktopWidgetService.landing?.screen === root.screenName
            ? DesktopWidgetService.landing : null
        const overGallery = DesktopWidgetService.overGallery(root.screenName, point.x, point.y)

        if (overGallery) {
            DesktopWidgetService.remove(root.row.key)
        } else if (edge !== "") {
            if (DesktopWidgetService.isEdge(root.row))
                DeckService.setSpectrumEdge(root.row.key, root.screenName, edge)
            else
                DeckService.spectrumToEdge(root.row.key, root.screenName, edge)
        } else if (landing) {
            if (DesktopWidgetService.isEdge(root.row))
                DeckService.spectrumToGrid(root.row.key, root.screenName, landing.col, landing.row)
            else
                DesktopWidgetService.place(root.row.key, root.screenName, landing.col, landing.row)
        }

        DeckService.receiving = ""
        DeckService.receivingScreen = ""
        DesktopWidgetService.endWidgetDrag()
    }
}