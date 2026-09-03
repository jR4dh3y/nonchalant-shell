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

    property var state: QtObject {
        property int currentTab: GlobalStates.dashboardCurrentTab
    }

    readonly property int tabCount: 2
    readonly property real nonAnimWidth: state.currentTab === 0 ? 600 : 400

    implicitWidth: nonAnimWidth
    implicitHeight: 430

    // LRU Tab Management
    property var lruAccessOrder: [0]  // Tracks access order: [0] means tab 0 is most recent
    property var lruTabsLoaded: ({0: true})  // Reflects which tabs are actually loaded

    // Update LRU on tab access
    function updateLRUAccess(tabIndex) {
        // Remove if already in list
        const idx = lruAccessOrder.indexOf(tabIndex);
        if (idx !== -1) {
            lruAccessOrder.splice(idx, 1);
        }
        // Add to end (most recent)
        lruAccessOrder.push(tabIndex);
        updateLoadedTabs();
    }

    // Determine which tabs should be loaded based on LRU and config
    function updateLoadedTabs() {
        let newLoadedTabs = {};
        
        // Always load tab 0 (WidgetsTab) to avoid "jumpy" opening
        newLoadedTabs[0] = true;
        
        // Always load current tab
        newLoadedTabs[root.state.currentTab] = true;

        if (Config.performance.dashboardPersistTabs) {
            // Load up to maxPersistentTabs most recent tabs
            const maxTabs = Math.max(1, Config.performance.dashboardMaxPersistentTabs);
            const startIdx = Math.max(0, lruAccessOrder.length - maxTabs);
            for (let i = startIdx; i < lruAccessOrder.length; i++) {
                newLoadedTabs[lruAccessOrder[i]] = true;
            }
        }

        lruTabsLoaded = newLoadedTabs;
    }

    // Check if a tab should be loaded
    function shouldTabBeLoaded(tabIndex) {
        if (tabIndex === 0) return true; // Always load WidgetsTab (Tab 0)

        if (Config.performance.dashboardPersistTabs) {
            return lruTabsLoaded[tabIndex] === true;
        } else {
            // Without persistence, only load current tab
            return root.state.currentTab === tabIndex;
        }
    }

    function focusCurrentTab() {
        const activeLoader = root.state.currentTab === 1
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

    // Navegar a la pestaña seleccionada cuando se abre el dashboard
    Component.onCompleted: {
        root.state.currentTab = Math.max(0, Math.min(GlobalStates.dashboardCurrentTab, root.tabCount - 1));
        GlobalStates.dashboardCurrentTab = root.state.currentTab;
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
                        widgetsTabLoader.visible = (root.state.currentTab === 0);
                        wallpapersTabLoader.visible = (root.state.currentTab === 1);
                        widgetsTabLoader.x = 0;
                        wallpapersTabLoader.x = 0;
                        root.focusCurrentTab();
                    }
                }

                // Function to navigate to a specific tab
                function navigateToTab(index) {
                    if (index >= 0 && index < root.tabCount && index !== root.state.currentTab) {
                        const oldIndex = root.state.currentTab;
                        root.state.currentTab = index;
                        GlobalStates.dashboardCurrentTab = index;

                        // Update LRU when tab is accessed
                        root.updateLRUAccess(index);

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
                            fromLoader.x = 0;
                            fromLoader.opacity = 0;
                            fromLoader.visible = false;

                            toLoader.x = 0;
                            toLoader.opacity = 1;
                            toLoader.visible = true;
                            root.focusCurrentTab();
                        }
                    }
                }

                // Tab 0: widgets
                Loader {
                    id: widgetsTabLoader
                    width: parent.width
                    height: parent.height
                    active: root.shouldTabBeLoaded(0) || root.state.currentTab === 0 || opacity > 0
                    sourceComponent: widgetsComponent
                    visible: root.state.currentTab === 0
                    opacity: root.state.currentTab === 0 ? 1 : 0
                    z: root.state.currentTab === 0 ? 2 : 1
                }

                // Tab 1: Wallpapers
                Loader {
                    id: wallpapersTabLoader
                    width: parent.width
                    height: parent.height
                    active: root.shouldTabBeLoaded(1) || root.state.currentTab === 1 || opacity > 0
                    sourceComponent: wallpapersComponent
                    visible: root.state.currentTab === 1
                    opacity: root.state.currentTab === 1 ? 1 : 0
                    z: root.state.currentTab === 1 ? 2 : 1
                }

            }
        }
    }

    // Atajos de teclado para navegación
    Shortcut {
        id: nextTabShortcut
        sequence: "Ctrl+Tab"
        enabled: GlobalStates.dashboardOpen

        onActivated: {
            let nextIndex = (root.state.currentTab + 1) % root.tabCount;
            stack.navigateToTab(nextIndex);
        }
    }

    Shortcut {
        id: prevTabShortcut
        sequence: "Ctrl+Shift+Tab"
        enabled: GlobalStates.dashboardOpen

        onActivated: {
            let prevIndex = root.state.currentTab - 1;
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
