pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.services
import qs.modules.services.desktop

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    readonly property string screenName: root.targetScreen?.name ?? ""
    readonly property bool editing: DesktopWidgetService.editing
    readonly property var edgeRows: DesktopWidgetService.widgets.filter(row =>
        row.id === "spectrum" && DesktopWidgetService.isEdge(row)
            && DesktopWidgetService.nameOf(row) === root.screenName)
    readonly property bool away: DeckService.spectrumAwayOn(root.screenName)

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    screen: root.targetScreen
    visible: !Config.desktop.hidden && (root.editing || !root.away)
        && (root.edgeRows.length > 0 || root.editing)

    WlrLayershell.namespace: "nonchalant:desktop:spectrum-edges"
    WlrLayershell.layer: root.editing ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    mask: Region {
        regions: root.editing ? root.interactiveRegions : []
    }

    readonly property var interactiveRegions: {
        const regions = []
        for (let index = 0; index < handles.count; index++) {
            const region = handles.objectAt(index)
            if (region)
                regions.push(region)
        }
        return regions
    }

    Item {
        id: board
        anchors.fill: parent
        readonly property var insets: DesktopWidgetService.insetsFor(root.screenName)
        anchors.topMargin: insets.top
        anchors.leftMargin: insets.left
        anchors.rightMargin: insets.right
        anchors.bottomMargin: insets.bottom
    }

    Instantiator {
        id: handles
        model: root.edgeRows

        delegate: Region {
            required property var modelData
            readonly property var box: DeckService.spectrumBox(
                root.screenName, modelData, board.width, board.height)
            x: board.x + box.x
            y: board.y + box.y
            width: box.width
            height: box.height
        }
    }

    Repeater {
        model: root.edgeRows

        SpectrumEdgeStrip {
            required property var modelData
            board: board
            screenName: root.screenName
            editing: root.editing
            row: modelData
            listening: root.visible && !root.away
        }
    }
}