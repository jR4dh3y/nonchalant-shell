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

    opacity: isVisible ? 1 : 0
    visible: forceVisible || opacity > 0

    Behavior on opacity {
        enabled: Config.animDuration > 0
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
        Rectangle {
            id: viewWrapper

            color: "transparent"
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

                // Function to navigate to a specific tab
                function navigateToTab(index) {
                    if (index >= 0 && index < root.tabCount && index !== root.state.currentTab) {
                        root.state.currentTab = index;
                        GlobalStates.dashboardCurrentTab = index;
                        
                        // Update LRU when tab is accessed
                        root.updateLRUAccess(index);

                        if (index === 0)
                            Notifications.hideAllPopups();
                    }
                }

                // Generic Tab Loader Component
                component TabLoader : Loader {
                    anchors.fill: parent
                    // Load based on LRU strategy or if currently active
                    active: root.shouldTabBeLoaded(index) || root.state.currentTab === index
                    
                    // Visibility handles the "switching"
                    visible: root.state.currentTab === index
                    
                    // Transitions
                    opacity: visible ? 1 : 0
                    transform: Translate {
                        y: visible ? 0 : (root.state.currentTab > index ? -20 : 20)
                        Behavior on y {
                             enabled: Config.animDuration > 0
                             NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } 
                        }
                    }

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
                    }

                }

                // Tab 0: widgets
                TabLoader {
                    property int index: 0
                    sourceComponent: widgetsComponent
                    z: visible ? 1 : 0
                }

                // Tab 1: Wallpapers
                TabLoader {
                    property int index: 1
                    sourceComponent: wallpapersComponent
                    z: visible ? 1 : 0
                }

                // Gesture handling para swipe vertical
                MouseArea {
                    anchors.fill: parent
                    property real startY: 0
                    property real startX: 0
                    property bool swiping: false
                    property real swipeThreshold: 50
                    
                    // Allow clicking through to tabs
                    propagateComposedEvents: true
                    preventStealing: false

                    onPressed: mouse => {
                        startY = mouse.y;
                        startX = mouse.x;
                        swiping = false;
                        mouse.accepted = false; // Let children handle clicks
                    }

                    onPositionChanged: mouse => {
                        let deltaY = mouse.y - startY;
                        let deltaX = Math.abs(mouse.x - startX);

                        // Solo considerar swipe vertical si el movimiento horizontal es mínimo
                        if (Math.abs(deltaY) > 20 && deltaX < 30) {
                            swiping = true;
                        }
                    }

                    onReleased: mouse => {
                        if (swiping) {
                            let deltaY = mouse.y - startY;

                            if (deltaY < -swipeThreshold && root.state.currentTab < root.tabCount - 1) {
                                // Swipe hacia arriba - siguiente tab
                                stack.navigateToTab(root.state.currentTab + 1);
                            } else if (deltaY > swipeThreshold && root.state.currentTab > 0) {
                                // Swipe hacia abajo - tab anterior
                                stack.navigateToTab(root.state.currentTab - 1);
                            }
                        }
                        swiping = false;
                        mouse.accepted = false;
                    }
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

    // Animated size properties for smooth transitions
    property real animatedWidth: implicitWidth
    property real animatedHeight: implicitHeight

    width: animatedWidth
    height: animatedHeight

    // Update animated properties when implicit properties change
    onImplicitWidthChanged: animatedWidth = implicitWidth
    onImplicitHeightChanged: animatedHeight = implicitHeight

    Behavior on animatedWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }

    Behavior on animatedHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
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
