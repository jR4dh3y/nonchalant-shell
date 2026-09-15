import QtQuick
import qs.modules.globals
import qs.modules.services
import qs.modules.widgets.dashboard.widgets
import qs.modules.widgets.dashboard.wallpapers
import qs.config

Item {
    id: root

    // When hosted inside the bar dashboard popup, the BarPopup owns the open/
    // close animation. Keep content fully visible so notifications and tabs
    // are not double-hidden behind GlobalStates.dashboardOpen.
    property bool forceVisible: false
    property bool isVisible: forceVisible || GlobalStates.dashboardOpen

    opacity: forceVisible ? 1 : (isVisible ? 1 : 0)
    visible: forceVisible || opacity > 0

    Behavior on opacity {
        enabled: !root.forceVisible && Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutQuad
        }
    }

    property string screenName: ""
    property int currentTab: GlobalStates.dashboardCurrentTab

    readonly property int tabCount: 2
    readonly property real nonAnimWidth: currentTab === 0 ? 600 : 400

    implicitWidth: nonAnimWidth
    implicitHeight: 430

    function focusCurrentTab() {
        const activeLoader = root.currentTab === 1
            ? wallpapersTabLoader
            : widgetsTabLoader;
        const activeTab = activeLoader.item;

        if (activeTab && typeof activeTab.focusSearchInput === "function") {
            activeTab.focusSearchInput();
        } else {
            root.forceActiveFocus();
        }
    }

    focus: true

    Component.onCompleted: {
        root.currentTab = Math.max(0, Math.min(GlobalStates.dashboardCurrentTab, root.tabCount - 1));
        GlobalStates.dashboardCurrentTab = root.currentTab;
    }

    onIsVisibleChanged: {
        if (isVisible && GlobalStates.dashboardCurrentTab === 0)
            Notifications.hideAllPopups();
    }

    Item {
        id: mainLayout
        anchors.fill: parent

        // Content area
        Item {
            id: viewWrapper
            anchors.fill: parent
            clip: true

            // Custom Tab View with Lazy Loading + Persistence
            Item {
                id: stack
                anchors.fill: parent

                // Update internal index when global changes
                Connections {
                    target: GlobalStates
                    function onDashboardCurrentTabChanged() {
                        stack.navigateToTab(GlobalStates.dashboardCurrentTab);
                    }
                }

                ParallelAnimation {
                    id: tabTransitionAnim
                    property real distance: 35
                    property int duration: Config.animDuration > 0 ? Math.min(Config.animDuration, 240) : 0

                    NumberAnimation { id: animOutX; duration: tabTransitionAnim.duration; easing.type: Easing.OutCubic }
                    NumberAnimation { id: animOutOpacity; duration: tabTransitionAnim.duration; easing.type: Easing.OutCubic; to: 0 }
                    NumberAnimation { id: animInX; duration: tabTransitionAnim.duration; easing.type: Easing.OutCubic; to: 0 }
                    NumberAnimation { id: animInOpacity; duration: tabTransitionAnim.duration; easing.type: Easing.OutCubic; to: 1 }

                    onFinished: {
                        root.restoreTabBindings();
                        root.focusCurrentTab();
                    }
                }

                // Animated switches imperatively override visible/opacity below,
                // which replaces their declarative bindings. Re-establish them
                // on settle so later direct currentTab writes keep working.
                function restoreTabBindings() {
                    widgetsTabLoader.visible = Qt.binding(() => root.currentTab === 0);
                    widgetsTabLoader.opacity = Qt.binding(() => root.currentTab === 0 ? 1 : 0);
                    wallpapersTabLoader.visible = Qt.binding(() => root.currentTab === 1);
                    wallpapersTabLoader.opacity = Qt.binding(() => root.currentTab === 1 ? 1 : 0);
                    widgetsTabLoader.x = 0;
                    wallpapersTabLoader.x = 0;
                }

                // Function to navigate to a specific tab
                function navigateToTab(index) {
                    if (index >= 0 && index < root.tabCount && index !== root.currentTab) {
                        const oldIndex = root.currentTab;
                        root.currentTab = index;
                        GlobalStates.dashboardCurrentTab = index;

                        if (index === 0)
                            Notifications.hideAllPopups();

                        const fromLoader = (oldIndex === 0) ? widgetsTabLoader : wallpapersTabLoader;
                        const toLoader = (index === 0) ? widgetsTabLoader : wallpapersTabLoader;

                        if (tabTransitionAnim.duration > 0 && root.isVisible) {
                            tabTransitionAnim.stop();

                            const forward = index > oldIndex;
                            const offset = tabTransitionAnim.distance;

                            toLoader.visible = true;
                            fromLoader.visible = true;

                            toLoader.x = forward ? offset : -offset;
                            toLoader.opacity = 0;

                            animOutX.target = fromLoader;
                            animOutX.property = "x";
                            animOutX.to = forward ? -offset : offset;

                            animOutOpacity.target = fromLoader;
                            animOutOpacity.property = "opacity";

                            animInX.target = toLoader;
                            animInX.property = "x";

                            animInOpacity.target = toLoader;
                            animInOpacity.property = "opacity";

                            tabTransitionAnim.restart();
                        } else {
                            tabTransitionAnim.stop();
                            root.restoreTabBindings();
                            root.focusCurrentTab();
                        }
                    }
                }

                // Tab 0: widgets (always loaded)
                Loader {
                    id: widgetsTabLoader
                    width: parent.width
                    height: parent.height
                    active: true
                    sourceComponent: widgetsComponent
                    visible: root.currentTab === 0
                    opacity: root.currentTab === 0 ? 1 : 0
                    z: root.currentTab === 0 ? 2 : 1
                }

                // Tab 1: Wallpapers (lazy loaded when selected or when persistTabs is true and maxTabs > 1)
                Loader {
                    id: wallpapersTabLoader
                    width: parent.width
                    height: parent.height
                    active: root.currentTab === 1 || (Config.performance.dashboardPersistTabs && Config.performance.dashboardMaxPersistentTabs > 1) || opacity > 0
                    sourceComponent: wallpapersComponent
                    visible: root.currentTab === 1
                    opacity: root.currentTab === 1 ? 1 : 0
                    z: root.currentTab === 1 ? 2 : 1
                }

            }
        }
    }

    // Keyboard shortcuts for tab switching
    Shortcut {
        id: nextTabShortcut
        sequence: "Ctrl+Tab"
        enabled: GlobalStates.dashboardOpen

        onActivated: {
            let nextIndex = (root.currentTab + 1) % root.tabCount;
            stack.navigateToTab(nextIndex);
        }
    }

    Shortcut {
        id: prevTabShortcut
        sequence: "Ctrl+Shift+Tab"
        enabled: GlobalStates.dashboardOpen

        onActivated: {
            let prevIndex = root.currentTab - 1;
            if (prevIndex < 0) {
                prevIndex = root.tabCount - 1;
            }
            stack.navigateToTab(prevIndex);
        }
    }


    // Component definitions for better performance (defined once, reused)
    Component {
        id: widgetsComponent
        WidgetsTab {}
    }

    Component {
        id: wallpapersComponent
        WallpapersTab {}
    }
}
