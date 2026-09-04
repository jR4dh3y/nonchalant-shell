pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services
import qs.config

Singleton {
    id: root

    property var wallpaperManager: null
    property string avatarCacheBuster: ""

    function pickUserAvatar() {
        filePickerProcess.running = true;
    }

    Process {
        id: filePickerProcess
        running: false
        command: ["zenity", "--file-selection", "--title=Select User Icon", "--file-filter=Images | *.png *.jpg *.jpeg *.svg *.webp"]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path) {
                    console.log("Selected icon:", path);
                    copyIconProcess.command = ["cp", path, Quickshell.env("HOME") + "/.face.icon"];
                    copyIconProcess.running = true;
                }
            }
        }
    }

    Process {
        id: copyIconProcess
        running: false
        command: []

        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Icon updated successfully");
                avatarCacheBuster = Date.now();
            } else {
                console.warn("Failed to update icon");
            }
        }
    }

    // Ensure LockscreenService singleton is loaded
    Component.onCompleted: {
        // Reference the singleton to ensure it loads
        LockscreenService.toString();
    }

    // Persistent launcher state across monitors
    property string launcherMode: "apps"
    property string launcherSearchText: ""
    property int launcherSelectedIndex: -1

    function clearLauncherState() {
        launcherSearchText = "";
        launcherSelectedIndex = -1;
    }

    // Project picker state across monitors
    property string projectPickerSearchText: ""
    property int projectPickerSelectedIndex: 0

    function clearProjectPickerState() {
        projectPickerSearchText = "";
        projectPickerSelectedIndex = 0;
    }

    // Persistent dashboard state across monitors  
    property int dashboardCurrentTab: 0
    // Name of the screen whose bar-anchored dashboard popup is open.
    property string dashboardPopupScreen: ""
    property string systemMonitorPopupScreen: ""
    
    // Persistent wallpaper navigation state
    property int wallpaperSelectedIndex: -1

    function clearWallpaperState() {
        wallpaperSelectedIndex = -1;
    }

    function getActiveLauncher() {
        let active = Visibilities.getForActive();
        return active ? active.launcher : false;
    }

    readonly property bool launcherOpen: getActiveLauncher()
    readonly property bool dashboardOpen: dashboardPopupScreen !== ""
    readonly property bool systemMonitorOpen: systemMonitorPopupScreen !== ""

    // Lockscreen state
    property bool lockscreenVisible: false
    // Legacy flags (unlock is immediate; kept so older bindings do not break).
    property bool lockscreenUnlocking: false
    property bool lockscreenHandoff: false
    property real lockscreenHandoffOpacity: 1

    // Lockshot prep: per-screen desktop captures taken just BEFORE the lock
    // request so the lock surface's first frame matches the on-screen content
    // (windows included) instead of flashing the clean wallpaper. Each
    // Wallpaper window registers a prep handler; LockscreenService waits for
    // all of them (with a timeout) before engaging the lock.
    property var lockPrepHandlers: ({})
    property var lockshotPaths: ({})
    property int lockshotPending: 0

    function registerLockPrep(screenName, handler) {
        const map = Object.assign({}, lockPrepHandlers);
        map[screenName] = handler;
        lockPrepHandlers = map;
    }

    function unregisterLockPrep(screenName) {
        const map = Object.assign({}, lockPrepHandlers);
        delete map[screenName];
        lockPrepHandlers = map;
    }

    // Kick off a capture on every registered screen. Returns how many
    // prep handlers actually started.
    function beginLockshotPrep(): int {
        let started = 0;
        lockshotPaths = {};
        for (const name in lockPrepHandlers) {
            try {
                if (lockPrepHandlers[name]())
                    started++;
            } catch (e) {
                console.warn("Lockshot prep failed for screen", name, e);
            }
        }
        lockshotPending = started;
        return started;
    }

    function notifyLockshotPrepared(screenName, path) {
        if (path) {
            const map = Object.assign({}, lockshotPaths);
            map[screenName] = path;
            lockshotPaths = map;
        }
        if (lockshotPending > 0)
            lockshotPending--;
    }

    // OSD state
    property bool osdVisible: false
    property string osdIndicator: "volume" // volume, mic, brightness

    // Settings Window state
    property bool settingsWindowVisible: false
    property int settingsTargetWorkspaceId: 0
    property string settingsTargetScreenName: ""


    // ASSISTANT SIDEBAR STATE
    // ═══════════════════════════════════════════════════════════════
    readonly property bool assistantAvailable: Config.aiReady
        && (Config.ai.enabled ?? true)
        && (Config.ai.sidebarEnabled ?? true)
    property bool assistantVisible: false
    property bool assistantPinned: Config.ai.sidebarPinnedOnStartup ?? false
    property int assistantWidth: Config.ai.sidebarWidth ?? 400
    property string assistantPosition: Config.ai.sidebarPosition ?? "right"
    property string assistantScreenName: ""

    signal assistantFocusRequested(bool wasAlreadyOpen)

    function toggleAssistant() {
        if (!assistantAvailable) {
            assistantVisible = false;
            return;
        }
        if (assistantVisible) {
            assistantFocusRequested(true);
        } else {
            assistantVisible = true;
            if (NiriService.focusedMonitor && NiriService.focusedMonitor.name) {
                assistantScreenName = NiriService.focusedMonitor.name;
            } else if (Quickshell.screens.length > 0) {
                assistantScreenName = Quickshell.screens[0].name;
            }
            assistantFocusRequested(false);
        }
    }

    function hideAssistant() {
        assistantVisible = false;
    }

    onAssistantAvailableChanged: {
        if (!assistantAvailable)
            hideAssistant();
    }

    property int settingsCurrentTab: 0
}
