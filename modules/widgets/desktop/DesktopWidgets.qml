import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.desktop.details
import qs.modules.widgets.desktop.edges
import qs.modules.widgets.desktop.impasto.theme as Impasto

PanelWindow {
    id: root

    required property ShellScreen targetScreen

    readonly property string screenName: targetScreen?.name ?? ""
    readonly property bool editing: DesktopWidgetService.editing
    readonly property bool ownsKeyboard: editing && DesktopWidgetService.editingScreen === screenName
    readonly property var boardInsets: DesktopWidgetService.insetsFor(screenName)

    screen: targetScreen
    visible: DesktopWidgetService.isVisibleOn(screenName)
    color: "transparent"

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "nonchalant:desktop"
    WlrLayershell.layer: editing ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: ownsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    mask: Region {
        item: root.visible ? fullInput : null
    }

    Item {
        id: fullInput
        anchors.fill: parent

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: eventPoint => {
                if (root.editing) {
                    DesktopWidgetService.closeEditor()
                } else {
                    const point = surface.mapFromItem(null,
                        eventPoint.scenePosition.x, eventPoint.scenePosition.y)
                    DesktopWidgetService.openMenu("", root.screenName, point.x, point.y)
                }
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
                DesktopWidgetService.closeMenu()
                if (root.editing)
                    DesktopWidgetService.selected = ""
            }
        }
    }

    FocusScope {
        id: surface

        anchors.fill: parent
        anchors.topMargin: root.boardInsets.top
        anchors.rightMargin: root.boardInsets.right
        anchors.bottomMargin: root.boardInsets.bottom
        anchors.leftMargin: root.boardInsets.left
        focus: root.ownsKeyboard

        onWidthChanged: DesktopWidgetService.setBoard(root.screenName, width, height)
        onHeightChanged: DesktopWidgetService.setBoard(root.screenName, width, height)
        Component.onCompleted: DesktopWidgetService.setBoard(root.screenName, width, height)

        Keys.onEscapePressed: DesktopWidgetService.closeEditor()

        HoverHandler {
            enabled: root.editing && !DesktopWidgetService.inHand
            onHoveredChanged: {
                if (hovered)
                    DesktopWidgetService.galleryScreen = root.screenName
            }
        }

        Repeater {
            model: root.editing
                ? DesktopWidgetService.columnsOn(root.screenName) * DesktopWidgetService.rowsOn(root.screenName)
                : 0

            StyledRect {
                required property int index

                readonly property int columns: DesktopWidgetService.columnsOn(root.screenName)
                readonly property int column: index % columns
                readonly property int row: Math.floor(index / columns)

                variant: "transparent"
                x: DesktopWidgetService.offsetX(root.screenName, column)
                y: DesktopWidgetService.offsetY(root.screenName, row)
                width: DesktopWidgetService.offsetX(root.screenName, column + 1)
                    - DesktopWidgetService.gutter - x
                height: DesktopWidgetService.offsetY(root.screenName, row + 1)
                    - DesktopWidgetService.gutter - y
                radius: Impasto.Theme.radiusSmall
                backgroundOpacity: 0
                border.color: Impasto.Theme.hairline
                border.width: 1
            }
        }

        StyledRect {
            id: landing

            readonly property var spot: DesktopWidgetService.landing
                && DesktopWidgetService.landing.screen === root.screenName
                ? DesktopWidgetService.landing : null
            property bool showing: false

            visible: root.editing && landing.showing
            variant: "transparent"
            backgroundOpacity: 1
            clip: false
            animateRadius: false
            radius: Impasto.Theme.desktopRadius
            color: Qt.rgba(Impasto.Theme.accent.r, Impasto.Theme.accent.g, Impasto.Theme.accent.b, 0.14)
            border.color: Impasto.Theme.accent
            border.width: 2

            onSpotChanged: {
                const shape = landing.spot ? DesktopWidgetService.family(landing.spot.family) : null
                if (!landing.spot || !shape) {
                    landing.showing = false
                    return
                }
                const name = root.screenName
                const x = DesktopWidgetService.offsetX(name, landing.spot.col)
                const y = DesktopWidgetService.offsetY(name, landing.spot.row)
                slide.enabled = landing.showing
                landing.x = x
                landing.y = y
                landing.width = DesktopWidgetService.offsetX(name, landing.spot.col + shape.cols)
                    - Impasto.Theme.desktopGutter - x
                landing.height = DesktopWidgetService.offsetY(name, landing.spot.row + shape.rows)
                    - Impasto.Theme.desktopGutter - y
                slide.enabled = true
                landing.showing = true
            }

            Behavior on x { id: slide; NumberAnimation { duration: Impasto.Theme.durationFast; easing.type: Impasto.Theme.easing } }
            Behavior on y { enabled: slide.enabled; NumberAnimation { duration: Impasto.Theme.durationFast; easing.type: Impasto.Theme.easing } }
            Behavior on width { enabled: slide.enabled; NumberAnimation { duration: Impasto.Theme.durationFast; easing.type: Impasto.Theme.easing } }
            Behavior on height { enabled: slide.enabled; NumberAnimation { duration: Impasto.Theme.durationFast; easing.type: Impasto.Theme.easing } }
        }

        Item {
            id: widgetField
            anchors.fill: parent
            visible: DesktopWidgetService.isVisibleOn(root.screenName)

            Repeater {
                model: DesktopWidgetService.keysOn(root.screenName)

                DesktopWidget {
                    required property string modelData

                    board: surface
                    screenName: root.screenName
                    key: modelData
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: root.editing && DesktopWidgetService.galleryScreen === root.screenName
            sourceComponent: WidgetGallery { board: surface; screen: root.targetScreen }
            z: 1
        }

        Loader {
            anchors.fill: parent
            active: root.editing && DesktopWidgetService.picking === ""
                && DesktopWidgetService.entryOf(DesktopWidgetService.selected) !== null
                && DesktopWidgetService.nameOf(DesktopWidgetService.entryOf(DesktopWidgetService.selected))
                    === root.screenName
            sourceComponent: WidgetInspector { board: surface }
            z: 5
        }

        Loader {
            anchors.fill: parent
            active: root.editing
                && DesktopWidgetService.entryOf(DesktopWidgetService.picking) !== null
                && DesktopWidgetService.nameOf(DesktopWidgetService.entryOf(DesktopWidgetService.picking))
                    === root.screenName
            sourceComponent: WidgetPicturePicker { board: surface }
            z: 5
        }
    }

    EdgeWidgets {
        screen: root.targetScreen
    }
    WidgetContextMenu {
        targetScreen: root.targetScreen
        board: surface
    }


    PanelWindow {
        id: detailWindow

        screen: root.targetScreen
        visible: DesktopWidgetService.detailModuleId !== ""
            && DesktopWidgetService.detailScreen === root.screenName
            && !root.editing && !DesktopWidgetService.isFullscreen(root.screenName)
            && !NiriService.overviewOpen
        color: "transparent"

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        WlrLayershell.namespace: "nonchalant:desktop-details"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        mask: Region {
            item: detailWindow.visible ? detailInput : null
        }

        FocusScope {
            id: detailInput

            anchors.fill: parent
            focus: detailWindow.visible

            Keys.onEscapePressed: DesktopWidgetService.closeDetail()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: DesktopWidgetService.closeDetail()
            }

            WidgetDetails {
                id: details

                readonly property real safeMargin: Math.min(Styling.fontSize(0) * 2,
                    Math.min(detailInput.width, detailInput.height) / 4)

                screen: root.targetScreen
                moduleId: DesktopWidgetService.detailModuleId
                row: DesktopWidgetService.detailRow
                    ?? DesktopWidgetService.entryOf(DesktopWidgetService.detailKey)
                width: Math.max(1, Math.min(implicitWidth, detailInput.width - safeMargin * 2))
                height: Math.max(1, Math.min(implicitHeight, detailInput.height - safeMargin * 2))
                anchors.centerIn: parent
                focus: detailWindow.visible
                z: 1
                onCloseRequested: DesktopWidgetService.closeDetail()
            }
        }
    }

    Connections {
        target: detailWindow.visible ? detailWindow.contentItem.Window : null

        function onActiveChanged(): void {
            if (detailWindow.contentItem.Window.active)
                return
            const grabId = DesktopWidgetService.detailGrabId
            Qt.callLater(() => {
                if (detailWindow.visible && DesktopWidgetService.detailGrabId === grabId
                        && !detailWindow.contentItem.Window.active)
                    DesktopWidgetService.closeDetail()
            })
        }
    }

    Connections {
        target: root.editing && root.ownsKeyboard ? root.contentItem.Window : null

        function onActiveChanged(): void {
            if (root.contentItem.Window.active)
                return
            const grabId = DesktopWidgetService.editorGrabId
            Qt.callLater(() => {
                if (root.editing && root.ownsKeyboard
                        && DesktopWidgetService.editorGrabId === grabId
                        && !root.contentItem.Window.active)
                    DesktopWidgetService.closeEditor()
            })
        }
    }

    onVisibleChanged: {
        if (!visible && DesktopWidgetService.editingScreen === screenName)
            DesktopWidgetService.closeEditor()
    }
}
