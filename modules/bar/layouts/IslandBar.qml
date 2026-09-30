pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
    // Set only while switching mode on a hidden island: nothing is on screen,
    // so geometry jumps to the new mode and the pinch alone animates it in.
    property bool snapGeometry: false
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
        root.animateReveal(root.shouldBeRevealed ? 0 : -root.islandHeight);
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
        root.snapGeometry = wasHidden;
        root.currentMode = mode || "dashboard";
        root.snapGeometry = false;
        if (wasHidden) {
            slideDownAnim.from = -root.targetHeight;
            slideDownAnim.to = 0;
            slideDownAnim.start();
        } else {
            root.animateReveal(0);
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

    readonly property bool isHovered: revealHoverHandler.hovered && root.currentMode === "collapsed" && !root.retractingToHidden
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
    readonly property bool isFullyRetracted: !shouldBeRevealed && root.revealProgress <= 0.01
    readonly property bool hitboxExpanded: root.isExpanded || shouldBeRevealed || !isFullyRetracted

    property real containerY: shouldBeRevealed ? 0 : -islandHeight

    NumberAnimation {
        id: slideDownAnim
        target: root
        property: "containerY"
        duration: root.morphDuration
        easing.type: Easing.OutBack
        easing.overshoot: root.morphOvershoot
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
        easing.overshoot: root.morphOvershoot
    }

    onShouldBeRevealedChanged: {
        if (root.isExpanded || root.retractingToHidden)
            return;
        root.animateReveal(root.shouldBeRevealed ? 0 : -root.islandHeight);
    }

    // Motion tokens. Expansion is a long, softly overshooting spring; collapse
    // is a monotonic decelerating curve. Content enters a beat after the body
    // starts morphing so it lands on an already-growing surface instead of
    // popping in clipped.
    readonly property int morphDuration: Config.animDuration > 0 ? Math.max(360, Math.round(Config.animDuration * 1.3)) : 0
    readonly property int morphCollapseDuration: Config.animDuration > 0 ? Math.max(240, Math.round(Config.animDuration * 0.9)) : 0
    readonly property int contentFadeInDuration: Config.animDuration > 0 ? Math.max(200, Math.round(Config.animDuration * 0.8)) : 0
    readonly property int contentFadeOutDuration: Config.animDuration > 0 ? Math.max(90, Math.round(Config.animDuration * 0.35)) : 0
    readonly property int contentEnterDelay: Math.round(morphDuration * 0.22)
    readonly property real morphOvershoot: 1.12
    readonly property real pageDrift: 6

    // Concave fillets that join the body to the top screen edge.
    readonly property real earRadius: Math.min(root.cornerRadius, root.islandHeight / 2)

    // The reveal is a pinch out of the top edge, not a slide. containerY
    // (driven by the slide animations) maps to revealProgress, which grows the
    // body's height, width, corner radius and ears together from a narrow nub
    // at the bezel. Positive containerY is spring overshoot; it stretches the
    // body downward instead of detaching it from the screen edge.
    readonly property real revealProgress: root.targetHeight > 0 ? Math.max(0, 1 + root.containerY / root.targetHeight) : 0
    readonly property real revealClamped: Math.min(1, root.revealProgress)
    readonly property real revealStretch: Math.max(0, root.containerY)
    readonly property real pinchWidthFactor: 0.28
    readonly property real revealWidthFactor: root.pinchWidthFactor + (1 - root.pinchWidthFactor) * root.revealClamped
    // Content arrives over the last part of the reveal so the pinch reads as
    // a clean shape first.
    readonly property real contentReveal: Math.max(0, Math.min(1, (root.revealProgress - 0.4) / 0.6))

    readonly property real bodyBottomRadiusTarget: {
        if (root.currentMode === "osd")
            return root.targetHeight / 2;
        return (root.isExpanded || root.retractingToHidden) ? root.cornerRadius : root.islandHeight / 2;
    }
    property real bodyBottomRadius: bodyBottomRadiusTarget
    Behavior on bodyBottomRadius {
        enabled: Config.animDuration > 0 && (root.shouldBeRevealed || root.isExpanded) && !root.retractingToHidden && !root.snapGeometry
        NumberAnimation {
            duration: root.isExpanded ? root.morphDuration : root.morphCollapseDuration
            easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: root.morphOvershoot
        }
    }

    // Moves the reveal toward `target` with the hover curve (spring in,
    // monotonic out) instead of snapping.
    function animateReveal(target: real) {
        barHoverAnim.stop();
        if (Config.animDuration <= 0 || Math.abs(root.containerY - target) < 0.5) {
            root.containerY = target;
            return;
        }
        barHoverAnim.from = root.containerY;
        barHoverAnim.to = target;
        barHoverAnim.start();
    }

    // Inverted corner ("ear"): the region between the screen edge, the island
    // side and a quarter circle tangent to both. Left ear sits left of the body.
    component IslandEar: Shape {
        id: ear

        property bool mirrored: false
        property real size: 0
        property color fillColor: "transparent"

        width: size
        height: size
        visible: size > 0.5
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: ear.fillColor
            strokeWidth: -1
            startX: ear.mirrored ? 0 : ear.size
            startY: 0

            PathLine {
                x: ear.mirrored ? 0 : ear.size
                y: ear.size
            }
            PathArc {
                x: ear.mirrored ? ear.size : 0
                y: 0
                radiusX: ear.size
                radiusY: ear.size
                direction: ear.mirrored ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }

    // Shared enter/leave choreography for every island surface. Entering
    // waits a beat, then fades in while drifting down and settling from a
    // slight shrink; leaving is a quick monotonic fade that drifts back up.
    component IslandPage: Item {
        id: page

        required property bool active

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.targetWidth
        height: root.targetHeight
        transformOrigin: Item.Top
        // The active page stays visible even while its fade-in is still
        // paused at opacity 0: invisible items cannot take focus, so gating on
        // opacity made opening a page drop its keyboard focus.
        visible: page.active || opacity > 0.001
        enabled: page.active && !root.retractingToHidden

        property real drift: -root.pageDrift
        opacity: 0
        scale: 0.96
        transform: Translate {
            y: page.drift
        }

        states: State {
            name: "shown"
            when: page.active
            PropertyChanges {
                page.opacity: 1
                page.scale: 1
                page.drift: 0
            }
        }

        transitions: [
            Transition {
                to: "shown"
                enabled: Config.animDuration > 0
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.contentEnterDelay
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            duration: root.contentFadeInDuration
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            properties: "scale,drift"
                            duration: root.morphDuration
                            easing.type: Easing.OutBack
                            easing.overshoot: root.morphOvershoot
                        }
                    }
                }
            },
            Transition {
                from: "shown"
                enabled: Config.animDuration > 0
                NumberAnimation {
                    properties: "opacity,scale,drift"
                    duration: root.contentFadeOutDuration
                    easing.type: Easing.OutQuad
                }
            }
        ]
    }

    readonly property int targetWidth: {
        if (root.isExpanded || root.retractingToHidden) {
            if (root.currentMode === "osd") {
                return Math.min(300, root.width - 32);
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
            launcherView.focusSearchInput();
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
            const inLauncher = root.currentMode === "apps" || root.currentMode === "projects";
            if (inLauncher && root.currentMode !== GlobalStates.launcherMode)
                root.expand(GlobalStates.launcherMode);
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

    property bool suppressOsd: false

    Timer {
        id: suppressOsdTimer
        interval: 400
        repeat: false
        onTriggered: {
            root.suppressOsd = false;
        }
    }

    function suppressOsdTemporarily() {
        root.suppressOsd = true;
        suppressOsdTimer.restart();
    }

    function triggerOsd(indicator: string, value: real, muted: bool) {
        if (root.suppressOsd && root.currentMode === "collapsed")
            return;
        root.osdIndicator = indicator;
        root.osdValue = value;
        root.osdMuted = muted;
        if (root.currentMode === "collapsed" || root.currentMode === "osd") {
            if (root.currentMode === "collapsed") {
                root.expand("osd");
            } else if (root.retractingToHidden) {
                root.retractingToHidden = false;
                retractFinishTimer.stop();
                slideUpAnim.stop();
            }
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
        width: islandContainer.width
        height: root.isExpanded ? islandContainer.height : (root.hitboxExpanded ? islandContainer.height : root.triggerHeight)
    }

    // Island body
    Item {
        id: islandContainer
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: root.targetWidth
        height: root.targetHeight
        visible: root.revealProgress > 0.001

        Behavior on width {
            enabled: Config.animDuration > 0 && (root.shouldBeRevealed || root.isExpanded) && !root.retractingToHidden && !root.snapGeometry
            NumberAnimation {
                duration: root.isExpanded ? root.morphDuration : root.morphCollapseDuration
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: root.morphOvershoot
            }
        }

        Behavior on height {
            enabled: Config.animDuration > 0 && (root.shouldBeRevealed || root.isExpanded) && !root.retractingToHidden && !root.snapGeometry
            NumberAnimation {
                duration: root.isExpanded ? root.morphDuration : root.morphCollapseDuration
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: root.morphOvershoot
            }
        }

        // Ears hug the body's current edges and scale with the pinch, so the
        // island is pulled out of the bezel as one continuous shape.
        IslandEar {
            x: islandBody.x - size
            y: 0
            size: root.earRadius * root.revealClamped
            fillColor: islandBody.color
        }

        IslandEar {
            mirrored: true
            x: islandBody.x + islandBody.width
            y: 0
            size: root.earRadius * root.revealClamped
            fillColor: islandBody.color
        }

        StyledRect {
            id: islandBody
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * root.revealWidthFactor
            height: parent.height * root.revealClamped + root.revealStretch
            variant: "pane"
            backgroundOpacity: 1.0
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: root.bodyBottomRadius * root.revealClamped
            bottomRightRadius: root.bodyBottomRadius * root.revealClamped
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

            // Full-size content plane. It rides the leading edge of the pinch
            // and is clipped by the body, so panels never reflow mid-reveal.
            Item {
                id: pageLayer
                anchors.horizontalCenter: parent.horizontalCenter
                y: islandContainer.height * (root.revealClamped - 1)
                width: islandContainer.width
                height: islandContainer.height
                opacity: root.contentReveal

                // ═══════════════════════════════════════════════════════════════
                // COLLAPSED BAR STATE (Image 0)
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "collapsed" && !root.retractingToHidden

                    Item {
                        id: collapsedView
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width, collapsedRow.implicitWidth + collapsedRow.anchors.leftMargin + collapsedRow.anchors.rightMargin)
                        height: root.islandHeight

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
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE -1: LIVE OSD BANNER (Volume / Brightness / Mic)
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "osd"

                    IslandOsdBanner {
                        id: osdView
                        bar: root
                        width: parent.width
                        indicator: root.osdIndicator
                        value: root.osdValue
                        muted: root.osdMuted
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 0: LIVE NOTIFICATION BANNER (Dynamic Island Morph)
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: !Notifications.silent && root.currentMode === "notification" && root.hasNotifications && notificationView.activeNotif !== null

                    IslandNotificationBanner {
                        id: notificationView
                        width: parent.width

                        onDismissRequested: {
                            root.collapse();
                        }
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 1: MAIN DASHBOARD HUB
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "dashboard"

                    IslandDashboard {
                        id: dashboardView
                        screen: root.screen
                        width: parent.width
                        height: implicitHeight

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
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 2: POWER MENU (Image 0)
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "power"

                    IslandPowerPanel {
                        id: powerView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                        onActionTriggered: root.collapse()
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 3: SOUND PANEL (Image 1)
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "sound"

                    IslandSoundPanel {
                        id: soundView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 3.5: MICROPHONE PANEL
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "mic"

                    IslandMicPanel {
                        id: micView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 4: WI-FI NETWORKS PANEL (Image 2)
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "wifi"

                    IslandWifiPanel {
                        id: wifiView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 4.5: BLUETOOTH PANEL
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "bluetooth"

                    IslandBluetoothPanel {
                        id: bluetoothView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 5: SYSTEM RESOURCES STATS PANEL
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "stats"

                    IslandStatsPanel {
                        id: statsView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 5.5: ALERTS PANEL
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "alerts"

                    IslandAlertsPanel {
                        id: alertsView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 5.6: WALLPAPERS PANEL
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "wallpapers"

                    IslandWallpaperPanel {
                        id: wallpapersView
                        screen: root.screen
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 5.7: BATTERY & POWER PANEL
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "battery"

                    IslandBatteryPanel {
                        id: batteryView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 5.8: WEATHER PANEL
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "weather"

                    IslandWeatherPanel {
                        id: weatherView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 5.9: DEDICATED MEDIA CENTER
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "media"

                    IslandMediaCenterPanel {
                        id: mediaCenterView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 5.95: DEDICATED CALENDAR & DATE TIME
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "calendar"

                    IslandCalendarPanel {
                        id: calendarView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ═══════════════════════════════════════════════════════════════
                // EXPANDED STATE 6: APP LAUNCHER & PROJECT PICKER
                // ═══════════════════════════════════════════════════════════════
                IslandPage {
                    active: root.currentMode === "apps" || root.currentMode === "projects"

                    Item {
                        id: launcherViewWrapper
                        width: parent.width
                        height: implicitHeight
                        implicitHeight: launcherView.implicitHeight + 16

                        LauncherView {
                            id: launcherView
                            anchors.fill: parent
                            anchors.margins: 8
                        }
                    }
                }
            }
        }
    }

    // Single hover zone for the autohide reveal: the top-edge trigger strip
    // while hidden, growing with the visible body as it pinches out. It sits
    // above everything and is non-blocking, so controls underneath still get
    // hover. Separate handlers on the strip and the body lost hover to the
    // collapsed row's MouseAreas as they slid under a stationary cursor
    // mid-reveal (hover is delivered top-down and hover-enabled MouseAreas
    // stop it), so the island flickered open, closed, open.
    Item {
        id: hoverZone
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        z: 1000
        width: Math.max(200, collapsedRow.implicitWidth + 28, islandBody.width)
        height: Math.max(root.triggerHeight, islandBody.height)

        HoverHandler {
            id: revealHoverHandler
            blocking: false
        }
    }
}
