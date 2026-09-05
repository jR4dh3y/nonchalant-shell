pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.modules.bar.clock
import qs.modules.bar.systray
import qs.modules.bar.audioformat
import qs.modules.bar.workspaces
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.theme
import qs.modules.widgets.launcher
import "../island"

Item {
    id: root

    anchors.fill: parent
    required property ShellScreen screen
    focus: true

    Component.onCompleted: {
        Visibilities.registerIsland(root.screen.name, root);
    }

    Component.onDestruction: {
        Visibilities.unregisterIsland(root.screen.name, root);
    }

    readonly property int islandHeight: 36
    readonly property int triggerHeight: 4
    readonly property real cornerRadius: Styling.radius(4)

    // Current morphing state: "collapsed" | "dashboard" | "power" | "sound" | "wifi" | "stats" | "apps" | "projects"
    property string currentMode: "collapsed"
    readonly property bool isExpanded: currentMode !== "collapsed"
    readonly property bool islandActive: isExpanded

    function collapse() {
        root.currentMode = "collapsed";
        GlobalStates.clearLauncherState();
        GlobalStates.clearProjectPickerState();
        if (Visibilities.currentActiveModule === "launcher" || Visibilities.currentActiveModule === "powermenu" || Visibilities.currentActiveModule === "system-monitor" || Visibilities.currentActiveModule === "dashboard") {
            Visibilities.setActiveModule("");
        }
    }

    function expand(mode: string) {
        root.currentMode = mode || "dashboard";
    }

    readonly property bool fullscreenOnScreen: false
    readonly property bool compositorHide: NiriService.overviewOpen

    readonly property var activeWorkspace: {
        const list = NiriService.workspaces.values;
        if (!list || list.length === 0)
            return null;
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            if (ws && ws.output === root.screen.name && ws.active)
                return ws;
        }
        return null;
    }

    readonly property int activeWorkspaceWindows: activeWorkspace?.windows ?? 0
    readonly property bool hasActiveWindows: activeWorkspaceWindows > 0

    readonly property bool isHovered: triggerHoverHandler.hovered || islandHoverHandler.hovered
    property bool debounceActive: false

    readonly property bool shouldBeRevealed: {
        if (root.isExpanded)
            return true;
        if (compositorHide)
            return false;
        if (!hasActiveWindows)
            return true;
        if (isHovered || debounceActive)
            return true;
        return false;
    }

    readonly property int targetY: shouldBeRevealed ? 0 : -islandHeight
    readonly property bool isFullyRetracted: !shouldBeRevealed && (islandContainer.y <= -islandHeight + 0.5)
    readonly property bool hitboxExpanded: root.isExpanded || shouldBeRevealed || !isFullyRetracted

    readonly property int targetWidth: {
        if (root.isExpanded) {
            return Math.min(400, root.width - 32);
        }
        return Math.min(Math.max(collapsedRow.implicitWidth + 28, 200), Math.min(Math.max(0, root.width - 16), 740));
    }

    readonly property int targetHeight: {
        switch (root.currentMode) {
        case "dashboard":
            return dashboardView.implicitHeight;
        case "power":
            return powerView.implicitHeight;
        case "sound":
            return soundView.implicitHeight;
        case "wifi":
            return wifiView.implicitHeight;
        case "bluetooth":
            return bluetoothView.implicitHeight;
        case "stats":
            return statsView.implicitHeight;
        case "alerts":
            return alertsView.implicitHeight;
        case "wallpapers":
            return wallpapersView.implicitHeight;
        case "battery":
            return batteryView.implicitHeight;
        case "weather":
            return weatherView.implicitHeight;
        case "apps":
        case "projects":
            return launcherViewWrapper.implicitHeight + 16;
        default:
            return root.islandHeight;
        }
    }

    onCurrentModeChanged: {
        GlobalStates.islandOpen = (currentMode !== "collapsed");
        GlobalStates.islandLauncherOpen = (currentMode === "apps" || currentMode === "projects");
        GlobalStates.islandStatsOpen = (currentMode === "stats");

        if (currentMode === "apps" || currentMode === "projects") {
            GlobalStates.launcherMode = currentMode;
            Qt.callLater(() => {
                launcherView.forceActiveFocus();
                launcherView.focusSearchInput();
            });
        } else if (currentMode !== "collapsed") {
            Qt.callLater(() => {
                root.forceActiveFocus();
            });
        }
    }

    Connections {
        target: GlobalStates
        function onLauncherModeChanged() {
            if (root.currentMode === "apps" || root.currentMode === "projects") {
                root.currentMode = GlobalStates.launcherMode;
            }
        }
    }

    // Contract properties for BarContent & UnifiedShellPanel
    readonly property int barTargetHeight: islandHeight
    readonly property int baseOuterMargin: 0
    readonly property int totalBarHeight: islandHeight
    readonly property bool timerInputActive: false
    readonly property bool dashboardInputActive: root.isExpanded

    property alias barHitbox: activeBarHitbox

    // Stable dummy item for dashboardHitbox contract
    Item {
        id: dummyDashboardHitbox
        width: 0
        height: 0
        visible: false
    }
    readonly property Item dashboardHitbox: dummyDashboardHitbox

    Timer {
        id: exitDebounceTimer
        interval: 200
        repeat: false
        onTriggered: {
            root.debounceActive = false;
        }
    }

    onIsHoveredChanged: {
        if (isHovered) {
            exitDebounceTimer.stop();
            root.debounceActive = false;
        } else if (root.hasActiveWindows && !root.isExpanded) {
            root.debounceActive = true;
            exitDebounceTimer.restart();
        }
    }

    // Keyboard handling when expanded
    Keys.onPressed: event => {
        if (root.currentMode === "power") {
            if (event.key === Qt.Key_Left) {
                powerView.moveSelection(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                powerView.moveSelection(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                powerView.activateSelected();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.currentMode = "dashboard";
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Escape) {
            if (root.currentMode === "apps" || root.currentMode === "projects") {
                root.collapse();
            } else if (root.currentMode !== "dashboard" && root.currentMode !== "collapsed") {
                root.currentMode = "dashboard";
            } else {
                root.collapse();
            }
            event.accepted = true;
        }
    }

    // Wayland input mask hitbox
    Item {
        id: activeBarHitbox
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: islandContainer.width
        height: root.isExpanded ? islandContainer.height : (root.hitboxExpanded ? root.islandHeight : root.triggerHeight)
    }

    // Slim top-edge trigger hitbox along upper bezel
    Item {
        id: triggerStrip
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: islandContainer.width
        height: root.triggerHeight

        HoverHandler {
            id: triggerHoverHandler
        }
    }

    // Island body
    Item {
        id: islandContainer
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.targetWidth
        height: root.targetHeight
        y: root.targetY

        Behavior on y {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: root.shouldBeRevealed ? 220 : 180
                easing.type: root.shouldBeRevealed ? Easing.OutCubic : Easing.InCubic
            }
        }

        Behavior on width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        opacity: (root.shouldBeRevealed || islandContainer.y > -root.islandHeight) ? 1.0 : 0.0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: islandHoverHandler
        }

        // Island body container
        StyledRect {
            id: islandBody
            anchors.fill: parent
            variant: "pane"
            backgroundOpacity: 1.0
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: root.cornerRadius
            bottomRightRadius: root.cornerRadius
            enableShadow: root.isExpanded
            enableBorder: true
            clip: true

            MouseArea {
                anchors.fill: parent
                // Absorb clicks on empty space so backdropArea doesn't collapse the island
                onClicked: {}
            }

            // ═══════════════════════════════════════════════════════════════
            // COLLAPSED BAR STATE (Image 0)
            // ═══════════════════════════════════════════════════════════════
            Item {
                id: collapsedView
                anchors.fill: parent
                visible: !root.isExpanded || opacity > 0
                opacity: root.currentMode === "collapsed" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                RowLayout {
                    id: collapsedRow
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 8

                    // Context info: Window / Media title (text only, no outside bar image)
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: 200
                        implicitWidth: Math.min(contextText.implicitWidth, 200)
                        implicitHeight: Math.max(contextText.implicitHeight, 20)

                        Text {
                            id: contextText
                            anchors.fill: parent
                            text: {
                                if (MprisController.isPlaying && MprisController.activePlayer) {
                                    return MprisController.activePlayer.trackTitle || "Playing";
                                }
                                return NiriService.focusedClient?.title || "Desktop";
                            }
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.bold: true
                            color: (MprisController.isPlaying && MprisController.activePlayer) ? Colors.primary : Colors.overBackground
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.expand("apps")
                        }
                    }

                    // Separator
                    Text {
                        text: "|"
                        color: Colors.overSurfaceVariant
                        opacity: 0.5
                        font.pixelSize: Styling.fontSize(-2)
                        renderType: Text.NativeRendering
                    }

                    // Time clickable (clean, seamless - no sub-section pill)
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: dateTimeRow.implicitHeight
                        implicitWidth: dateTimeRow.implicitWidth

                        RowLayout {
                            id: dateTimeRow
                            anchors.fill: parent
                            spacing: 6

                            Text {
                                text: Qt.formatTime(new Date(), Config.bar?.use12hFormat ? "hh:mm ap" : "HH:mm")
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-1)
                                font.bold: true
                                color: dateMouse.containsMouse ? Colors.primary : Colors.overBackground
                                renderType: Text.NativeRendering
                            }
                        }

                        MouseArea {
                            id: dateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expand("dashboard")
                        }
                    }

                    // Separator
                    Text {
                        text: "|"
                        color: Colors.overSurfaceVariant
                        opacity: 0.5
                        font.pixelSize: Styling.fontSize(-2)
                        renderType: Text.NativeRendering
                    }

                    // Workspaces switcher shared with the default bar
                    NonchalantTaskbar {
                        Layout.alignment: Qt.AlignVCenter
                        bar: root
                        showBackground: false
                    }

                    // Separator before battery
                    Text {
                        visible: Battery.available
                        text: "|"
                        color: Colors.overSurfaceVariant
                        opacity: 0.5
                        font.pixelSize: Styling.fontSize(-2)
                        renderType: Text.NativeRendering
                    }

                    // Battery indicator (flat, when available)
                    Item {
                        visible: Battery.available
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: batteryRow.implicitWidth
                        implicitHeight: batteryRow.implicitHeight

                        RowLayout {
                            id: batteryRow
                            anchors.fill: parent
                            spacing: 4

                            Text {
                                text: Battery.getBatteryIcon()
                                font.family: Icons.font
                                font.pixelSize: 13
                                color: Battery.statusColor()
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: Math.round(Battery.percentage) + "%"
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: true
                                color: Battery.statusColor()
                                renderType: Text.NativeRendering
                            }
                        }

                        MouseArea {
                            id: batteryBarMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expand("battery")
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 1: MAIN DASHBOARD HUB
            // ═══════════════════════════════════════════════════════════════
            IslandDashboard {
                id: dashboardView
                screen: root.screen
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                visible: root.currentMode === "dashboard" || opacity > 0
                opacity: root.currentMode === "dashboard" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                onOpenPower: root.currentMode = "power"
                onOpenSound: root.currentMode = "sound"
                onOpenWifi: root.currentMode = "wifi"
                onOpenBluetooth: root.currentMode = "bluetooth"
                onOpenStats: root.currentMode = "stats"
                onOpenAlerts: root.currentMode = "alerts"
                onOpenWallpapers: root.currentMode = "wallpapers"
                onOpenBattery: root.currentMode = "battery"
                onOpenWeather: root.currentMode = "weather"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 2: POWER MENU (Image 0)
            // ═══════════════════════════════════════════════════════════════
            IslandPowerPanel {
                id: powerView
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                visible: root.currentMode === "power" || opacity > 0
                opacity: root.currentMode === "power" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                onBackRequested: root.currentMode = "dashboard"
                onActionTriggered: root.collapse()
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 3: SOUND PANEL (Image 1)
            // ═══════════════════════════════════════════════════════════════
            IslandSoundPanel {
                id: soundView
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                visible: root.currentMode === "sound" || opacity > 0
                opacity: root.currentMode === "sound" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 4: WI-FI NETWORKS PANEL (Image 2)
            // ═══════════════════════════════════════════════════════════════
            IslandWifiPanel {
                id: wifiView
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                visible: root.currentMode === "wifi" || opacity > 0
                opacity: root.currentMode === "wifi" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 4.5: BLUETOOTH PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandBluetoothPanel {
                id: bluetoothView
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                visible: root.currentMode === "bluetooth" || opacity > 0
                opacity: root.currentMode === "bluetooth" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 5: SYSTEM RESOURCES STATS PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandStatsPanel {
                id: statsView
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                visible: root.currentMode === "stats" || opacity > 0
                opacity: root.currentMode === "stats" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 5.5: ALERTS PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandAlertsPanel {
                id: alertsView
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                visible: root.currentMode === "alerts" || opacity > 0
                opacity: root.currentMode === "alerts" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 5.6: WALLPAPERS PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandWallpaperPanel {
                id: wallpapersView
                screen: root.screen
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                visible: root.currentMode === "wallpapers" || opacity > 0
                opacity: root.currentMode === "wallpapers" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 5.7: BATTERY & POWER PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandBatteryPanel {
                id: batteryView
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                visible: root.currentMode === "battery" || opacity > 0
                opacity: root.currentMode === "battery" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 5.8: WEATHER PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandWeatherPanel {
                id: weatherView
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                visible: root.currentMode === "weather" || opacity > 0
                opacity: root.currentMode === "weather" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 6: APP LAUNCHER & PROJECT PICKER
            // ═══════════════════════════════════════════════════════════════
            Item {
                id: launcherViewWrapper
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                implicitHeight: launcherView.implicitHeight
                visible: (root.currentMode === "apps" || root.currentMode === "projects") || opacity > 0
                opacity: (root.currentMode === "apps" || root.currentMode === "projects") ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: 150 }
                }

                LauncherView {
                    id: launcherView
                    anchors.fill: parent
                }
            }
        }
    }
}
