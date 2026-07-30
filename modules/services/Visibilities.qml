pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services

Singleton {
    id: root

    property var screens: ({})
    property var barPanels: ({})
    property var powerMenuButtons: ({})
    property var systemMonitorButtons: ({})
    property string currentActiveModule: ""
    property string lastFocusedScreen: ""
    property var contextMenu: null
    property bool playerMenuOpen: false
    // Exclusive bar popup: only one BarPopup should be open at a time.
    property var activeBarPopup: null
    readonly property var moduleNames: ["launcher"]

    function claimBarPopup(popup) {
        if (!popup)
            return;
        if (activeBarPopup && activeBarPopup !== popup) {
            try {
                // Prefer quick close so weather→dashboard (and similar) crossfades
                // instead of waiting on a full exit animation.
                if (typeof activeBarPopup.closeQuick === "function")
                    activeBarPopup.closeQuick();
                else if (activeBarPopup.isOpen)
                    activeBarPopup.close();
            } catch (e) {
                // Previous popup may already be destroyed.
            }
        }
        // Opening a bar popup should dismiss the run menu / modules.
        clearAll();
        currentActiveModule = "";
        activeBarPopup = popup;
    }

    function releaseBarPopup(popup) {
        if (activeBarPopup === popup)
            activeBarPopup = null;
    }

    function closeActiveBarPopup() {
        if (activeBarPopup) {
            try {
                if (activeBarPopup.isOpen)
                    activeBarPopup.close();
            } catch (e) {}
            activeBarPopup = null;
        }
    }

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

    function registerBarPanel(screenName, barPanel) {
        barPanels = _updateMap(barPanels, screenName, barPanel);
    }

    function unregisterBarPanel(screenName) {
        barPanels = _updateMap(barPanels, screenName, null);
    }

    function getBarPanelForScreen(screenName) {
        return barPanels[screenName] || null;
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

        // Prefer niri's focused monitor; fall back to the first Quickshell screen
        // so modules still open when compositor focus is unavailable.
        let focusedScreenName = "";
        if (NiriService.focusedMonitor && NiriService.focusedMonitor.name)
            focusedScreenName = NiriService.focusedMonitor.name;
        else if (Quickshell.screens.length > 0)
            focusedScreenName = Quickshell.screens[0].name;
        else
            return;

        // Modules and bar popups are mutually exclusive.
        closeActiveBarPopup();
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

        property var lastFullscreenOutputs: []

        function onFocusedMonitorChanged() {
            moveActiveModuleToFocusedScreen();
        }

        function onOverviewOpenChanged() {
            // Overview is a full compositor surface — dismiss shell chrome.
            if (NiriService.overviewOpen) {
                closeActiveBarPopup();
                clearAll();
                currentActiveModule = "";
            }
        }

        function onFullscreenOutputsChanged() {
            // A fullscreen window covers the Overlay-layer panel — dismiss shell
            // chrome, but only when a screen newly enters fullscreen.
            const outputs = NiriService.fullscreenOutputs;
            const newlyFullscreen = outputs.some(name => lastFullscreenOutputs.indexOf(name) === -1);
            lastFullscreenOutputs = outputs.slice();
            if (newlyFullscreen) {
                closeActiveBarPopup();
                clearAll();
                currentActiveModule = "";
            }
        }
    }
}
