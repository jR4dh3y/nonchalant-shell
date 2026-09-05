pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services
import qs.modules.globals
import qs.config

Singleton {
    id: root

    property var screens: ({})
    property var barPanels: ({})
    property var islands: ({})
    property var dashboardControllers: ({})
    property var powerMenuButtons: ({})
    property var systemMonitorButtons: ({})
    property string currentActiveModule: ""
    property string lastFocusedScreen: ""
    property var contextMenu: null
    property bool playerMenuOpen: false
    // Exclusive bar popup: only one BarPopup should be open at a time.
    property var activeBarPopup: null
    readonly property list<string> moduleNames: ["launcher"]

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

    function registerIsland(screenName, island) {
        islands = _updateMap(islands, screenName, island);
    }

    function unregisterIsland(screenName, island) {
        if (islands[screenName] === island)
            islands = _updateMap(islands, screenName, null);
    }

    function getIslandForScreen(screenName) {
        return islands[screenName] || null;
    }

    function getIslandForActive() {
        const focusedMonitor = NiriService.focusedMonitor;
        if (!focusedMonitor) {
            if (Quickshell.screens.length > 0)
                return islands[Quickshell.screens[0].name] || null;
            return null;
        }
        return islands[focusedMonitor.name] || null;
    }

    function registerDashboardController(screenName, controller) {
        dashboardControllers = _updateMap(dashboardControllers, screenName, controller);
    }

    function unregisterDashboardController(screenName, controller) {
        if (dashboardControllers[screenName] === controller)
            dashboardControllers = _updateMap(dashboardControllers, screenName, null);
    }

    function getDashboardControllerForActive() {
        const focusedMonitor = NiriService.focusedMonitor;
        if (!focusedMonitor)
            return null;
        return dashboardControllers[focusedMonitor.name] || null;
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

        if ((Config.bar?.style ?? "default") === "island") {
            const island = getIslandForActive();
            if (island) {
                if (island.isExpanded && island.currentMode === "power") {
                    island.collapse();
                } else {
                    clearAll();
                    currentActiveModule = "powermenu";
                    island.expand("power");
                }
                return;
            }
        }

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

        if ((Config.bar?.style ?? "default") === "island") {
            const island = getIslandForActive();
            if (island) {
                if (island.isExpanded && island.currentMode === "stats") {
                    island.collapse();
                } else {
                    clearAll();
                    currentActiveModule = "system-monitor";
                    island.expand("stats");
                }
                return;
            }
        }

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

        if ((Config.bar?.style ?? "default") === "island") {
            const island = getIslandForActive();
            if (island) {
                if (moduleName === "launcher") {
                    closeActiveBarPopup();
                    clearAll();
                    currentActiveModule = "launcher";
                    const mode = GlobalStates.launcherMode === "projects" ? "projects" : "apps";
                    island.expand(mode);
                    return;
                } else if (moduleName === "dashboard") {
                    closeActiveBarPopup();
                    clearAll();
                    currentActiveModule = "dashboard";
                    island.expand("dashboard");
                    return;
                } else if (moduleName === "wallpapers" || moduleName === "wallpaper") {
                    closeActiveBarPopup();
                    clearAll();
                    currentActiveModule = "wallpapers";
                    island.expand("wallpapers");
                    return;
                } else if (moduleName === "alerts" || moduleName === "notifications") {
                    closeActiveBarPopup();
                    clearAll();
                    currentActiveModule = "alerts";
                    island.expand("alerts");
                    return;
                } else if (moduleName === "stats" || moduleName === "system-monitor") {
                    closeActiveBarPopup();
                    clearAll();
                    currentActiveModule = "stats";
                    island.expand("stats");
                    return;
                } else if (moduleName === "power" || moduleName === "powermenu") {
                    closeActiveBarPopup();
                    clearAll();
                    currentActiveModule = "powermenu";
                    island.expand("power");
                    return;
                } else if (moduleName === "sound" || moduleName === "audio") {
                    closeActiveBarPopup();
                    clearAll();
                    currentActiveModule = "sound";
                    island.expand("sound");
                    return;
                } else if (moduleName === "battery" || moduleName === "powerprofile") {
                    closeActiveBarPopup();
                    clearAll();
                    currentActiveModule = "battery";
                    island.expand("battery");
                    return;
                } else if (moduleName === "wifi" || moduleName === "network") {
                    closeActiveBarPopup();
                    clearAll();
                    currentActiveModule = "wifi";
                    island.expand("wifi");
                    return;
                } else if (moduleName === "bluetooth") {
                    closeActiveBarPopup();
                    clearAll();
                    currentActiveModule = "bluetooth";
                    island.expand("bluetooth");
                    return;
                } else if (moduleName === "weather") {
                    closeActiveBarPopup();
                    clearAll();
                    currentActiveModule = "weather";
                    island.expand("weather");
                    return;
                } else if (!moduleName) {
                    currentActiveModule = "";
                    island.collapse();
                    return;
                }
            }
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
        if ((Config.bar?.style ?? "default") === "island") {
            for (const screenName in islands) {
                const island = islands[screenName];
                if (island && island.isExpanded) {
                    island.collapse();
                }
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
                const island = getIslandForActive();
                if (island)
                    island.collapse();
            }
        }

        function onFullscreenOutputsChanged() {
            // In island style, windows naturally occupy full output without top reservation.
            if ((Config.bar?.style ?? "default") === "island")
                return;

            // A fullscreen window covers the Overlay-layer panel — dismiss shell
            // chrome, but only when a screen newly enters fullscreen.
            const outputs = NiriService.fullscreenOutputs;
            const newlyFullscreen = outputs.some(name => lastFullscreenOutputs.indexOf(name) === -1);
            lastFullscreenOutputs = outputs.slice();
            if (newlyFullscreen) {
                closeActiveBarPopup();
                clearAll();
                currentActiveModule = "";
                const island = getIslandForActive();
                if (island)
                    island.collapse();
            }
        }
    }
}
