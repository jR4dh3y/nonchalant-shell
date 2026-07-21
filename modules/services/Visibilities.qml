pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services

Singleton {
    id: root

    property var screens: ({})
    property var panels: ({})
    property var bars: ({})
    property var barPanels: ({})
    property var notches: ({})
    property var notchPanels: ({})
    property var docks: ({})
    property var dockPanels: ({})
    property var powerMenuButtons: ({})
    property var systemMonitorButtons: ({})
    property string currentActiveModule: ""
    property string lastFocusedScreen: ""
    property var contextMenu: null
    property bool playerMenuOpen: false
    readonly property var moduleNames: ["launcher", "dashboard", "overview", "tools", "presets"]

    function setContextMenu(menu) {
        contextMenu = menu;
    }

    function getForScreen(screenName) {
        if (!screens[screenName]) {
            screens[screenName] = screenPropertiesComponent.createObject(root, {
                screenName: screenName
            });
        }
        return screens[screenName];
    }

    function getForActive() {
        if (!NiriService.focusedMonitor) {
            return null;
        }
        return getForScreen(NiriService.focusedMonitor.name);
    }

    // Helper to clone map and trigger update
    function _updateMap(map, key, value) {
        var newMap = {};
        for (var k in map) {
            newMap[k] = map[k];
        }
        if (value === null) {
            delete newMap[key];
        } else {
            newMap[key] = value;
        }
        return newMap;
    }

    function registerPanel(screenName, panel) {
        panels = _updateMap(panels, screenName, panel);
    }

    function unregisterPanel(screenName) {
        panels = _updateMap(panels, screenName, null);
    }

    function registerBar(screenName, barContainer) {
        bars = _updateMap(bars, screenName, barContainer);
    }

    function unregisterBar(screenName) {
        bars = _updateMap(bars, screenName, null);
    }

    function getBarForScreen(screenName) {
        return bars[screenName] || null;
    }

    function registerBarPanel(screenName, barPanel) {
        barPanels = _updateMap(barPanels, screenName, barPanel);
    }

    function unregisterBarPanel(screenName) {
        barPanels = _updateMap(barPanels, screenName, null);
    }

    function getBarPanelForScreen(screenName) {
        return barPanels[screenName] || null;
    }

    function registerNotch(screenName, notchContainer) {
        notches = _updateMap(notches, screenName, notchContainer);
    }

    function unregisterNotch(screenName) {
        notches = _updateMap(notches, screenName, null);
    }

    function getNotchForScreen(screenName) {
        return notches[screenName] || null;
    }

    function registerNotchPanel(screenName, notchPanel) {
        notchPanels = _updateMap(notchPanels, screenName, notchPanel);
    }

    function unregisterNotchPanel(screenName) {
        notchPanels = _updateMap(notchPanels, screenName, null);
    }

    function getNotchPanelForScreen(screenName) {
        return notchPanels[screenName] || null;
    }

    function registerDock(screenName, dockContainer) {
        docks = _updateMap(docks, screenName, dockContainer);
    }

    function unregisterDock(screenName) {
        docks = _updateMap(docks, screenName, null);
    }

    function getDockForScreen(screenName) {
        return docks[screenName] || null;
    }

    function registerDockPanel(screenName, dockPanel) {
        dockPanels = _updateMap(dockPanels, screenName, dockPanel);
    }

    function unregisterDockPanel(screenName) {
        dockPanels = _updateMap(dockPanels, screenName, null);
    }

    function getDockPanelForScreen(screenName) {
        return dockPanels[screenName] || null;
    }

    function registerPowerMenuButton(screenName, button) {
        powerMenuButtons = _updateMap(powerMenuButtons, screenName, button);
    }

    function unregisterPowerMenuButton(screenName, button) {
        if (powerMenuButtons[screenName] === button)
            powerMenuButtons = _updateMap(powerMenuButtons, screenName, null);
    }

    function togglePowerMenuForActive() {
        const focusedMonitor = NiriService.focusedMonitor;
        if (!focusedMonitor)
            return;

        const button = powerMenuButtons[focusedMonitor.name] || null;
        if (!button) {
            console.warn("Visibilities: no power menu button registered for", focusedMonitor.name);
            return;
        }

        clearAll();
        currentActiveModule = "";
        button.togglePopup();
    }

    function registerSystemMonitorButton(screenName, button) {
        systemMonitorButtons = _updateMap(systemMonitorButtons, screenName, button);
    }

    function unregisterSystemMonitorButton(screenName, button) {
        if (systemMonitorButtons[screenName] === button)
            systemMonitorButtons = _updateMap(systemMonitorButtons, screenName, null);
    }

    function toggleSystemMonitorForActive() {
        const focusedMonitor = NiriService.focusedMonitor;
        if (!focusedMonitor)
            return;

        const button = systemMonitorButtons[focusedMonitor.name] || null;
        if (!button) {
            console.warn("Visibilities: no system monitor button registered for", focusedMonitor.name);
            return;
        }

        clearAll();
        currentActiveModule = "";
        button.togglePopup();
    }

    function setActiveModule(moduleName) {
        if (moduleName === "powermenu") {
            togglePowerMenuForActive();
            return;
        }

        const focusedMonitor = NiriService.focusedMonitor;
        if (!focusedMonitor)
            return;

        const focusedScreenName = focusedMonitor.name;

        clearAll();

        if (moduleName) {
            currentActiveModule = moduleName;
            applyActiveModuleToScreen(focusedScreenName);
        } else {
            currentActiveModule = "";
        }

        lastFocusedScreen = focusedScreenName;
    }

    function moveActiveModuleToFocusedScreen() {
        const focusedMonitor = NiriService.focusedMonitor;
        if (!focusedMonitor || !currentActiveModule)
            return;

        const newFocusedScreen = focusedMonitor.name;
        if (newFocusedScreen === lastFocusedScreen)
            return;

        clearAll();
        applyActiveModuleToScreen(newFocusedScreen);
        lastFocusedScreen = newFocusedScreen;
    }

    Component {
        id: screenPropertiesComponent
        QtObject {
            property string screenName
            property bool launcher: false
            property bool dashboard: false
            property bool overview: false
            property bool tools: false
            property bool presets: false
        }
    }

    function clearAll() {
        for (const screenName in screens) {
            const screenProps = screens[screenName];
            for (let i = 0; i < moduleNames.length; i++) {
                screenProps[moduleNames[i]] = false;
            }
        }
    }

    function applyActiveModuleToScreen(screenName) {
        if (!currentActiveModule)
            return;

        const screenProps = getForScreen(screenName);
        if (moduleNames.indexOf(currentActiveModule) !== -1) {
            screenProps[currentActiveModule] = true;
        }
    }

    // Monitor focus changes
    Connections {
        target: NiriService
        function onFocusedMonitorChanged() {
            moveActiveModuleToFocusedScreen();
        }
    }
}
