pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.theme
import "defaults/theme.js" as ThemeDefaults
import "defaults/bar.js" as BarDefaults
import "defaults/performance.js" as PerformanceDefaults
import "defaults/weather.js" as WeatherDefaults
import "defaults/lockscreen.js" as LockscreenDefaults
import "defaults/system.js" as SystemDefaults
import "defaults/ai.js" as AiDefaults
import "ConfigValidator.js" as ConfigValidator

Singleton {
    id: root

    property string version: "0.0.0"

    FileView {
        id: versionFile
        path: Qt.resolvedUrl("../version").toString().replace("file://", "")
        onLoaded: root.version = text().trim()
    }

    property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/nonchalant/config"
    property string presetDir: Qt.resolvedUrl("../assets/presets/Nonchalant Default").toString().replace("file://", "")
    property bool configDirReady: false

    // Module init status
    property bool themeReady: false
    property bool barReady: false
    property bool performanceReady: false
    property bool weatherReady: false
    property bool lockscreenReady: false
    property bool systemReady: false
    property bool aiReady: false

    property bool initialLoadComplete: themeReady && barReady && performanceReady && weatherReady && lockscreenReady && systemReady && aiReady

    // Compatibility aliases
    property alias loader: themeLoader

    // ============================================
    // BATCH INITIALIZATION
    // ============================================
    // Ensure config directory exists and copy preset files if missing
    Process {
        id: ensureConfigDir
        running: true
        command: [
            "bash", "-c",
            "mkdir -p '" + root.configDir + "' && " +
            "cp -n '" + root.presetDir + "/theme.json' '" + root.configDir + "/theme.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/bar.json' '" + root.configDir + "/bar.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/performance.json' '" + root.configDir + "/performance.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/weather.json' '" + root.configDir + "/weather.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/lockscreen.json' '" + root.configDir + "/lockscreen.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/ai.json' '" + root.configDir + "/ai.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/system.json' '" + root.configDir + "/system.json' 2>/dev/null || true; " +
            "echo 'Preset files copied if missing'"
        ]
        onExited: root.configDirReady = true
    }

    // ============================================
    // THEME MODULE
    // ============================================
    FileView {
        id: themeLoader
        path: root.configDirReady ? root.configDir + "/theme.json" : ""
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.themeReady) {
                validateModule("theme", themeLoader, ThemeDefaults.data, () => {
                    root.themeReady = true;
                });
            }
        }
        onLoadFailed: function(error) {
            if (!root.themeReady) {
                handleMissingConfig("theme", themeLoader, ThemeDefaults.data, () => {
                    root.themeReady = true;
                });
            }
        }
        onFileChanged: reload()
        onAdapterUpdated: {
            if (root.themeReady) {
                themeLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property bool oledMode: false
            property bool lightMode: false
            property int roundness: 16
            property string font: "JetBrains Mono"
            property int fontSize: 14
            property string monoFont: "JetBrains Mono"
            property int monoFontSize: 14
            property bool tintIcons: false
            property int animDuration: 300
            property real shadowOpacity: 0.5
            property string shadowColor: "shadow"
            property int shadowXOffset: 0
            property int shadowYOffset: 0
            property real shadowBlur: 1

            property JsonObject srBg: JsonObject {
                property string label: "Background"
                property list<var> gradient: [["background", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "background"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srPopup: JsonObject {
                property string label: "Popup"
                property list<var> gradient: [["background", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "background"
                property list<var> border: ["surfaceBright", 2]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srInternalBg: JsonObject {
                property string label: "Internal BG"
                property list<var> gradient: [["background", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "background"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srBarBg: JsonObject {
                property string label: "Bar BG"
                property list<var> gradient: [["surfaceDim", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "surfaceDim"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 0.0
            }

            property JsonObject srPane: JsonObject {
                property string label: "Pane"
                property list<var> gradient: [["surface", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surfaceBright"
                property string halftoneBackgroundColor: "surface"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srCommon: JsonObject {
                property string label: "Common"
                property list<var> gradient: [["surface", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "background"
                property string halftoneBackgroundColor: "surface"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srFocus: JsonObject {
                property string label: "Focus"
                property list<var> gradient: [["surfaceBright", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surfaceVariant"
                property string halftoneBackgroundColor: "surfaceBright"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srPrimary: JsonObject {
                property string label: "Primary"
                property list<var> gradient: [["primary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overPrimaryContainer"
                property string halftoneBackgroundColor: "primary"
                property list<var> border: ["primary", 0]
                property string itemColor: "overPrimary"
                property real opacity: 1.0
            }

            property JsonObject srPrimaryFocus: JsonObject {
                property string label: "Primary Focus"
                property list<var> gradient: [["overPrimaryContainer", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "primary"
                property string halftoneBackgroundColor: "overPrimaryContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overPrimary"
                property real opacity: 1.0
            }

            property JsonObject srOverPrimary: JsonObject {
                property string label: "Over Primary"
                property list<var> gradient: [["overPrimary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "primaryContainer"
                property string halftoneBackgroundColor: "overPrimary"
                property list<var> border: ["overPrimary", 0]
                property string itemColor: "primary"
                property real opacity: 1.0
            }

            property JsonObject srSecondary: JsonObject {
                property string label: "Secondary"
                property list<var> gradient: [["secondary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overSecondaryContainer"
                property string halftoneBackgroundColor: "secondary"
                property list<var> border: ["secondary", 0]
                property string itemColor: "overSecondary"
                property real opacity: 1.0
            }

            property JsonObject srSecondaryFocus: JsonObject {
                property string label: "Secondary Focus"
                property list<var> gradient: [["overSecondaryContainer", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "secondary"
                property string halftoneBackgroundColor: "overSecondaryContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overSecondary"
                property real opacity: 1.0
            }

            property JsonObject srOverSecondary: JsonObject {
                property string label: "Over Secondary"
                property list<var> gradient: [["overSecondary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "secondaryContainer"
                property string halftoneBackgroundColor: "overSecondary"
                property list<var> border: ["overSecondary", 0]
                property string itemColor: "secondary"
                property real opacity: 1.0
            }

            property JsonObject srTertiary: JsonObject {
                property string label: "Tertiary"
                property list<var> gradient: [["tertiary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overTertiaryContainer"
                property string halftoneBackgroundColor: "tertiary"
                property list<var> border: ["tertiary", 0]
                property string itemColor: "overTertiary"
                property real opacity: 1.0
            }

            property JsonObject srTertiaryFocus: JsonObject {
                property string label: "Tertiary Focus"
                property list<var> gradient: [["overTertiaryContainer", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "tertiary"
                property string halftoneBackgroundColor: "overTertiaryContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overTertiary"
                property real opacity: 1.0
            }

            property JsonObject srOverTertiary: JsonObject {
                property string label: "Over Tertiary"
                property list<var> gradient: [["overTertiary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "tertiaryContainer"
                property string halftoneBackgroundColor: "overTertiary"
                property list<var> border: ["overTertiary", 0]
                property string itemColor: "tertiary"
                property real opacity: 1.0
            }

            property JsonObject srError: JsonObject {
                property string label: "Error"
                property list<var> gradient: [["error", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overErrorContainer"
                property string halftoneBackgroundColor: "error"
                property list<var> border: ["error", 0]
                property string itemColor: "overError"
                property real opacity: 1.0
            }

            property JsonObject srErrorFocus: JsonObject {
                property string label: "Error Focus"
                property list<var> gradient: [["overBackground", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "error"
                property string halftoneBackgroundColor: "overErrorContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overError"
                property real opacity: 1.0
            }

            property JsonObject srOverError: JsonObject {
                property string label: "Over Error"
                property list<var> gradient: [["overError", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "errorContainer"
                property string halftoneBackgroundColor: "overError"
                property list<var> border: ["overError", 0]
                property string itemColor: "error"
                property real opacity: 1.0
            }
        }
    }

    // ============================================
    // BAR MODULE
    // ============================================
    FileView {
        id: barLoader
        path: root.configDirReady ? root.configDir + "/bar.json" : ""
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.barReady) {
                validateModule("bar", barLoader, BarDefaults.data, () => {
                    root.barReady = true;
                });
            }
        }
        onLoadFailed: function(error) {
            if (!root.barReady) {
                handleMissingConfig("bar", barLoader, BarDefaults.data, () => {
                    root.barReady = true;
                });
            }
        }
        onFileChanged: reload()
        onAdapterUpdated: {
            if (root.barReady) {
                barLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string position: "top"
            property list<string> screenList: []
            property bool enableFirefoxPlayer: false
            property bool use12hFormat: false
        }
    }

    // ============================================
    // PERFORMANCE MODULE
    // ============================================
    FileView {
        id: performanceLoader
        path: root.configDirReady ? root.configDir + "/performance.json" : ""
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.performanceReady) {
                validateModule("performance", performanceLoader, PerformanceDefaults.data, () => {
                    root.performanceReady = true;
                });
            }
        }
        onLoadFailed: function(error) {
            if (!root.performanceReady) {
                handleMissingConfig("performance", performanceLoader, PerformanceDefaults.data, () => {
                    root.performanceReady = true;
                });
            }
        }
        onFileChanged: reload()
        onAdapterUpdated: {
            if (root.performanceReady) {
                performanceLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property bool blurTransition: true
            property bool windowPreview: true
            property bool wavyLine: true
            property bool rotateCoverArt: true
            property bool dashboardPersistTabs: true
            property int dashboardMaxPersistentTabs: 2
        }
    }

    // ============================================
    // WEATHER MODULE
    // ============================================
    FileView {
        id: weatherLoader
        path: root.configDirReady ? root.configDir + "/weather.json" : ""
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.weatherReady) {
                validateModule("weather", weatherLoader, WeatherDefaults.data, () => {
                    root.weatherReady = true;
                });
            }
        }
        onLoadFailed: function(error) {
            if (!root.weatherReady) {
                handleMissingConfig("weather", weatherLoader, WeatherDefaults.data, () => {
                    root.weatherReady = true;
                });
            }
        }
        onFileChanged: reload()
        onAdapterUpdated: {
            if (root.weatherReady) {
                weatherLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string location: ""
            property string unit: "C"
        }
    }


    // ============================================
    // LOCKSCREEN MODULE
    // ============================================
    FileView {
        id: lockscreenLoader
        path: root.configDirReady ? root.configDir + "/lockscreen.json" : ""
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.lockscreenReady) {
                validateModule("lockscreen", lockscreenLoader, LockscreenDefaults.data, () => {
                    root.lockscreenReady = true;
                });
            }
        }
        onLoadFailed: function(error) {
            if (!root.lockscreenReady) {
                handleMissingConfig("lockscreen", lockscreenLoader, LockscreenDefaults.data, () => {
                    root.lockscreenReady = true;
                });
            }
        }
        onFileChanged: reload()
        onAdapterUpdated: {
            if (root.lockscreenReady) {
                lockscreenLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string position: "bottom"
        }
    }


    // ============================================
    // SYSTEM MODULE
    // ============================================
    FileView {
        id: systemLoader
        path: root.configDirReady ? root.configDir + "/system.json" : ""
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.systemReady) {
                validateModule("system", systemLoader, SystemDefaults.data, () => {
                    root.systemReady = true;
                });
            }
        }
        onLoadFailed: function(error) {
            if (!root.systemReady) {
                handleMissingConfig("system", systemLoader, SystemDefaults.data, () => {
                    root.systemReady = true;
                });
            }
        }
        onFileChanged: reload()
        onAdapterUpdated: {
            if (root.systemReady) {
                systemLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property list<string> disks: ["/"]
            property JsonObject pomodoro: JsonObject {
                property int workTime: 1500
                property int restTime: 300
                property bool autoStart: false
                property bool syncSpotify: false
            }
        }
    }


    // ============================================
    // AI MODULE
    // ============================================
    FileView {
        id: aiLoader
        path: root.configDirReady ? root.configDir + "/ai.json" : ""
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.aiReady) {
                validateModule("ai", aiLoader, AiDefaults.data, () => {
                    root.aiReady = true;
                });
            }
        }
        onLoadFailed: function(error) {
            if (!root.aiReady) {
                handleMissingConfig("ai", aiLoader, AiDefaults.data, () => {
                    root.aiReady = true;
                });
            }
        }
        onFileChanged: reload()
        onAdapterUpdated: {
            if (root.aiReady) {
                aiLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property bool enabled: true
            property bool sidebarEnabled: true
            property string defaultAgent: "opencode"
            property string workingDirectory: ""
            property list<var> agents: [
                {
                    "id": "opencode",
                    "name": "OpenCode",
                    "command": ["opencode", "acp", "--print-logs", "--log-level", "ERROR"],
                    "authMethod": "opencode-login"
                },
                {
                    "id": "grok",
                    "name": "Grok Build",
                    "command": ["grok", "agent", "stdio"],
                    "authMethod": "cached_token"
                },
                {
                    "id": "codex",
                    "name": "Codex",
                    "command": ["sh", "-lc", "CODEX_PATH=\"$(command -v codex)\" exec npx -y @agentclientprotocol/codex-acp"],
                    "authMethod": "chatgpt"
                }
            ]
            property int sidebarWidth: 400
            property string sidebarPosition: "right"
            property bool sidebarPinnedOnStartup: false
        }
    }


    // Validation helper
    function validateModule(name, loader, defaults, onComplete) {
        var raw = loader.text();
        if (!raw || raw.trim().length === 0) {
            // File is missing or empty — create with defaults
            console.log(name + ".json missing or empty, creating default...");
            loader.setText(JSON.stringify(defaults, null, 2));
            onComplete();
            return;
        }

        try {
            var current = JSON.parse(raw);
            var validated = ConfigValidator.validate(current, defaults);

            if (JSON.stringify(current) !== JSON.stringify(validated)) {
                console.log("Merging and updating " + name + ".json...");
                loader.setText(JSON.stringify(validated, null, 2));
            }
            onComplete();
        } catch (e) {
            console.log("Error validating " + name + " config (invalid JSON?): " + e);
            console.log("Overwriting with defaults due to error.");
            loader.setText(JSON.stringify(defaults, null, 2));
            onComplete();
        }
    }

    // Create missing files directly from the in-tree defaults. The old
    // asynchronous preset copy raced FileView startup and left domains
    // permanently uninitialized when a preset file did not exist.
    function handleMissingConfig(name, loader, defaults, onComplete) {
        console.log(name + ".json not found, creating defaults");
        loader.setText(JSON.stringify(defaults, null, 2));
        onComplete();
    }


    // Exposed properties
    // Theme configuration
    property QtObject theme: themeLoader.adapter
    property bool oledMode: lightMode ? false : theme.oledMode
    property bool lightMode: theme.lightMode

    property int roundness: theme.roundness
    property string defaultFont: theme.font
    property int animDuration: theme.animDuration
    property bool tintIcons: theme.tintIcons

    // Handle lightMode changes
    onLightModeChanged: {
        console.log("lightMode changed to:", lightMode);
        if (GlobalStates.wallpaperManager) {
            var wallpaperManager = GlobalStates.wallpaperManager;
            if (wallpaperManager.currentWallpaper) {
                console.log("Re-running Matugen due to lightMode change");
                wallpaperManager.runMatugenForCurrentWallpaper();
            }
        }
    }

    // Bar configuration
    property QtObject bar: barLoader.adapter
    property bool showBackground: theme.srBarBg.opacity > 0

    // Performance configuration
    property QtObject performance: performanceLoader.adapter
    property bool blurTransition: performance.blurTransition

    // Weather configuration
    property QtObject weather: weatherLoader.adapter

    // Lockscreen configuration
    property QtObject lockscreen: lockscreenLoader.adapter

    // System configuration
    property QtObject system: systemLoader.adapter

    // AI configuration
    property QtObject ai: aiLoader.adapter

    function setAiWorkingDirectory(path) {
        aiLoader.adapter.workingDirectory = path || "";
    }

    // Color helpers
    function isHexColor(colorValue) {
        if (!colorValue || typeof colorValue !== 'string')
            return false;
        const normalized = colorValue.toLowerCase().trim();
        return normalized.startsWith('#') || normalized.startsWith('rgb');
    }

    function resolveColor(colorValue) {
        if (!colorValue) return "transparent"; // Fallback
        
        if (isHexColor(colorValue)) {
            return colorValue;
        }
        
        // Check Colors singleton
        if (typeof Colors === 'undefined' || !Colors) return "transparent";
        
        return Colors[colorValue] || "transparent"; 
    }

    function resolveColorWithOpacity(colorValue, opacity) {
        if (!colorValue) return Qt.rgba(0,0,0,0);
        
        const color = isHexColor(colorValue) ? Qt.color(colorValue) : (Colors[colorValue] || Qt.color("transparent"));
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }
}
