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
    
    // Widgets tab internal state (for prefix-based tabs)
    // 0=launcher, 1=clipboard, 2=emoji, 3=tmux, 4=wallpapers
    property int widgetsTabCurrentIndex: 0

    // Persistent wallpaper navigation state
    property int wallpaperSelectedIndex: -1

    function clearWallpaperState() {
        wallpaperSelectedIndex = -1;
    }

    function getActiveLauncher() {
        let active = Visibilities.getForActive();
        return active ? active.launcher : false;
    }

    function getActiveProjects() {
        return getActiveLauncher() && launcherMode === "projects";
    }

    function getActiveDashboard() {
        let active = Visibilities.getForActive();
        return active ? active.dashboard === true : false;
    }

    function getActiveOverview() {
        let active = Visibilities.getForActive();
        return active ? active.overview === true : false;
    }

    function getActivePresets() {
        let active = Visibilities.getForActive();
        return active ? active.presets === true : false;
    }

    // Legacy properties for backward compatibility - use active screen
    readonly property bool overviewOpen: getActiveOverview()
    readonly property bool presetsOpen: getActivePresets()
    readonly property bool launcherOpen: getActiveLauncher()
    readonly property bool projectsOpen: getActiveProjects()
    readonly property bool dashboardOpen: getActiveDashboard() || dashboardPopupScreen !== ""
    readonly property bool systemMonitorOpen: systemMonitorPopupScreen !== ""

    // Lockscreen state
    property bool lockscreenVisible: false
    // Legacy flags (unlock is immediate; kept so older bindings do not break).
    property bool lockscreenUnlocking: false
    property bool lockscreenHandoff: false
    property real lockscreenHandoffOpacity: 1

    // OSD state
    property bool osdVisible: false
    property string osdIndicator: "volume" // volume, mic, brightness

    // Screenshot Tool state
    property bool screenshotToolVisible: false
    // property string screenshotToolMode: "normal" // DEPRECATED
    property string screenshotCaptureMode: "region" // region, window, screen
    
    // Global selection state for synchronization
    property int screenshotSelectionX: 0
    property int screenshotSelectionY: 0
    property int screenshotSelectionW: 0
    property int screenshotSelectionH: 0

    // Screen Record Tool state
    property bool screenRecordToolVisible: false

    // Mirror Tool state
    property bool mirrorWindowVisible: false

    // Settings Window state
    property bool settingsWindowVisible: false
    property int settingsTargetWorkspaceId: 0
    property string settingsTargetScreenName: ""


    // ASSISTANT SIDEBAR STATE
    // ═══════════════════════════════════════════════════════════════
    property bool assistantVisible: false
    property bool assistantPinned: Config.ai.sidebarPinnedOnStartup ?? false
    property int assistantWidth: Config.ai.sidebarWidth ?? 400
    property string assistantPosition: Config.ai.sidebarPosition ?? "right"
    property string assistantScreenName: ""

    signal assistantFocusRequested(bool wasAlreadyOpen)

    function toggleAssistant() {
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

    property int settingsCurrentTab: 0
}
