pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.widgets.desktop as DesktopWidgets
import qs.modules.widgets.desktop.impasto.components as ImpastoComponents
import qs.modules.widgets.desktop.impasto.services as ImpastoServices
import qs.modules.widgets.desktop.impasto.theme as ImpastoTheme
import qs.modules.services as CoreWidgets
import qs.modules.services.desktop as CoreDesktop

Item {
    id: root

    required property Item board
    required property string screenName
    required property var row
    required property bool editing
    required property bool listening

    readonly property string edge: root.row?.edge ?? "bottom"
    readonly property bool selected: CoreWidgets.DesktopWidgetService.selected === root.row.key
    readonly property var looks: ImpastoServices.DesktopService.spectrumOf(root.row)
    readonly property bool held: carry.active
    readonly property var box: CoreDesktop.DeckService.spectrumBox(
        root.screenName, root.row, root.board.width, root.board.height)

    x: root.board.x + root.box.x
    y: root.board.y + root.box.y
    width: root.box.width
    height: root.box.height
    z: root.editing ? 10 : 0

    Rectangle {
        anchors.fill: parent
        visible: root.editing
        radius: ImpastoTheme.Theme.radiusSmall
        color: Qt.alpha(ImpastoTheme.Theme.accent, root.selected ? 0.16 : 0.08)
        border.color: root.selected ? ImpastoTheme.Theme.accent : ImpastoTheme.Theme.hairline
        border.width: root.selected ? 2 : 1
        opacity: root.held ? 0.4 : 1
    }

    ImpastoComponents.SpectrumBars {
        anchors.fill: parent
        edge: root.edge
        style: root.looks.look
        fillStyle: root.looks.fill
        color: root.looks.color
        color2: root.looks.color2
        barWidth: root.looks.bar
        gap: root.looks.gap
        lowsAt: root.looks.lows
        peaks: root.looks.peaks
        listening: root.listening
        visible: listening
        opacity: root.looks.opacity / 100 * (root.held ? 0.4 : 1)
    }

    TapHandler {
        enabled: root.editing
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: CoreWidgets.DesktopWidgetService.selected = root.selected ? "" : root.row.key
    }

    DragHandler {
        id: carry
        enabled: root.editing
        target: null

        onActiveChanged: {
            if (carry.active) {
                CoreWidgets.DesktopWidgetService.beginWidgetDrag(root.row.key)
                root.aim(carry.centroid.scenePosition)
                return
            }
            root.drop(carry.centroid.scenePosition)
        }
        onCentroidChanged: if (carry.active) root.aim(carry.centroid.scenePosition)
    }
    Loader {
        id: hand

        readonly property var size: CoreWidgets.DesktopWidgetService.sizeFor("4x2", root.screenName)

        parent: root.board
        z: 10
        active: root.held
        width: hand.size.width
        height: hand.size.height
        opacity: 0.9

        sourceComponent: Rectangle {
            radius: ImpastoTheme.Theme.desktopRadius
            color: ImpastoTheme.Theme.island
            border.color: ImpastoTheme.Theme.accent
            border.width: 2

            DesktopWidgets.Face {
                anchors.fill: parent
                moduleId: "spectrum"
                family: "4x2"
                row: root.row
                ink: ImpastoServices.DesktopService.inkFor(null)
                active: root.listening
                enabled: false
            }
        }

    }

    Component.onDestruction: {
        if (CoreWidgets.DesktopWidgetService.dragging === root.row.key) {
            CoreDesktop.DeckService.receiving = ""
            CoreDesktop.DeckService.receivingScreen = ""
            CoreWidgets.DesktopWidgetService.endWidgetDrag()
        }
    }

    function aim(scene: point): void {
        const point = root.board.mapFromItem(null, scene.x, scene.y)
        hand.x = point.x - hand.width / 2
        hand.y = point.y - hand.height / 2
        if (CoreWidgets.DesktopWidgetService.overGallery(root.screenName, point.x, point.y)) {
            CoreWidgets.DesktopWidgetService.landing = null
            CoreDesktop.DeckService.receiving = ""
            CoreDesktop.DeckService.receivingScreen = ""
            return
        }

        const edge = CoreDesktop.DeckService.edgeAt(point.x, point.y, root.board.width, root.board.height)
        if (edge !== "") {
            if (CoreDesktop.DeckService.spectrumTakes(root.screenName, edge)) {
                CoreDesktop.DeckService.receiving = edge
                CoreDesktop.DeckService.receivingScreen = root.screenName
            } else {
                CoreDesktop.DeckService.receiving = ""
                CoreDesktop.DeckService.receivingScreen = ""
            }
            CoreWidgets.DesktopWidgetService.landing = null
            return
        }

        CoreDesktop.DeckService.receiving = ""
        CoreDesktop.DeckService.receivingScreen = ""
        const family = CoreWidgets.DesktopWidgetService.familiesFor("spectrum")[0] ?? "4x2"
        const size = CoreWidgets.DesktopWidgetService.sizeFor(family, root.screenName)
        const spot = CoreWidgets.DesktopWidgetService.nearestFree(root.screenName,
            CoreWidgets.DesktopWidgetService.cellX(root.screenName, point.x - size.width / 2),
            CoreWidgets.DesktopWidgetService.cellY(root.screenName, point.y - size.height / 2), family, root.row.key)
        CoreWidgets.DesktopWidgetService.landing = spot
            ? { screen: root.screenName, col: spot.col, row: spot.row, family: family } : null
    }

    function drop(scene: point): void {
        const point = root.board.mapFromItem(null, scene.x, scene.y)
        const edge = CoreDesktop.DeckService.receivingScreen === root.screenName
            ? CoreDesktop.DeckService.receiving : ""
        const landing = CoreWidgets.DesktopWidgetService.landing?.screen === root.screenName
            ? CoreWidgets.DesktopWidgetService.landing : null
        const overGallery = CoreWidgets.DesktopWidgetService.overGallery(root.screenName, point.x, point.y)

        if (overGallery) {
            CoreWidgets.DesktopWidgetService.remove(root.row.key)
        } else if (edge !== "") {
            if (CoreWidgets.DesktopWidgetService.isEdge(root.row))
                CoreDesktop.DeckService.setSpectrumEdge(root.row.key, root.screenName, edge)
            else
                CoreDesktop.DeckService.spectrumToEdge(root.row.key, root.screenName, edge)
        } else if (landing) {
            if (CoreWidgets.DesktopWidgetService.isEdge(root.row))
                CoreDesktop.DeckService.spectrumToGrid(root.row.key, root.screenName, landing.col, landing.row)
            else
                CoreWidgets.DesktopWidgetService.place(root.row.key, root.screenName, landing.col, landing.row)
        }

        CoreDesktop.DeckService.receiving = ""
        CoreDesktop.DeckService.receivingScreen = ""
        CoreWidgets.DesktopWidgetService.endWidgetDrag()
    }
}