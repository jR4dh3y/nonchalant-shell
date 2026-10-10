import QtQuick
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme

Item {
    id: root

    required property Item board
    required property ShellScreen screen

    readonly property string screenName: screen?.name ?? ""
    readonly property var defaultSize: DesktopWidgetService.gallerySizeOn(screenName, width, height)
    readonly property var defaultPosition: DesktopWidgetService.galleryAtOn(screenName, width, height)
    property string pulling: ""
    property real ghostX: 0
    property real ghostY: 0
    property string edgeTarget: ""

    anchors.fill: board

    onVisibleChanged: {
        if (visible) {
            root.publishDropTarget()
        } else if (root.pulling !== "") {
            root.clearReceiving()
            root.edgeTarget = ""
            DesktopWidgetService.endGalleryDrag()
            root.pulling = ""
        }
    }

    function familyFor(id: string): string {
        return DesktopWidgetService.familiesFor(id)[0] ?? "4x2"
    }

    function publishDropTarget(): void {
        if (root.visible)
            DesktopWidgetService.setGalleryBox(
                root.screenName, card.x, card.y, card.width, card.height)
    }

    function clearReceiving(): void {
        if (DeckService.receivingScreen === root.screenName) {
            DeckService.receiving = ""
            DeckService.receivingScreen = ""
        }
    }


    function aim(id: string, sceneX: real, sceneY: real): void {
        const pointer = root.board.mapFromItem(null, sceneX, sceneY)
        const familyId = root.familyFor(id)
        const size = DesktopWidgetService.sizeFor(familyId, root.screenName)
        root.ghostX = pointer.x - size.width / 2
        root.ghostY = pointer.y - size.height / 2
        if (DesktopWidgetService.overGallery(root.screenName, pointer.x, pointer.y)) {
            root.edgeTarget = ""
            DesktopWidgetService.landing = null
            root.clearReceiving()
            return
        }

        const edge = DeckService.edgeAt(pointer.x, pointer.y, root.board.width, root.board.height)
        if ((id === "notes" || id === "spectrum") && edge !== "") {
            root.edgeTarget = id === "notes" || DeckService.spectrumTakes(root.screenName, edge)
                ? edge : ""
            DesktopWidgetService.landing = null
            root.clearReceiving()
            if (id === "notes" && root.edgeTarget !== "") {
                DeckService.receiving = edge
                DeckService.receivingScreen = root.screenName
            }
            return
        }

        root.edgeTarget = ""
        root.clearReceiving()
        const spot = DesktopWidgetService.nearestFree(root.screenName,
            DesktopWidgetService.cellX(root.screenName, root.ghostX),
            DesktopWidgetService.cellY(root.screenName, root.ghostY), familyId)
        DesktopWidgetService.landing = spot
            ? { screen: root.screenName, col: spot.col, row: spot.row, family: familyId }
            : null
    }

    StyledRect {
        id: card
        x: root.defaultPosition.x
        y: root.defaultPosition.y

        width: Math.min(root.defaultSize.width,
            Math.max(1, root.width - DesktopWidgetService.gutter * 2))
        height: Math.min(root.defaultSize.height,
            Math.max(1, root.height - DesktopWidgetService.gutter * 2))
        variant: "popup"
        backgroundOpacity: 0.96
        radius: Styling.radius(8)
        border.color: Colors.outlineVariant
        border.width: 1
        clip: true
        z: 10

        onXChanged: root.publishDropTarget()
        onYChanged: root.publishDropTarget()
        onWidthChanged: root.publishDropTarget()
        onHeightChanged: root.publishDropTarget()
        Component.onCompleted: root.publishDropTarget()

        Item {
            id: titleBar

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "Widgets"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(2)
                font.weight: Font.DemiBold
                color: Colors.overBackground
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 42
                anchors.verticalCenter: parent.verticalCenter
                text: `${DesktopWidgetService.catalogue.length} available`
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.outline
            }

            DragHandler {
                id: moveGallery
                target: null
                property point startOffset: Qt.point(0, 0)
                onActiveChanged: {
                    if (active) {
                        const pointer = root.board.mapFromItem(null,
                            centroid.scenePosition.x, centroid.scenePosition.y)
                        startOffset = Qt.point(pointer.x - card.x, pointer.y - card.y)
                        DesktopWidgetService.inHand = true
                    } else {
                        DesktopWidgetService.inHand = false
                        if (DesktopWidgetService.editing && root.visible)
                            DesktopWidgetService.setGalleryAt(root.screenName, card.x, card.y)
                    }
                }

                onCentroidChanged: {
                    if (!active || !root.visible || !DesktopWidgetService.editing)
                        return
                    const pointer = root.board.mapFromItem(null,
                        centroid.scenePosition.x, centroid.scenePosition.y)
                    card.x = Math.max(0, Math.min(Math.max(0, root.width - card.width),
                        pointer.x - moveGallery.startOffset.x))
                    card.y = Math.max(0, Math.min(Math.max(0, root.height - card.height),
                        pointer.y - moveGallery.startOffset.y))
                    DesktopWidgetService.setGalleryAt(root.screenName, card.x, card.y)
                }
            }

            HoverHandler { cursorShape: moveGallery.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
        }

        Row {
            id: edgeActions

            anchors.top: titleBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: 34
            spacing: 6

            StyledRect {
                id: addDeckAction
                width: (edgeActions.width - edgeActions.spacing) / 2
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                enabled: DeckService.freeDeckEdge(root.screenName) !== ""
                variant: enabled ? "common" : "transparent"
                backgroundOpacity: enabled ? 0.84 : 0.2
                radius: Styling.radius(4)
                border.color: Colors.outlineVariant
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Note deck"
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overBackground
                    opacity: addDeckAction.enabled ? 1 : 0.5
                }

                TapHandler {
                    enabled: addDeckAction.enabled
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: DeckService.addDeck(
                        root.screenName, DeckService.freeDeckEdge(root.screenName))
                }
            }

            StyledRect {
                id: addSpectrumAction
                width: (edgeActions.width - edgeActions.spacing) / 2
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                enabled: DeckService.freeSpectrumEdge(root.screenName) !== ""
                variant: enabled ? "common" : "transparent"
                backgroundOpacity: enabled ? 0.84 : 0.2
                radius: Styling.radius(4)
                border.color: Colors.outlineVariant
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Spectrum edge"
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overBackground
                    opacity: addSpectrumAction.enabled ? 1 : 0.5
                }

                TapHandler {
                    enabled: addSpectrumAction.enabled
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: DeckService.addSpectrum(root.screenName)
                }
            }
        }
        GridView {
            id: catalogGrid

            anchors.top: edgeActions.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            anchors.topMargin: 4
            clip: true
            cellWidth: Math.max(112, Math.min(158, width / 3))
            cellHeight: 110
            model: DesktopWidgetService.catalogue

            delegate: Item {
                id: tile

                required property var modelData

                readonly property string moduleId: modelData.id
                readonly property string familyId: root.familyFor(moduleId)
                property bool hovered: false

                width: catalogGrid.cellWidth - 6
                height: catalogGrid.cellHeight - 6

                StyledRect {
                    anchors.fill: parent
                    variant: tile.hovered ? "focus" : "common"
                    backgroundOpacity: 0.84
                    radius: Styling.radius(4)
                    border.color: tile.hovered ? Colors.primary : Colors.outlineVariant
                    border.width: 1
                }

                Item {
                    id: preview
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    height: 62
                    readonly property var dimensions: DesktopWidgetService.families.find(family => family.id === tile.familyId)

                    Face {
                        anchors.centerIn: parent
                        width: (preview.dimensions?.cols ?? 2) * DesktopWidgetService.stride - DesktopWidgetService.gutter
                        height: (preview.dimensions?.rows ?? 2) * DesktopWidgetService.stride - DesktopWidgetService.gutter
                        scale: Math.min(preview.width / width, preview.height / height)
                        moduleId: tile.moduleId
                        family: tile.familyId
                        theme: DesktopWidgetService.configuredTheme()
                        ink: DesktopWidgetService.inkFor(null)
                        row: null
                        active: false
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.bottomMargin: 7
                    text: tile.modelData.name
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(-1)
                    color: tile.hovered ? Colors.overBackground : Colors.outline
                }

                HoverHandler {
                    cursorShape: tile.hovered ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onHoveredChanged: tile.hovered = hovered
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: DesktopWidgetService.add(tile.moduleId, root.screenName)
                }

                DragHandler {
                    id: pull
                    target: null

                    onActiveChanged: {
                        if (active) {
                            root.pulling = tile.moduleId
                            DesktopWidgetService.beginGalleryDrag(tile.moduleId)
                            root.aim(tile.moduleId, centroid.scenePosition.x, centroid.scenePosition.y)
                            return
                        }

                        if (root.pulling !== tile.moduleId)
                            return

                        if (!root.visible || !DesktopWidgetService.editing) {
                            root.clearReceiving()
                            root.edgeTarget = ""
                            DesktopWidgetService.endGalleryDrag()
                            root.pulling = ""
                            return
                        }

                        root.aim(tile.moduleId, centroid.scenePosition.x, centroid.scenePosition.y)
                        const edge = root.edgeTarget
                        const landing = DesktopWidgetService.landing
                        if (edge !== "" && tile.moduleId === "notes") {
                            DeckService.addDeck(root.screenName, edge)
                        } else if (edge !== "" && tile.moduleId === "spectrum") {
                            DeckService.addSpectrum(root.screenName, edge)
                        } else if (landing && landing.screen === root.screenName) {
                            DesktopWidgetService.add(
                                tile.moduleId, landing.screen, landing.col, landing.row)
                        }
                        root.clearReceiving()
                        root.edgeTarget = ""
                        DesktopWidgetService.endGalleryDrag()
                        root.pulling = ""
                    }

                    onCentroidChanged: {
                        if (active && root.pulling === tile.moduleId && root.visible
                                && DesktopWidgetService.editing)
                            root.aim(tile.moduleId, centroid.scenePosition.x, centroid.scenePosition.y)
                    }
                }
            }
        }

        StyledRect {
            id: resizeGrip

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 24
            height: 24
            variant: "focus"
            backgroundOpacity: 0.75
            radius: Styling.radius(3)
            z: 2

            Text {
                anchors.centerIn: parent
                text: "↘"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(10)
                color: Colors.overBackground
            }

            DragHandler {
                id: resizeGallery
                target: null
                property real startWidth: card.width
                property real startHeight: card.height
                property point startPointer: Qt.point(0, 0)

                onActiveChanged: {
                    if (active) {
                        startWidth = card.width
                        startHeight = card.height
                        startPointer = centroid.scenePosition
                        DesktopWidgetService.inHand = true
                    } else {
                        DesktopWidgetService.inHand = false
                        if (DesktopWidgetService.editing && root.visible) {
                            DesktopWidgetService.setGallerySize(root.screenName, card.width, card.height)
                            DesktopWidgetService.setGalleryAt(root.screenName, card.x, card.y)
                        }
                    }
                }

                onCentroidChanged: {
                    if (!active || !root.visible || !DesktopWidgetService.editing)
                        return
                    const deltaX = centroid.scenePosition.x - resizeGallery.startPointer.x
                    const deltaY = centroid.scenePosition.y - resizeGallery.startPointer.y
                    const availableWidth = Math.max(1, root.width - card.x)
                    const availableHeight = Math.max(1, root.height - card.y)
                    card.width = Math.max(Math.min(180, availableWidth),
                        Math.min(availableWidth, resizeGallery.startWidth + deltaX))
                    card.height = Math.max(Math.min(190, availableHeight),
                        Math.min(availableHeight, resizeGallery.startHeight + deltaY))
                }
            }
        }
    }

    Item {
        id: ghost

        readonly property string familyId: root.familyFor(root.pulling)
        readonly property var size: DesktopWidgetService.sizeFor(familyId, root.screenName)

        parent: root.board
        visible: DesktopWidgetService.draggingModuleId !== ""
            && DesktopWidgetService.draggingModuleId === root.pulling
        x: root.ghostX
        y: root.ghostY
        width: size.width
        height: size.height
        opacity: 0.88
        z: 100

        StyledRect {
            anchors.fill: parent
            variant: "primary"
            backgroundOpacity: 0.18
            radius: Styling.radius(4)
            border.color: Colors.primary
            border.width: 2
        }

        Face {
            anchors.fill: parent
            moduleId: root.pulling
            family: ghost.familyId
            theme: DesktopWidgetService.configuredTheme()
            ink: DesktopWidgetService.inkFor(null)
            row: null
            active: false
        }
    }
}
