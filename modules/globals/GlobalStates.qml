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

    // Dynamic Island state flags
    property bool islandOpen: false
    property bool islandLauncherOpen: false
    property bool islandStatsOpen: false

    readonly property bool launcherOpen: getActiveLauncher() || islandLauncherOpen
    readonly property bool dashboardOpen: (dashboardPopupScreen !== "") || islandOpen
    readonly property bool systemMonitorOpen: (systemMonitorPopupScreen !== "") || islandStatsOpen

    // Lockscreen state
    // True from the lock request until niri is released after unlock.
    property bool lockscreenVisible: false
    // PAM succeeded; lock surfaces are running their exit animation.
    property bool lockscreenUnlocking: false
    // Mirrors WlSessionLock.secure: niri has confirmed every output is locked.
    property bool lockscreenSecure: false
    // Drives LockCurtain: raised before the lock engages, lowered after unlock.
    property bool lockCurtainShown: false

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
