pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.compositor
import qs.modules.theme

Item {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)
    required property ShellScreen screen
    property bool compact: false
    readonly property list<CompositorWorkspace> workspaces: CompositorService.workspacesForOutput(screen.name)
    readonly property string order: JSON.stringify(workspaces.map(workspace => workspace.id))
    property list<string> ids: []
    readonly property int activeIndex: workspaces.findIndex(workspace => workspace.active)
    readonly property real unit: Styling.fontSize(0) * 2
    implicitWidth: Math.min(strip.implicitWidth, unit * 9)
    implicitHeight: unit
    onOrderChanged: ids = workspaces.map(workspace => workspace.id)
    Component.onCompleted: ids = workspaces.map(workspace => workspace.id)

    function followActive(): void {
        Qt.callLater(() => {
            const item = repeater.itemAt(Math.max(0, root.activeIndex));
            if (!item) return;
            const left = item.x;
            const right = left + item.width;
            viewport.contentX = Math.max(0, Math.min(
                left < viewport.contentX ? left : Math.max(viewport.contentX, right - viewport.width),
                Math.max(0, viewport.contentWidth - viewport.width)));
        });
    }
    onActiveIndexChanged: followActive()
    onCompactChanged: followActive()

    Flickable {
        id: viewport
        anchors.fill: parent
        clip: true
        contentWidth: strip.implicitWidth
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        onWidthChanged: root.followActive()
        onContentWidthChanged: root.followActive()
        Row {
            id: strip
            spacing: Styling.fontSize(0) * 0.2
            Repeater {
                id: repeater
                model: root.ids
                DeckAction {
                    id: tab
                    required property string modelData
                    readonly property CompositorWorkspace workspace: CompositorService.workspaceById(modelData)
                    readonly property int windowCount: CompositorService.windowsForWorkspace(modelData).length
                    readonly property bool urgent: workspace?.is_urgent ?? false
                    readonly property string number: String(workspace?.idx ?? "")
                    readonly property string displayName: workspace?.isNamed ? workspace.name : number
                    objectName: "deckWorkspace-" + modelData
                    width: selected && windowCount === 0 ? Math.max(root.unit, implicitWidth + Styling.fontSize(0) / 2) : root.unit
                    height: root.unit
                    padding: 0
                    label: selected ? (windowCount > 0 ? "" : displayName) : number
                    labelAlignment: Text.AlignHCenter
                    selected: workspace?.active ?? false
                    accent: true
                    ink: Styling.workspaceLabelColor(selected, windowCount > 0, urgent, root.shellPalette)
                    description: (workspace?.isNamed ? displayName : "Workspace " + number)
                        + " · " + windowCount + (windowCount === 1 ? " window" : " windows") + " · Scroll to switch"
                    onClicked: DeckActions.focusWorkspace(modelData)
                    wheelEnabled: true
                    onScrolled: delta => {
                        if (delta !== 0) DeckActions.adjacentWorkspace(root.screen.name, delta < 0 ? 1 : -1);
                    }
                    // Occupancy pips: one per window, up to four, read at a glance without text.
                    Row {
                        objectName: tab.objectName + "-pips"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Math.max(2, Styling.fontSize(0) * 0.18)
                        spacing: Math.max(1, Styling.fontSize(0) * 0.14)
                        Repeater {
                            model: Math.min(tab.windowCount, 4)
                            StyledRect {
                                width: Math.max(2, Styling.fontSize(0) * 0.22)
                                height: width
                                radius: Styling.pillRadius(width)
                                variant: "focus"
                                color: tab.selected ? Styling.srItem("primary", root.shellPalette) : root.shellPalette.secondary
                                opacity: tab.selected ? 0.9 : 0.6
                                enableBorder: false
                            }
                        }
                    }
                    StyledRect {
                        visible: tab.urgent
                        variant: "focus"
                        color: root.shellPalette.danger
                        enableBorder: false
                        width: Styling.fontSize(0) * 0.3
                        height: width
                        radius: Styling.pillRadius(width)
                        anchors.right: parent.right
                        anchors.top: parent.top
                    }
                }
            }
        }
    }
}
