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

    // Current morphing state: "collapsed" | "notification" | "osd" | "dashboard" | "power" | "sound" | "mic" | "wifi" | "stats" | "apps" | "projects"
    property string currentMode: "collapsed"
    property string previousMode: "collapsed"
    property bool openedFromHidden: false
    property bool retractingToHidden: false
    readonly property bool isExpanded: currentMode !== "collapsed" && !retractingToHidden
    readonly property bool islandActive: isExpanded && currentMode !== "notification" && currentMode !== "osd"

    function finishRetraction() {
        if (root.retractingToHidden) {
            slideUpAnim.stop();
            retractFinishTimer.stop();
            barHoverAnim.stop();
            root.openedFromHidden = false;
            root.currentMode = "collapsed";
            root.retractingToHidden = false;
            root.containerY = -root.islandHeight;
        }
    }

    function collapse() {
        if (root.currentMode === "collapsed" && !root.retractingToHidden && Visibilities.currentActiveModule === "")
            return;

        islandOsdTimer.stop();
        root.debounceActive = false;
        exitDebounceTimer.stop();
        if (slideDownAnim.running)
            slideDownAnim.stop();
        if (barHoverAnim.running)
            barHoverAnim.stop();

        GlobalStates.clearLauncherState();
        GlobalStates.clearProjectPickerState();
        if (Visibilities.currentActiveModule !== "") {
            Visibilities.currentActiveModule = "";
        }
        Visibilities.closeActiveBarPopup();
        FocusGrabManager.clearTopGrab();

        if (root.openedFromHidden && !root.barAlwaysVisible && root.currentMode !== "collapsed") {
            root.retractingToHidden = true;
            GlobalStates.islandOpen = false;
            GlobalStates.islandLauncherOpen = false;
            GlobalStates.islandStatsOpen = false;
            retractFinishTimer.restart();
            slideUpAnim.stop();
            slideUpAnim.from = root.containerY;
            slideUpAnim.to = -root.targetHeight;
            slideUpAnim.start();
            return;
        }

        root.retractingToHidden = false;
        retractFinishTimer.stop();
        slideUpAnim.stop();
        root.openedFromHidden = false;
        root.currentMode = "collapsed";
        root.containerY = root.shouldBeRevealed ? 0 : -root.islandHeight;
    }

    function expand(mode: string) {
        FocusGrabManager.clearTopGrab();
        Visibilities.closeActiveBarPopup();
        if (root.retractingToHidden) {
            root.retractingToHidden = false;
            retractFinishTimer.stop();
            slideUpAnim.stop();
        }
        if (barHoverAnim.running)
            barHoverAnim.stop();
        if (slideDownAnim.running)
            slideDownAnim.stop();

        const wasHidden = !root.barNormallyVisible && root.currentMode === "collapsed";
        if (root.currentMode === "collapsed") {
            root.openedFromHidden = !root.barNormallyVisible;
        }
        if (root.currentMode !== mode) {
            root.previousMode = root.currentMode;
        }
        root.currentMode = mode || "dashboard";
        if (wasHidden) {
            slideDownAnim.from = -root.targetHeight;
            slideDownAnim.to = 0;
            slideDownAnim.start();
        } else {
            root.containerY = 0;
        }
        if (root.currentMode === "dashboard") {
            NetworkService.update();
            BluetoothService.updateStatus();
        }
    }

    function isWindowTouchingTop(win): bool {
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
        if (list && list.length > 0) {
            for (let i = 0; i < list.length; i++) {
                const ws = list[i];
                if (ws && (ws.output === root.screen.name || (!ws.output && Quickshell.screens.length <= 1)) && ws.active)
                    return ws;
            }
        }
        if (NiriService.focusedWorkspace && (NiriService.focusedWorkspace.output === root.screen.name || Quickshell.screens.length <= 1))
            return NiriService.focusedWorkspace;
        return null;
    }

    readonly property int activeWorkspaceWindows: {
        if (!activeWorkspace)
            return 0;
        return NiriService.windowsForWorkspace(activeWorkspace.id).length;
    }
    readonly property bool hasActiveWindows: activeWorkspaceWindows > 0
    readonly property bool hasWindowTouchingTop: {
        const ws = root.activeWorkspace;
        if (ws) {
            const windows = NiriService.windowsForWorkspace(ws.id);
            if (windows && windows.length > 0) {
                for (let i = 0; i < windows.length; i++) {
                    if (isWindowTouchingTop(windows[i]))
                        return true;
                }
                return false;
            }
        }
        if (root.screenFocusedClient && isWindowTouchingTop(root.screenFocusedClient))
            return true;
        return false;
    }
    readonly property bool hasNotifications: !Notifications.silent && Notifications.popupList && Notifications.popupList.length > 0

    onHasNotificationsChanged: {
        if (hasNotifications) {
            if (root.currentMode === "collapsed" || root.retractingToHidden) {
                root.expand("notification");
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

    readonly property bool isHovered: triggerHoverHandler.hovered || (islandHoverHandler.hovered && root.currentMode === "collapsed" && !root.retractingToHidden)
    property bool debounceActive: false
    readonly property bool isPinned: Config.bar?.pinned ?? false

    readonly property bool barAlwaysVisible: !NiriService.overviewOpen && (root.isPinned || !hasWindowTouchingTop)
    readonly property bool barNormallyVisible: barAlwaysVisible || isHovered || debounceActive

    readonly property bool shouldBeRevealed: {
        if (root.retractingToHidden)
            return false;
        if (currentMode === "osd")
            return true;
        if (root.isExpanded)
            return true;
        return barNormallyVisible;
    }

    readonly property int targetY: shouldBeRevealed ? 0 : -targetHeight
    readonly property bool isFullyRetracted: !shouldBeRevealed && (islandContainer.y <= -targetHeight + 1.0)
    readonly property bool hitboxExpanded: root.isExpanded || shouldBeRevealed || !isFullyRetracted

    property real containerY: shouldBeRevealed ? 0 : -islandHeight

    NumberAnimation {
        id: slideDownAnim
        target: root
        property: "containerY"
        duration: root.morphDuration
        easing.type: Easing.OutBack
        easing.overshoot: 1.25
    }

    NumberAnimation {
        id: slideUpAnim
        target: root
        property: "containerY"
        duration: root.morphCollapseDuration
        easing.type: Easing.InCubic
        onFinished: {
            root.finishRetraction();
        }
    }

    NumberAnimation {
        id: barHoverAnim
        target: root
        property: "containerY"
        duration: root.shouldBeRevealed ? root.morphDuration : root.morphCollapseDuration
        easing.type: root.shouldBeRevealed ? Easing.OutBack : Easing.InCubic
        easing.overshoot: 1.25
    }

    onShouldBeRevealedChanged: {
        if (root.isExpanded || root.retractingToHidden)
            return;
        barHoverAnim.stop();
        barHoverAnim.from = root.containerY;
        barHoverAnim.to = root.shouldBeRevealed ? 0 : -root.islandHeight;
        barHoverAnim.start();
    }

    readonly property int morphDuration: Config.animDuration > 0 ? Math.max(240, Math.round(Config.animDuration * 0.85)) : 0
    readonly property int morphCollapseDuration: Config.animDuration > 0 ? Math.max(180, Math.round(Config.animDuration * 0.7)) : 0
    readonly property int contentFadeInDuration: Config.animDuration > 0 ? Math.max(160, Math.round(Config.animDuration * 0.60)) : 0
    readonly property int contentFadeOutDuration: Config.animDuration > 0 ? Math.max(80, Math.round(Config.animDuration * 0.28)) : 0

    readonly property int targetWidth: {
        if (root.isExpanded || root.retractingToHidden) {
            if (root.currentMode === "osd") {
                return Math.min(270, root.width - 32);
            }
            if (root.currentMode === "wallpapers") {
                return Math.min(540, root.width - 32);
            }
            return Math.min(420, root.width - 32);
        }
        return Math.min(Math.max(collapsedRow.implicitWidth + collapsedRow.anchors.leftMargin + collapsedRow.anchors.rightMargin, 200), Math.max(200, root.width - 32));
    }

    readonly property int targetHeight: {
        switch (root.currentMode) {
        case "osd":
            return osdView.implicitHeight;
        case "notification":
            return (notificationView.implicitHeight > 0) ? notificationView.implicitHeight : root.islandHeight;
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
        case "calendar":
            return calendarView.implicitHeight;
        case "apps":
        case "projects":
            return launcherViewWrapper.implicitHeight;
        default:
            return root.islandHeight;
        }
    }

    onCurrentModeChanged: {
        FocusGrabManager.clearTopGrab();
        Visibilities.closeActiveBarPopup();
        GlobalStates.islandOpen = (currentMode !== "collapsed" && currentMode !== "notification" && currentMode !== "osd" && !root.retractingToHidden);
        GlobalStates.islandLauncherOpen = ((currentMode === "apps" || currentMode === "projects") && !root.retractingToHidden);
        GlobalStates.islandStatsOpen = (currentMode === "stats" && !root.retractingToHidden);

        if (root.previousMode === "collapsed" && root.currentMode !== "collapsed") {
            root.openedFromHidden = !root.barAlwaysVisible;
        }
        root.previousMode = root.currentMode;

        if (currentMode === "apps" || currentMode === "projects") {
            GlobalStates.launcherMode = currentMode;
            Qt.callLater(() => {
                launcherView.forceActiveFocus();
                launcherView.focusSearchInput();
            });
        } else if (currentMode !== "collapsed" && currentMode !== "notification" && currentMode !== "osd") {
            Qt.callLater(() => {
                root.forceActiveFocus();
            });
        } else if (currentMode === "collapsed" && root.hasNotifications) {
            Qt.callLater(() => {
                if (root.currentMode === "collapsed" && root.hasNotifications) {
                    root.openedFromHidden = !root.barAlwaysVisible;
                    root.currentMode = "notification";
                }
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

    // OSD Morphing State & Connections
    property string osdIndicator: "volume"
    property real osdValue: 0.0
    property bool osdMuted: false

    Timer {
        id: islandOsdTimer
        interval: 2200
        repeat: false
        onTriggered: {
            if (root.currentMode === "osd") {
                root.collapse();
            }
        }
    }

    Timer {
        id: retractFinishTimer
        interval: root.morphCollapseDuration + 60
        repeat: false
        onTriggered: {
            root.finishRetraction();
        }
    }

    function triggerOsd(indicator: string, value: real, muted: bool) {
        root.osdIndicator = indicator;
        root.osdValue = value;
        root.osdMuted = muted;
        if (root.currentMode === "collapsed" || root.currentMode === "osd") {
            root.expand("osd");
            islandOsdTimer.restart();
        }
    }

    Connections {
        target: Audio
        function onVolumeChanged(volume, muted, node) {
            root.triggerOsd("volume", volume, muted);
        }
        function onMicVolumeChanged(volume, muted, node) {
            root.triggerOsd("mic", volume, muted);
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged(value, screen) {
            if (!screen || !root.screen || screen.name === root.screen.name || Brightness.syncBrightness) {
                root.triggerOsd("brightness", value, false);
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
        } else if (root.hasWindowTouchingTop && !root.isExpanded && !root.isPinned && !root.retractingToHidden) {
            root.debounceActive = true;
            exitDebounceTimer.restart();
        }
    }

    // Keyboard handling when expanded
    Keys.onPressed: event => {
        if (root.retractingToHidden) {
            event.accepted = true;
            return;
        }
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
                root.expand("dashboard");
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Escape) {
            if (Visibilities.activeBarPopup && Visibilities.activeBarPopup.isOpen) {
                Visibilities.closeActiveBarPopup();
                event.accepted = true;
                return;
            }
            if (root.currentMode === "apps" || root.currentMode === "projects") {
                root.collapse();
            } else if (root.currentMode === "notification") {
                notificationView.dismissCurrent();
            } else if (root.currentMode !== "dashboard" && root.currentMode !== "collapsed") {
                root.expand("dashboard");
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
        width: Math.max(200, collapsedRow.implicitWidth + 28)
        height: root.triggerHeight

        HoverHandler {
            id: triggerHoverHandler
            enabled: root.currentMode === "collapsed" && !root.retractingToHidden
        }
    }

    // Island body
    Item {
        id: islandContainer
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.targetWidth
        height: root.targetHeight
        y: root.containerY

        Behavior on width {
            enabled: Config.animDuration > 0 && (root.shouldBeRevealed || root.isExpanded) && !root.retractingToHidden
            NumberAnimation {
                duration: root.isExpanded ? root.morphDuration : root.morphCollapseDuration
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutQuad
                easing.overshoot: 1.28
            }
        }

        Behavior on height {
            enabled: Config.animDuration > 0 && (root.shouldBeRevealed || root.isExpanded) && !root.retractingToHidden
            NumberAnimation {
                duration: root.isExpanded ? root.morphDuration : root.morphCollapseDuration
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutQuad
                easing.overshoot: 1.28
            }
        }

        opacity: {
            if (root.shouldBeRevealed)
                return 1.0;
            if (root.retractingToHidden && islandContainer.y > -root.targetHeight)
                return 1.0;
            return 0.0;
        }
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuad
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
            bottomLeftRadius: (root.currentMode === "osd") ? (root.targetHeight / 2) : ((root.isExpanded || root.retractingToHidden) ? root.cornerRadius : (root.islandHeight / 2))
            bottomRightRadius: (root.currentMode === "osd") ? (root.targetHeight / 2) : ((root.isExpanded || root.retractingToHidden) ? root.cornerRadius : (root.islandHeight / 2))

            Behavior on bottomLeftRadius {
                enabled: Config.animDuration > 0 && (root.shouldBeRevealed || root.isExpanded) && !root.retractingToHidden
                NumberAnimation {
                    duration: (root.isExpanded || root.retractingToHidden) ? root.morphDuration : root.morphCollapseDuration
                    easing.type: root.isExpanded ? Easing.OutBack : Easing.OutQuad
                    easing.overshoot: 1.28
                }
            }

            Behavior on bottomRightRadius {
                enabled: Config.animDuration > 0 && (root.shouldBeRevealed || root.isExpanded) && !root.retractingToHidden
                NumberAnimation {
                    duration: (root.isExpanded || root.retractingToHidden) ? root.morphDuration : root.morphCollapseDuration
                    easing.type: root.isExpanded ? Easing.OutBack : Easing.OutQuad
                    easing.overshoot: 1.28
                }
            }
            enableShadow: root.isExpanded || root.retractingToHidden
            enableBorder: true
            clip: true

            MouseArea {
                anchors.fill: parent
                // Absorb clicks on empty space so backdropArea doesn't collapse the island,
                // but dismiss any open dropdown/bar popup.
                onClicked: {
                    FocusGrabManager.clearTopGrab();
                    Visibilities.closeActiveBarPopup();
                }
            }

            // ═══════════════════════════════════════════════════════════════
            // COLLAPSED BAR STATE (Image 0)
            // ═══════════════════════════════════════════════════════════════
            Item {
                id: collapsedView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, collapsedRow.implicitWidth + collapsedRow.anchors.leftMargin + collapsedRow.anchors.rightMargin)
                height: root.islandHeight
                visible: opacity > 0
                opacity: (root.currentMode === "collapsed" && !root.retractingToHidden) ? 1.0 : 0.0
                enabled: root.currentMode === "collapsed" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "collapsed" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "collapsed" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                RowLayout {
                    id: collapsedRow
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 8

                    // Context info: Window / Media title with live fluid shader progress fill
                    Item {
                        id: contextContainer
                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: 200
                        implicitWidth: Math.min(fluidContextText.implicitWidth, 200)
                        implicitHeight: Math.max(fluidContextText.implicitHeight, 20)
                        scale: contextMouse.pressed ? 0.94 : 1.0

                        Behavior on scale {
                            enabled: (Config.animDuration ?? 0) > 0
                            NumberAnimation {
                                duration: contextMouse.pressed ? 80 : 250
                                easing.type: contextMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                easing.overshoot: 1.4
                            }
                        }

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
                            id: contextMouse
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
                        scale: dateMouse.pressed ? 0.94 : 1.0

                        Behavior on scale {
                            enabled: (Config.animDuration ?? 0) > 0
                            NumberAnimation {
                                duration: dateMouse.pressed ? 80 : 250
                                easing.type: dateMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                easing.overshoot: 1.4
                            }
                        }

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
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    root.expand("calendar");
                                } else {
                                    root.expand("dashboard");
                                }
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
                        scale: alertsMouse.pressed ? 0.90 : 1.0

                        Behavior on scale {
                            enabled: (Config.animDuration ?? 0) > 0
                            NumberAnimation {
                                duration: alertsMouse.pressed ? 80 : 250
                                easing.type: alertsMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                easing.overshoot: 1.4
                            }
                        }

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
                        implicitWidth: 22
                        implicitHeight: 22
                        Layout.alignment: Qt.AlignVCenter

                        StyledRect {
                            anchors.fill: parent
                            radius: 11
                            variant: pinMouse.containsMouse ? "focus" : "transparent"
                            scale: pinMouse.pressed ? 0.92 : 1.0
                            Behavior on scale {
                                enabled: (Config.animDuration ?? 0) > 0
                                NumberAnimation {
                                    duration: pinMouse.pressed ? 80 : 250
                                    easing.type: pinMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                    easing.overshoot: 1.4
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.isPinned ? Icons.pin : Icons.unpin
                                font.family: Icons.font
                                font.pixelSize: 13
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
                            description: root.isPinned ? "Autohide disabled (reserves window space)" : "Keep island visible and reserve window space"
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE -1: LIVE OSD BANNER (Volume / Brightness / Mic)
            // ═══════════════════════════════════════════════════════════════
            IslandOsdBanner {
                id: osdView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                indicator: root.osdIndicator
                value: root.osdValue
                muted: root.osdMuted
                visible: opacity > 0
                opacity: root.currentMode === "osd" ? 1.0 : 0.0
                enabled: root.currentMode === "osd" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: (root.currentMode === "osd") ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: (root.currentMode === "osd") ? Easing.OutCubic : Easing.OutQuad
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
                visible: opacity > 0
                opacity: (!Notifications.silent && root.currentMode === "notification" && root.hasNotifications && notificationView.activeNotif !== null) ? 1.0 : 0.0
                enabled: !Notifications.silent && root.currentMode === "notification" && root.hasNotifications && notificationView.activeNotif !== null && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: (root.currentMode === "notification") ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: (root.currentMode === "notification") ? Easing.OutCubic : Easing.OutQuad
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
                visible: opacity > 0
                opacity: root.currentMode === "dashboard" ? 1.0 : 0.0
                enabled: root.currentMode === "dashboard" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "dashboard" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "dashboard" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onOpenPower: root.expand("power")
                onOpenSound: root.expand("sound")
                onOpenMic: root.expand("mic")
                onOpenWifi: root.expand("wifi")
                onOpenBluetooth: root.expand("bluetooth")
                onOpenStats: root.expand("stats")
                onOpenAlerts: root.expand("alerts")
                onOpenWallpapers: root.expand("wallpapers")
                onOpenBattery: root.expand("battery")
                onOpenWeather: root.expand("weather")
                onOpenMedia: root.expand("media")
                onOpenCalendar: root.expand("calendar")
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
                visible: opacity > 0
                opacity: root.currentMode === "power" ? 1.0 : 0.0
                enabled: root.currentMode === "power" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "power" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "power" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
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
                visible: opacity > 0
                opacity: root.currentMode === "sound" ? 1.0 : 0.0
                enabled: root.currentMode === "sound" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "sound" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "sound" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
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
                visible: opacity > 0
                opacity: root.currentMode === "mic" ? 1.0 : 0.0
                enabled: root.currentMode === "mic" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "mic" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "mic" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
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
                visible: opacity > 0
                opacity: root.currentMode === "wifi" ? 1.0 : 0.0
                enabled: root.currentMode === "wifi" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "wifi" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "wifi" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
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
                visible: opacity > 0
                opacity: root.currentMode === "bluetooth" ? 1.0 : 0.0
                enabled: root.currentMode === "bluetooth" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "bluetooth" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "bluetooth" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
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
                visible: opacity > 0
                opacity: root.currentMode === "stats" ? 1.0 : 0.0
                enabled: root.currentMode === "stats" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "stats" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "stats" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
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
                visible: opacity > 0
                opacity: root.currentMode === "alerts" ? 1.0 : 0.0
                enabled: root.currentMode === "alerts" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "alerts" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "alerts" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
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
                visible: opacity > 0
                opacity: root.currentMode === "wallpapers" ? 1.0 : 0.0
                enabled: root.currentMode === "wallpapers" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "wallpapers" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "wallpapers" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
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
                visible: opacity > 0
                opacity: root.currentMode === "battery" ? 1.0 : 0.0
                enabled: root.currentMode === "battery" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "battery" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "battery" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
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
                visible: opacity > 0
                opacity: root.currentMode === "weather" ? 1.0 : 0.0
                enabled: root.currentMode === "weather" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "weather" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "weather" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
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
                visible: opacity > 0
                opacity: root.currentMode === "media" ? 1.0 : 0.0
                enabled: root.currentMode === "media" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "media" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "media" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
            }

            // ═══════════════════════════════════════════════════════════════
            // EXPANDED STATE 5.95: DEDICATED CALENDAR & DATE TIME
            // ═══════════════════════════════════════════════════════════════
            IslandCalendarPanel {
                id: calendarView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: implicitHeight
                visible: opacity > 0
                opacity: root.currentMode === "calendar" ? 1.0 : 0.0
                enabled: root.currentMode === "calendar" && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.currentMode === "calendar" ? root.contentFadeInDuration : root.contentFadeOutDuration
                        easing.type: root.currentMode === "calendar" ? Easing.OutCubic : Easing.OutQuad
                    }
                }

                onBackRequested: root.expand("dashboard")
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
                visible: opacity > 0
                opacity: (root.currentMode === "apps" || root.currentMode === "projects") ? 1.0 : 0.0
                enabled: (root.currentMode === "apps" || root.currentMode === "projects") && !root.retractingToHidden

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: (root.currentMode === "apps" || root.currentMode === "projects") ? root.contentFadeInDuration : root.contentFadeOutDuration
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
