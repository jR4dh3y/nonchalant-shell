pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import "layouts"

Item {
    id: root

    required property ShellScreen screen

    readonly property string barStyle: Config.bar?.style ?? "default"
    readonly property bool isIsland: barStyle === "island"

    // Stable fallback hitbox so UnifiedShellPanel.mask never references undefined
    Item {
        id: fallbackHitbox
        width: 0
        height: 0
        visible: false
    }

    readonly property int barTargetHeight: layoutLoader.item ? layoutLoader.item.barTargetHeight : (root.isIsland ? 36 : 44)
    readonly property int baseOuterMargin: layoutLoader.item ? layoutLoader.item.baseOuterMargin : (root.isIsland ? 0 : 8)
    readonly property int totalBarHeight: layoutLoader.item ? layoutLoader.item.totalBarHeight : (root.isIsland ? 36 : 44)

    readonly property bool timerInputActive: layoutLoader.item ? layoutLoader.item.timerInputActive : false
    readonly property bool dashboardInputActive: layoutLoader.item ? layoutLoader.item.dashboardInputActive : false

    readonly property Item barHitbox: (layoutLoader.item && layoutLoader.item.barHitbox) ? layoutLoader.item.barHitbox : fallbackHitbox
    readonly property Item dashboardHitbox: (layoutLoader.item && layoutLoader.item.dashboardHitbox) ? layoutLoader.item.dashboardHitbox : fallbackHitbox

    readonly property bool islandActive: (root.isIsland && layoutLoader.item) ? (layoutLoader.item.islandActive ?? false) : false

    function collapseIsland() {
        if (root.isIsland && layoutLoader.item && typeof layoutLoader.item.collapse === "function") {
            layoutLoader.item.collapse();
        }
    }

    Loader {
        id: layoutLoader
        anchors.fill: parent
        sourceComponent: root.isIsland ? islandComponent : defaultComponent
    }

    Component {
        id: defaultComponent
        DefaultBar {
            anchors.fill: parent
            screen: root.screen
        }
    }

    Component {
        id: islandComponent
        IslandBar {
            anchors.fill: parent
            screen: root.screen
        }
    }
}
