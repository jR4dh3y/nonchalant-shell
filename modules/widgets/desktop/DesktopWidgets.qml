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
            onTapped: {
                if (root.editing)
                    DesktopWidgetService.closeEditor()
                else
                    DesktopWidgetService.openEditor(root.screenName)
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            enabled: root.editing
            onTapped: DesktopWidgetService.selected = ""
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
                radius: Styling.radius(2)
                backgroundOpacity: 0
                border.color: Colors.outlineVariant
                border.width: 1
            }
        }

        StyledRect {
            readonly property var landing: DesktopWidgetService.landing
                && DesktopWidgetService.landing.screen === root.screenName
                ? DesktopWidgetService.landing : null
            readonly property var shape: landing
                ? DesktopWidgetService.family(landing.family) : null

            visible: root.editing && landing !== null && shape !== null
            variant: "focus"
            x: visible ? DesktopWidgetService.offsetX(root.screenName, landing.col) : 0
            y: visible ? DesktopWidgetService.offsetY(root.screenName, landing.row) : 0
            width: visible
                ? DesktopWidgetService.offsetX(root.screenName, landing.col + shape.cols)
                    - DesktopWidgetService.gutter - x
                : 0
            height: visible
                ? DesktopWidgetService.offsetY(root.screenName, landing.row + shape.rows)
                    - DesktopWidgetService.gutter - y
                : 0
            backgroundOpacity: 0.16
            border.color: Colors.primary
            border.width: 2
            radius: Styling.radius(4)
            z: 2
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
                    z: held ? 10 : (selected ? 8 : 4)
                }
            }
        }

        WidgetGallery {
            anchors.fill: parent
            board: surface
            screen: root.targetScreen
            visible: root.editing && DesktopWidgetService.galleryScreen === root.screenName
            z: 12
        }

        WidgetInspector {
            anchors.fill: parent
            board: surface
            visible: root.editing && DesktopWidgetService.selected !== ""
                && DesktopWidgetService.nameOf(DesktopWidgetService.entryOf(DesktopWidgetService.selected)) === root.screenName
            z: 20
        }
    }

    EdgeWidgets {
        screen: root.targetScreen
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
