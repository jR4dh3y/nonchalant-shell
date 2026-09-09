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
import ".."

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
    readonly property int triggerHeight: 8
    readonly property real cornerRadius: Styling.radius(4)

    // Current morphing state: "collapsed" | "notification" | "dashboard" | "power" | "sound" | "mic" | "wifi" | "stats" | "apps" | "projects"
    property string currentMode: "collapsed"
    property string previousMode: "collapsed"
    readonly property bool isExpanded: currentMode !== "collapsed"
    readonly property bool islandActive: isExpanded && currentMode !== "notification"

    function collapse() {
        root.currentMode = "collapsed";
        GlobalStates.clearLauncherState();
        GlobalStates.clearProjectPickerState();
        if (Visibilities.currentActiveModule === "launcher" || Visibilities.currentActiveModule === "powermenu" || Visibilities.currentActiveModule === "system-monitor" || Visibilities.currentActiveModule === "dashboard") {
            Visibilities.setActiveModule("");
        }
    }

    function expand(mode: string) {
        if (root.currentMode !== mode) {
            root.previousMode = root.currentMode;
        }
        root.currentMode = mode || "dashboard";
        if (root.currentMode === "dashboard") {
            NetworkService.update();
            BluetoothService.updateStatus();
        }
    }

    function isWindowTouchingTop(win: var): bool {
        if (!win)
            return false;
        if (win.floating) {
            const y = (win.at && win.at.length > 1) ? Number(win.at[1]) : 0;
            const h = (win.size && win.size.length > 1) ? Number(win.size[1]) : 0;
            return (y + h > 0) && (y <= (root.islandHeight + 8));
        }
        // Tiled windows in Niri attach to the top of the workspace view
        return true;
    }

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

    readonly property int activeWorkspaceWindows: {
        if (!activeWorkspace)
            return 0;
        return NiriService.windowsForWorkspace(activeWorkspace.id).length;
    }
    readonly property bool hasActiveWindows: activeWorkspaceWindows > 0
    readonly property bool hasWindowTouchingTop: {
        if (!activeWorkspace)
            return false;
        const windows = NiriService.windowsForWorkspace(activeWorkspace.id);
        if (!windows || windows.length === 0)
            return false;
        for (let i = 0; i < windows.length; i++) {
            if (isWindowTouchingTop(windows[i]))
                return true;
        }
        return false;
    }
    readonly property bool hasNotifications: !Notifications.silent && Notifications.popupList && Notifications.popupList.length > 0

    onHasNotificationsChanged: {
        if (hasNotifications) {
            if (root.currentMode === "collapsed") {
                root.currentMode = "notification";
            }
        } else {
            if (root.currentMode === "notification") {
                root.collapse();
            }
        }
    }

    property string formattedTime: ""

    Timer {
        id: clockTimer
        interval: 1000
        running: !SuspendManager.isSuspending
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            const format = Config.bar?.use12hFormat ? "hh:mm ap" : "HH:mm";
            root.formattedTime = Qt.formatTime(now, format);
        }
    }

    readonly property string batteryIcon: {
        let _ = Battery.percentage;
        let __ = Battery.isPluggedIn;
        let ___ = Battery.chargeState;
        return Battery.getBatteryIcon();
    }
    readonly property color batteryColor: {
        let _ = Battery.percentage;
        let __ = Battery.isPluggedIn;
        return Battery.statusColor();
    }

    readonly property bool audioMuted: Audio.sink?.audio?.muted ?? false
    readonly property real audioVolume: Audio.sink?.audio?.volume ?? 0.0

    readonly property int alertsCount: {
        if (Notifications.silent) return 0;
        let count = 0;
        const list = Notifications.appNameList;
        if (!list) return 0;
        for (let i = 0; i < list.length; i++) {
            const grp = Notifications.groupsByAppName[list[i]];
            if (grp?.notifications)
                count += grp.notifications.length;
        }
        return count;
    }

    readonly property var screenFocusedClient: {
        if (NiriService.focusedClient && (NiriService.focusedClient.output === root.screen.name || NiriService.focusedClient.monitor === root.screen.name))
            return NiriService.focusedClient;
        if (root.activeWorkspace && root.activeWorkspace.activeWindowId !== null) {
            const list = NiriService.clients.values;
            if (list) {
                const found = list.find(c => Number(c.id) === Number(root.activeWorkspace.activeWindowId));
                if (found) return found;
            }
        }
        return null;
    }

    readonly property bool isMediaPlaying: MprisController.isPlaying && MprisController.activePlayer !== null

    readonly property string contextLabel: {
        if (root.isMediaPlaying) {
            return MprisController.trackTitle || "Playing";
        }
        return root.screenFocusedClient?.title || "Desktop";
    }

    readonly property bool isHovered: triggerHoverHandler.hovered || islandHoverHandler.hovered
    property bool debounceActive: false
    readonly property bool isPinned: Config.bar?.pinned ?? false

    readonly property bool shouldBeRevealed: {
        if (root.isExpanded)
            return true;
        if (NiriService.overviewOpen)
            return false;
        if (root.isPinned)
            return true;
        if (hasNotifications)
            return true;
        if (isHovered || debounceActive)
            return true;
        if (!hasWindowTouchingTop)
            return true;
        return false;
    }

    readonly property int targetY: shouldBeRevealed ? 0 : -islandHeight
    readonly property bool isFullyRetracted: !shouldBeRevealed && (islandContainer.y <= -islandHeight + 0.5)
    readonly property bool hitboxExpanded: root.isExpanded || shouldBeRevealed || !isFullyRetracted

    readonly property int morphDuration: Config.animDuration > 0 ? Math.max(220, Math.round(Config.animDuration * 0.9)) : 0
    readonly property int morphCollapseDuration: Config.animDuration > 0 ? Math.max(180, Math.round(Config.animDuration * 0.75)) : 0

    readonly property int targetWidth: {
        if (root.isExpanded) {
            if (root.currentMode === "wallpapers") {
                return Math.min(540, root.width - 32);
            }
            return Math.min(420, root.width - 32);
        }
        return Math.min(Math.max(collapsedRow.implicitWidth + 28, 200), Math.min(Math.max(0, root.width - 16), 740));
    }

    readonly property int targetHeight: {
        switch (root.currentMode) {
        case "notification":
            return (root.hasNotifications && notificationView.activeNotif) ? notificationView.implicitHeight : root.islandHeight;
        case "dashboard":
            return dashboardView.implicitHeight;
        case "power":
            return powerView.implicitHeight;
        case "sound":
            return soundView.implicitHeight;
        case "mic":
            return micView.implicitHeight;
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
        case "media":
            return mediaCenterView.implicitHeight;
        case "apps":
        case "projects":
            return launcherViewWrapper.implicitHeight;
        default:
            return root.islandHeight;
        }
    }

    onCurrentModeChanged: {
        GlobalStates.islandOpen = (currentMode !== "collapsed" && currentMode !== "notification");
        GlobalStates.islandLauncherOpen = (currentMode === "apps" || currentMode === "projects");
        GlobalStates.islandStatsOpen = (currentMode === "stats");

        if (currentMode === "apps" || currentMode === "projects") {
            GlobalStates.launcherMode = currentMode;
            Qt.callLater(() => {
                launcherView.forceActiveFocus();
                launcherView.focusSearchInput();
            });
        } else if (currentMode !== "collapsed" && currentMode !== "notification") {
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

    Connections {
        target: Notifications
        function onSilentChanged() {
            if (Notifications.silent && root.currentMode === "notification") {
                root.collapse();
            }
        }
    }

    // Contract properties for BarContent & UnifiedShellPanel
    readonly property int barTargetHeight: islandHeight
    readonly property int baseOuterMargin: 0
    readonly property int totalBarHeight: islandHeight
    readonly property bool timerInputActive: false
    readonly property bool dashboardInputActive: islandActive && currentMode === "dashboard"

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
        } else if (root.hasWindowTouchingTop && !root.isExpanded && !root.isPinned) {
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
            } else if (root.currentMode === "notification") {
                notificationView.dismissCurrent();
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
        width: root.targetWidth
        height: root.isExpanded ? root.targetHeight : (root.hitboxExpanded ? root.islandHeight : root.triggerHeight)
    }

    // Slim top-edge trigger hitbox along upper bezel
    Item {
        id: triggerStrip
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: root.targetWidth
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
                duration: root.shouldBeRevealed ? 240 : 180
                easing.type: root.shouldBeRevealed ? Easing.OutCubic : Easing.InCubic
            }
        }

        Behavior on width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: root.isExpanded ? root.morphDuration : root.morphCollapseDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: root.isExpanded ? root.morphDuration : root.morphCollapseDuration
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
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: root.islandHeight
                visible: !root.isExpanded || opacity > 0
                opacity: root.currentMode === "collapsed" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.isExpanded ? 100 : Math.round(root.morphCollapseDuration * 0.7)
                        easing.type: root.isExpanded ? Easing.OutQuad : Easing.OutCubic
                    }
                }

                RowLayout {
                    id: collapsedRow
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 8

                    // Context info: Window / Media title with live fluid shader progress fill
                    Item {
                        id: contextContainer
                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: 200
                        implicitWidth: Math.min(fluidContextText.implicitWidth, 200)
                        implicitHeight: Math.max(fluidContextText.implicitHeight, 20)

                        FluidTextProgress {
                            id: fluidContextText
                            anchors.fill: parent
                            text: root.contextLabel
                            fontFamily: Config.theme.font
                            pixelSize: Styling.fontSize(-1)
                            bold: true
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            progress: (root.isMediaPlaying && MprisController.length > 0) ? MprisController.progress : 0.0
                            isPlaying: root.isMediaPlaying
                            baseColor: Colors.overBackground
                            fillColor: Colors.primary
                            highlightColor: Colors.primaryFixed ?? Colors.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (root.isMediaPlaying)
                                    root.expand("media");
                                else
                                    root.expand("apps");
                            }
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
                                text: root.formattedTime
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

                    // Separator before controls
                    Text {
                        text: "|"
                        color: Colors.overSurfaceVariant
                        opacity: 0.5
                        font.pixelSize: Styling.fontSize(-2)
                        renderType: Text.NativeRendering
                    }

                    // Dynamic Material Symbols status icons (Volume, Brightness, Battery)
                    IslandStatusIcons {
                        bar: root
                    }

                    // Separator before alerts
                    Text {
                        visible: !Notifications.silent && (root.alertsCount > 0 || root.hasNotifications)
                        text: "|"
                        color: Colors.overSurfaceVariant
                        opacity: 0.5
                        font.pixelSize: Styling.fontSize(-2)
                        renderType: Text.NativeRendering
                    }

                    // Alerts indicator
                    Item {
                        visible: !Notifications.silent && (root.alertsCount > 0 || root.hasNotifications)
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: alertsRow.implicitWidth
                        implicitHeight: alertsRow.implicitHeight

                        RowLayout {
                            id: alertsRow
                            anchors.fill: parent
                            spacing: 4

                            Text {
                                text: Icons.bell
                                font.family: Icons.font
                                font.pixelSize: 13
                                color: root.hasNotifications ? Colors.primary : (alertsMouse.containsMouse ? Colors.primary : Colors.overBackground)
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: String(root.alertsCount)
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: true
                                color: root.hasNotifications ? Colors.primary : (alertsMouse.containsMouse ? Colors.primary : Colors.overBackground)
                                renderType: Text.NativeRendering
                            }
                        }

                        MouseArea {
                            id: alertsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expand("alerts")
                        }
                    }

                    // Separator before pin button
                    Text {
                        text: "|"
                        color: Colors.overSurfaceVariant
                        opacity: 0.5
                        font.pixelSize: Styling.fontSize(-2)
                        renderType: Text.NativeRendering
                    }

                    // Dynamic Island pin toggle button
                    Item {
                        id: pinBtn
                        implicitWidth: 26
                        implicitHeight: 26
                        Layout.alignment: Qt.AlignVCenter

                        StyledRect {
                            anchors.fill: parent
                            radius: 13
                            variant: pinMouse.containsMouse ? "focus" : "transparent"
                            scale: pinMouse.pressed ? 0.88 : (pinMouse.containsMouse ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                            Text {
                                anchors.centerIn: parent
                                text: root.isPinned ? Icons.pin : Icons.unpin
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: root.isPinned ? Colors.primary : (pinMouse.containsMouse ? Colors.primary : Colors.overBackground)
                                opacity: root.isPinned ? 1.0 : (pinMouse.containsMouse ? 1.0 : 0.7)
                                renderType: Text.NativeRendering
                            }
                        }

                        MouseArea {
                            id: pinMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (Config.bar) {
                                    Config.bar.pinned = !root.isPinned;
                                }
                            }
                        }

                        StyledToolTip {
                            show: pinMouse.containsMouse
                            tooltipText: root.isPinned ? "Unpin Island" : "Pin Island"
                            description: root.isPinned ? "Autohide disabled" : "Keep island visible over windows"
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 0: LIVE NOTIFICATION BANNER (Dynamic Island Morph)
            // ═══════════════════════════════════════════════════════════════
            IslandNotificationBanner {
                id: notificationView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                visible: !Notifications.silent && (((root.currentMode === "notification" && root.hasNotifications && notificationView.activeNotif !== null)) || opacity > 0)
                opacity: (!Notifications.silent && root.currentMode === "notification" && root.hasNotifications && notificationView.activeNotif !== null) ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "notification" ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: root.currentMode === "notification" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onDismissRequested: {
                    root.collapse();
                }
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 1: MAIN DASHBOARD HUB
            // ═══════════════════════════════════════════════════════════════
            IslandDashboard {
                id: dashboardView
                screen: root.screen
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "dashboard" || opacity > 0
                opacity: root.currentMode === "dashboard" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "dashboard" ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: root.currentMode === "dashboard" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onOpenPower: root.currentMode = "power"
                onOpenSound: root.currentMode = "sound"
                onOpenMic: root.currentMode = "mic"
                onOpenWifi: root.currentMode = "wifi"
                onOpenBluetooth: root.currentMode = "bluetooth"
                onOpenStats: root.currentMode = "stats"
                onOpenAlerts: root.currentMode = "alerts"
                onOpenWallpapers: root.currentMode = "wallpapers"
                onOpenBattery: root.currentMode = "battery"
                onOpenWeather: root.currentMode = "weather"
                onOpenMedia: root.currentMode = "media"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 2: POWER MENU (Image 0)
            // ═══════════════════════════════════════════════════════════════
            IslandPowerPanel {
                id: powerView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "power" || opacity > 0
                opacity: root.currentMode === "power" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "power" ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: root.currentMode === "power" ? Easing.OutCubic : Easing.OutQuad
                    }
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
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "sound" || opacity > 0
                opacity: root.currentMode === "sound" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "sound" ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: root.currentMode === "sound" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 3.5: MICROPHONE PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandMicPanel {
                id: micView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "mic" || opacity > 0
                opacity: root.currentMode === "mic" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "mic" ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: root.currentMode === "mic" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 4: WI-FI NETWORKS PANEL (Image 2)
            // ═══════════════════════════════════════════════════════════════
            IslandWifiPanel {
                id: wifiView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "wifi" || opacity > 0
                opacity: root.currentMode === "wifi" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "wifi" ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: root.currentMode === "wifi" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 4.5: BLUETOOTH PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandBluetoothPanel {
                id: bluetoothView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "bluetooth" || opacity > 0
                opacity: root.currentMode === "bluetooth" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "bluetooth" ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: root.currentMode === "bluetooth" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 5: SYSTEM RESOURCES STATS PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandStatsPanel {
                id: statsView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "stats" || opacity > 0
                opacity: root.currentMode === "stats" ? 1.0 : 0.0
                scale: root.currentMode === "stats" ? 1.0 : 0.94
                y: root.currentMode === "stats" ? 0 : -8
                transformOrigin: Item.Top

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "stats" ? root.morphDuration : root.morphCollapseDuration
                        easing.type: root.currentMode === "stats" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                Behavior on scale {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "stats" ? root.morphDuration : root.morphCollapseDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "stats" ? root.morphDuration : root.morphCollapseDuration
                        easing.type: Easing.OutCubic
                    }
                }

                onBackRequested: {
                    if (root.previousMode === "dashboard") {
                        root.currentMode = "dashboard";
                    } else {
                        root.collapse();
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 5.5: ALERTS PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandAlertsPanel {
                id: alertsView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "alerts" || opacity > 0
                opacity: root.currentMode === "alerts" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "alerts" ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: root.currentMode === "alerts" ? Easing.OutCubic : Easing.OutQuad
                    }
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
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "wallpapers" || opacity > 0
                opacity: root.currentMode === "wallpapers" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "wallpapers" ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: root.currentMode === "wallpapers" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 5.7: BATTERY & POWER PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandBatteryPanel {
                id: batteryView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "battery" || opacity > 0
                opacity: root.currentMode === "battery" ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "battery" ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: root.currentMode === "battery" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.currentMode = "dashboard"
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 5.8: WEATHER PANEL
            // ═══════════════════════════════════════════════════════════════
            IslandWeatherPanel {
                id: weatherView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "weather" || opacity > 0
                opacity: root.currentMode === "weather" ? 1.0 : 0.0
                scale: root.currentMode === "weather" ? 1.0 : 0.94
                y: root.currentMode === "weather" ? 0 : -8
                transformOrigin: Item.Top

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "weather" ? root.morphDuration : root.morphCollapseDuration
                        easing.type: root.currentMode === "weather" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                Behavior on scale {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "weather" ? root.morphDuration : root.morphCollapseDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "weather" ? root.morphDuration : root.morphCollapseDuration
                        easing.type: Easing.OutCubic
                    }
                }

                onBackRequested: {
                    if (root.previousMode === "dashboard") {
                        root.currentMode = "dashboard";
                    } else {
                        root.collapse();
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 5.9: DEDICATED MEDIA CENTER
            // ═══════════════════════════════════════════════════════════════
            IslandMediaCenterPanel {
                id: mediaCenterView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: root.currentMode === "media" || opacity > 0
                opacity: root.currentMode === "media" ? 1.0 : 0.0
                scale: root.currentMode === "media" ? 1.0 : 0.94
                y: root.currentMode === "media" ? 0 : -8
                transformOrigin: Item.Top

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "media" ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: root.currentMode === "media" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                Behavior on scale {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "media" ? root.morphDuration : root.morphCollapseDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "media" ? root.morphDuration : root.morphCollapseDuration
                        easing.type: Easing.OutCubic
                    }
                }

                onBackRequested: {
                    if (root.previousMode === "dashboard") {
                        root.currentMode = "dashboard";
                    } else {
                        root.collapse();
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 6: APP LAUNCHER & PROJECT PICKER
            // ═══════════════════════════════════════════════════════════════
            Item {
                id: launcherViewWrapper
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                implicitHeight: launcherView.implicitHeight + 16
                visible: (root.currentMode === "apps" || root.currentMode === "projects") || opacity > 0
                opacity: (root.currentMode === "apps" || root.currentMode === "projects") ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: (root.currentMode === "apps" || root.currentMode === "projects") ? Math.round(root.morphDuration * 0.75) : 100
                        easing.type: (root.currentMode === "apps" || root.currentMode === "projects") ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                LauncherView {
                    id: launcherView
                    anchors.fill: parent
                    anchors.margins: 8
                }
            }
        }
    }
}
