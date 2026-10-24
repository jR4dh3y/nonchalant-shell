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
    readonly property string workspaceId: CompositorService.activeWorkspaceForOutput(screen.name)?.id ?? ""
    readonly property list<CompositorWindow> windows: CompositorService.windowsForWorkspace(workspaceId)
    readonly property string order: JSON.stringify(windows.map(window => window.id))
    property list<string> ids: []
    readonly property int focusedIndex: windows.findIndex(window => window.is_focused)
    readonly property real unit: Styling.fontSize(0) * 2
    readonly property real tabWidth: compact ? unit : Math.max(unit, Math.min(unit * 5.2, width / Math.max(1, Math.min(ids.length, 4))))
    signal windowsRequested()
    implicitHeight: unit
    onOrderChanged: ids = windows.map(window => window.id)
    Component.onCompleted: ids = windows.map(window => window.id)

    function followFocus(): void {
        Qt.callLater(() => {
            const left = Math.max(0, root.focusedIndex) * (root.tabWidth + tabs.spacing);
            viewport.contentX = Math.max(0, Math.min(
                left < viewport.contentX ? left : Math.max(viewport.contentX, left + root.tabWidth - viewport.width),
                Math.max(0, viewport.contentWidth - viewport.width)));
        });
    }
    onFocusedIndexChanged: followFocus()
    onTabWidthChanged: followFocus()

    Flickable {
        id: viewport
        anchors.fill: parent
        visible: root.ids.length > 0
        clip: true
        contentWidth: tabs.implicitWidth
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        onWidthChanged: root.followFocus()
        Row {
            id: tabs
            spacing: Styling.fontSize(0) * 0.25
            Repeater {
                model: root.ids
                DeckAction {
                    id: tab
                    required property string modelData
                    readonly property CompositorWindow windowData: CompositorService.windowById(modelData)
                    readonly property string iconName: DesktopEntries.heuristicLookup(windowData?.appId ?? "")?.icon
                        || AppSearch.guessIcon(windowData?.appId ?? "") || "application-x-executable"
                    objectName: "deckTask-" + modelData
                    width: root.tabWidth
                    height: root.unit
                    imageSource: "image://icon/" + iconName
                    textElide: Text.ElideMiddle
                    label: root.compact ? "" : (windowData?.title || windowData?.appId || "Window")
                    selected: windowData?.is_focused ?? false
                    description: (windowData?.title || windowData?.appId || "Window") + " · Click to focus · Middle-click to close"
                    onClicked: DeckActions.focusWindow(modelData)
                    onMiddleClicked: CompositorService.closeWindow(modelData)
                    onSecondaryClicked: root.windowsRequested()
                    wheelEnabled: true
                    onScrolled: delta => {
                        if (delta === 0 || root.windows.length < 2) return;
                        const index = Math.max(0, root.focusedIndex);
                        const next = (index + (delta < 0 ? 1 : root.windows.length - 1)) % root.windows.length;
                        DeckActions.focusWindow(root.windows[next].id);
                    }

                }
            }
        }
    }
}
