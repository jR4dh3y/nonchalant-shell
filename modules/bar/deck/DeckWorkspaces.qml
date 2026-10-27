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
                    objectName: "deckWorkspace-" + modelData
                    width: root.unit
                    height: root.unit
                    padding: 0
                    label: String(workspace?.idx ?? "")
                    labelAlignment: Text.AlignHCenter
                    selected: workspace?.active ?? false
                    description: (workspace?.isNamed ? workspace.name : "Workspace " + (workspace?.idx ?? ""))
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
                                radius: width / 2
                                variant: "focus"
                                color: tab.ink
                                opacity: tab.selected ? 0.9 : 0.6
                                enableBorder: false
                            }
                        }
                    }
                    StyledRect {
                        visible: tab.workspace?.is_urgent ?? false
                        variant: "focus"
                        color: Colors.red
                        enableBorder: false
                        width: Styling.fontSize(0) * 0.3
                        height: width
                        radius: width / 2
                        anchors.right: parent.right
                        anchors.top: parent.top
                    }
                }
            }
        }
    }
}
