import QtQuick
import Quickshell
import QtQuick.Effects
import qs.modules.components
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.widgets.desktop.impasto.components
import qs.modules.widgets.desktop.impasto.services
import qs.modules.widgets.desktop.impasto.theme

Item {
    id: root

    required property Item board
    required property string screenName
    required property string key

    readonly property var row: DesktopWidgetService.entryOf(root.key)
    readonly property string moduleId: root.row?.id ?? ""
    readonly property string family: DesktopWidgetService.familyOf(root.row)
    readonly property string theme: DesktopWidgetService.themeOf(root.row)
    readonly property var ink: DesktopWidgetService.inkFor(root.row)
    readonly property real solidity: DesktopWidgetService.opacityOf(root.row) / 100
    readonly property color rim: Qt.rgba(root.ink.border.r, root.ink.border.g,
        root.ink.border.b, root.ink.border.a * Math.min(1, root.solidity * 5))
    readonly property bool onPicture: DesktopWidgetService.bare(root.row)
    readonly property bool sticker: root.theme === "sticker"
        && root.moduleId !== "notes" && root.moduleId !== "spectrum"
    readonly property var box: DesktopWidgetService.geometry(
        root.row ?? ({}), root.board.width, root.board.height)
    readonly property bool editing: DesktopWidgetService.editing
    readonly property bool held: DesktopWidgetService.dragging === root.key
    readonly property bool selected: DesktopWidgetService.selected === root.key
    readonly property bool hovered: hover.hovered
    readonly property bool faceActive: root.visible && root.width > 0 && root.height > 0
        && (root.moduleId === "spectrum" || root.solidity > 0)
    readonly property string wantedWatch: root.moduleId !== "" && root.faceActive ? root.moduleId : ""

    property string watching: ""
    property real wheelSpent: 0

    function rewatch(): void {
        const next = root.wantedWatch
        if (next === root.watching)
            return
        if (root.watching !== "")
            ModuleService.watch(root.watching, false)
        root.watching = next
        if (root.watching !== "")
            ModuleService.watch(root.watching, true)
    }

    function clearReceiving(): void {
        if (DeckService.receivingScreen === root.screenName) {
            DeckService.receiving = ""
            DeckService.receivingScreen = ""
        }
    }

    function aim(scene: point): void {
        const pointer = root.board.mapFromItem(null, scene.x, scene.y)
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

    onWantedWatchChanged: root.rewatch()

    Component.onCompleted: root.rewatch()
    Component.onDestruction: {
        if (root.watching !== "")
            ModuleService.watch(root.watching, false)
    }

    width: root.box.width
    height: root.box.height
    visible: root.row !== null && root.box.valid
        && DesktopWidgetService.isVisibleOn(root.screenName)
    z: root.held ? 2 : (root.selected ? 1 : 0)

    Binding {
        target: root
        property: "x"
        value: root.box.x
        when: !drag.active
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: root
        property: "y"
        value: root.box.y
        when: !drag.active
        restoreMode: Binding.RestoreBindingOrValue
    }

    Behavior on x {
        enabled: !drag.active
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Behavior on y {
        enabled: !drag.active
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Behavior on width {
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Behavior on height {
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Item {
        id: cast

        readonly property int reach: Theme.shadowRange + 4
        readonly property bool cut: !Theme.deskSolid || root.solidity < 1

        visible: SettingsService.widgetShadow && !root.onPicture
            && (!Theme.deskSolid || root.solidity > 0)
        x: -cast.reach
        y: -cast.reach
        width: root.width + 2 * cast.reach
        height: root.height + 2 * cast.reach

        layer.enabled: cast.visible && cast.cut
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: cutout
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Item {
            anchors.fill: parent
            opacity: Theme.shadowOpacity

            layer.enabled: cast.visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: Theme.shadowRange - Theme.shadowSpread
            }

            Rectangle {
                x: cast.reach - Theme.shadowSpread
                y: cast.reach - Theme.shadowSpread
                width: root.width + 2 * Theme.shadowSpread
                height: root.height + 2 * Theme.shadowSpread
                radius: Theme.desktopRadius + Theme.shadowSpread
                color: Theme.shadowColor
            }
        }

        Item {
            id: cutout

            anchors.fill: parent
            visible: false
            layer.enabled: cast.cut

            Rectangle {
                x: cast.reach
                y: cast.reach
                width: root.width
                height: root.height
                radius: Theme.desktopRadius
            }
        }
    }

    Item {
        id: body

        readonly property int reach: Theme.shadowRange

        anchors.fill: parent
        anchors.margins: -reach
        layer.enabled: root.sticker ? SettingsService.widgetShadow
            : root.onPicture && root.moduleId !== "spectrum"
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            blurMax: root.sticker ? Theme.shadowRange : 32
            shadowOpacity: root.sticker ? Theme.shadowOpacity : 0.6
            shadowVerticalOffset: root.sticker ? Theme.shadowSpread : 2
            shadowColor: Theme.island
        }

        Item {
            x: body.reach
            y: body.reach
            width: root.width
            height: root.height

            StyledRect {
                id: capsule

                anchors.fill: parent
                visible: !root.onPicture
                clip: false
                backgroundOpacity: 1
                variant: "transparent"
                animateRadius: false
                radius: Theme.desktopRadius
                color: Theme.deskSolid
                    ? Qt.rgba(root.ink.ground.r, root.ink.ground.g, root.ink.ground.b,
                        root.solidity)
                    : Theme.groundOf(Theme.deskStyle)
                border.color: Theme.deskSolid ? root.rim : Theme.rimOf(Theme.deskStyle)
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: Theme.durationMedium }
                }
            }

            GlassSheen {
                shape: capsule
                visible: Theme.deskGlass && !root.onPicture
            }

            Face {
                anchors.fill: parent
                moduleId: root.moduleId
                family: root.family
                theme: root.theme
                ink: root.ink
                row: root.row
                active: root.faceActive
                enabled: !root.editing
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        visible: root.editing
        radius: Theme.desktopRadius + 3
        color: "transparent"
        border.color: root.held || root.selected ? Theme.accent : Theme.hairline
        border.width: root.held || root.selected ? 2 : 1
    }

    TapHandler {
        enabled: !root.editing && root.row !== null
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: eventPoint => {
            const point = root.board.mapFromItem(null,
                eventPoint.scenePosition.x, eventPoint.scenePosition.y)
            DesktopWidgetService.openMenu(root.key, root.screenName, point.x, point.y)
        }
    }

    TapHandler {
        enabled: root.editing && root.row !== null
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: DesktopWidgetService.selected = root.selected ? "" : root.key
    }

    DragHandler {
        id: drag

        enabled: root.editing && root.row !== null
        target: root

        onActiveChanged: {
            if (drag.active) {
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
                } else if (edge === "") {
                    const landing = DesktopWidgetService.landing
                    if (landing && landing.screen === root.screenName)
                        DesktopWidgetService.place(root.key, landing.screen, landing.col, landing.row)
                }
            }
            root.clearReceiving()
            DesktopWidgetService.endWidgetDrag()
        }

    }

    onXChanged: if (drag.active) root.aim(drag.centroid.scenePosition)
    onYChanged: if (drag.active) root.aim(drag.centroid.scenePosition)

    WheelHandler {
        enabled: root.editing && root.row !== null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (wheelRest.running)
                return
            root.wheelSpent += event.angleDelta.y
            if (Math.abs(root.wheelSpent) < 120)
                return
            const step = root.wheelSpent < 0 ? 1 : -1
            root.wheelSpent = 0
            DesktopWidgetService.cycleFamily(root.key, step)
            wheelRest.restart()
        }
    }

    Timer {
        id: wheelRest
        interval: 250
        onTriggered: root.wheelSpent = 0
    }

    HoverHandler {
        id: hover

        enabled: root.editing
        cursorShape: root.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    readonly property bool dressed: root.editing && !root.held
        && (root.hovered || root.selected)

    Rectangle {
        id: badge

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: -8
        anchors.topMargin: -8
        width: 24
        height: 24
        radius: 12
        color: Theme.island
        border.color: Theme.borderIn(QsWindow.window)
        border.width: 1
        visible: opacity > 0
        opacity: root.dressed ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 2
            radius: 1
            color: Theme.scrimText
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        TapHandler {
            enabled: root.row !== null
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: DesktopWidgetService.remove(root.key)
        }
    }

    Rectangle {
        id: handle

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -8
        anchors.bottomMargin: -8
        width: 24
        height: 24
        radius: 12
        color: Theme.island
        border.color: resize.active ? Theme.accent : Theme.borderIn(QsWindow.window)
        border.width: resize.active ? 2 : 1
        visible: opacity > 0
        opacity: root.dressed || resize.active ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast }
        }

        Item {
            anchors.centerIn: parent
            width: 10
            height: 10

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 10
                height: 2
                radius: 1
                color: Theme.scrimText
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 2
                height: 10
                radius: 1
                color: Theme.scrimText
            }
        }

        HoverHandler { cursorShape: Qt.SizeFDiagCursor }

        TapHandler {
            enabled: root.row !== null
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

        DragHandler {
            id: resize

            enabled: root.editing && root.row !== null
            target: null

            onActiveChanged: DesktopWidgetService.inHand = active

            onCentroidChanged: {
                if (!resize.active)
                    return
                const pointer = root.board.mapFromItem(null,
                    resize.centroid.scenePosition.x, resize.centroid.scenePosition.y)
                const grid = DesktopWidgetService.gridOn(root.screenName)
                const cols = (pointer.x - root.box.x + Theme.desktopGutter) / grid.stride
                const rows = (pointer.y - root.box.y + Theme.desktopGutter) / grid.stride
                const next = DesktopWidgetService.familyNearest(
                    root.moduleId, cols, rows, root.theme)
                if (next !== "" && next !== root.family)
                    DesktopWidgetService.setFamily(root.key, next)
            }
        }
    }
}
