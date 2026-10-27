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
import qs.modules.services.compositor
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
        root.containerY = root.shouldBeRevealed ? 0 : -(root.pillHeight + root.topMargin + 10);
        Visibilities.registerIsland(root.screen.name, root);
    }

    Component.onDestruction: {
        Visibilities.unregisterIsland(root.screen.name, root);
    }

    readonly property int pillHeight: 36
    readonly property int topMargin: 8
    readonly property int triggerHeight: 8
    readonly property real pillRadius: pillHeight / 2
    readonly property real panelRadius: Styling.radius(4)

    // Current morphing state: "collapsed" | "notification" | "osd" | "dashboard" | "power" | "sound" | "mic" | "wifi" | "stats" | "apps" | "projects"
    property string currentMode: "collapsed"
    property string previousMode: "collapsed"
    property bool openedFromHidden: false
    property bool retractingToHidden: false
    property bool snapGeometry: false
    readonly property bool isExpanded: currentMode !== "collapsed" && !retractingToHidden
    readonly property bool islandActive: isExpanded && currentMode !== "notification" && currentMode !== "osd"

    property bool isMorphing: false

    onIsMorphingChanged: {
        if (!root.isMorphing && root.isExpanded) {
            root.targetCardWidth = root.targetWidth;
            root.targetCardHeight = root.targetHeight;
            root.targetCardX = Math.round((root.width - root.targetWidth) / 2);
        }
    }

    Timer {
        id: morphCollapseTimer
        interval: Motion.collapseDuration + 40
        repeat: false
        onTriggered: {
            root.isMorphing = false;
        }
    }

    Timer {
        id: morphExpandTimer
        interval: Motion.expandDuration + 40
        repeat: false
        onTriggered: {
            root.isMorphing = false;
        }
    }

    function finishRetraction() {
        if (root.retractingToHidden) {
            slideUpAnim.stop();
            retractFinishTimer.stop();
            barHoverAnim.stop();
            root.openedFromHidden = false;
            root.currentMode = "collapsed";
            root.retractingToHidden = false;
            root.isMorphing = false;
            morphCollapseTimer.stop();
            morphExpandTimer.stop();
            root.targetCardX = root.sourcePillLeftInRoot;
            root.targetCardWidth = root.sourcePillWidth;
            root.targetCardHeight = root.pillHeight;
            root.targetCardRadius = root.pillRadius;
            root.containerY = -(root.pillHeight + root.topMargin + 10);
        }
    }

    function collapse() {
        if (root.currentMode === "collapsed" && !root.retractingToHidden && Visibilities.currentActiveModule === "")
            return;

        islandOsdTimer.stop();
        launcherView.cancelFocusRetry();
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
            root.forceActiveFocus();
            GlobalStates.islandOpen = false;
            GlobalStates.islandLauncherOpen = false;
            GlobalStates.islandStatsOpen = false;
            retractFinishTimer.restart();
            slideUpAnim.stop();
            slideUpAnim.from = root.containerY;
            slideUpAnim.to = -(root.targetHeight + root.topMargin + 10);
            slideUpAnim.start();
            return;
        }

        root.retractingToHidden = false;
        retractFinishTimer.stop();
        slideUpAnim.stop();
        const wasFromHidden = root.openedFromHidden;
        root.openedFromHidden = false;
        // Raise isMorphing first so the card stays opaque, then leave the
        // expanded mode before retargeting the card so its Behaviors pick the
        // monotonic collapse curve instead of the opening spring.
        root.isMorphing = !wasFromHidden;
        root.currentMode = "collapsed";
        if (!wasFromHidden) {
            root.snapGeometry = false;
            root.targetCardX = root.sourcePillLeftInRoot;
            root.targetCardWidth = root.sourcePillWidth;
            root.targetCardHeight = root.pillHeight;
            root.targetCardRadius = root.pillRadius;
            morphExpandTimer.stop();
            morphCollapseTimer.restart();
        } else {
            root.isMorphing = false;
            morphExpandTimer.stop();
        }
        root.animateReveal(root.shouldBeRevealed ? 0 : -(root.pillHeight + root.topMargin + 10));
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

        // Only a card that is fully off screen slides in from a hidden bar. One
        // still shrinking into its pill keeps morphing from where it is.
        const wasHidden = !root.barNormallyVisible && root.currentMode === "collapsed" && !root.isMorphing;
        if (root.currentMode === "collapsed") {
            root.openedFromHidden = wasHidden;
        }
        if (root.currentMode !== mode) {
            root.previousMode = root.currentMode;
        }
        morphCollapseTimer.stop();
        morphExpandTimer.stop();

        root.updateSourcePill(mode || "dashboard");

        const nextMode = mode || "dashboard";
        const targetW = root.calculateTargetWidth(nextMode);
        const targetH = root.calculateTargetHeight(nextMode);
        const centerX = Math.round((root.width - targetW) / 2);
        // The card is still on screen while a collapse morph shrinks it, so a
        // reopen continues from where it is instead of jumping to the pill.
        const cardOnScreen = root.currentMode !== "collapsed" || root.isMorphing;

        // Snapped geometry is applied with the Behaviors off, then the flag is
        // cleared in the same turn so later changes animate again.
        root.snapGeometry = wasHidden || !cardOnScreen;
        if (wasHidden) {
            root.targetCardX = centerX;
            root.targetCardWidth = targetW;
            root.targetCardHeight = targetH;
            root.targetCardRadius = root.panelRadius;
        } else if (!cardOnScreen) {
            // Start the card on the pill that opened it, then grow from there.
            root.targetCardX = root.sourcePillLeftInRoot;
            root.targetCardWidth = root.sourcePillWidth;
            root.targetCardHeight = root.pillHeight;
            root.targetCardRadius = root.pillRadius;
        }
        root.isMorphing = !wasHidden;
        root.currentMode = nextMode;
        root.snapGeometry = false;

        if (wasHidden) {
            slideDownAnim.from = -(targetH + root.topMargin + 10);
            slideDownAnim.to = 0;
            slideDownAnim.start();
        } else {
            morphExpandTimer.restart();
            root.targetCardX = centerX;
            root.targetCardWidth = targetW;
            root.targetCardHeight = targetH;
            root.targetCardRadius = root.panelRadius;
            root.animateReveal(0);
        }

        if (root.currentMode === "dashboard") {
            NetworkService.update();
            BluetoothService.updateStatus();
        }
    }

    readonly property CompositorWorkspace activeWorkspace: CompositorService.activeWorkspaceForOutput(root.screen.name)
    readonly property int activeWorkspaceWindows: activeWorkspace?.windows ?? 0
    readonly property bool hasActiveWindows: activeWorkspaceWindows > 0
    readonly property bool hasWindowTouchingTop: CompositorService.hasWindowAtTop(root.screen.name, root.pillHeight + root.topMargin + 8)
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
    property string formattedDate: ""

    Timer {
        id: clockTimer
        interval: 1000
        running: !SuspendManager.isSuspending
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            const format = (Config.bar && Config.bar.use12hFormat) ? "hh:mm ap" : "HH:mm";
            root.formattedTime = Qt.formatTime(now, format);
            root.formattedDate = Qt.formatDate(now, "ddd d MMM");
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

    readonly property bool audioMuted: (Audio.sink && Audio.sink.audio) ? Audio.sink.audio.muted : false
    readonly property real audioVolume: (Audio.sink && Audio.sink.audio) ? Audio.sink.audio.volume : 0.0

    readonly property int alertsCount: {
        if (Notifications.silent) return 0;
        let count = 0;
        const list = Notifications.appNameList;
        if (!list) return 0;
        for (let i = 0; i < list.length; i++) {
            const grp = Notifications.groupsByAppName[list[i]];
            if (grp && grp.notifications)
                count += grp.notifications.length;
        }
        return count;
    }

    readonly property CompositorWindow screenFocusedClient: CompositorService.activeWindowForOutput(root.screen.name)

    readonly property bool isMediaPlaying: MprisController.isPlaying && MprisController.activePlayer !== null
    readonly property string contextLabel: {
        if (root.isMediaPlaying) {
            return MprisController.trackTitle || "Playing";
        }
        return (root.screenFocusedClient && root.screenFocusedClient.title) ? root.screenFocusedClient.title : "Desktop";
    }

    readonly property bool isHovered: revealHoverHandler.hovered && root.currentMode === "collapsed" && !root.retractingToHidden
    property bool debounceActive: false
    readonly property bool isPinned: (Config.bar && Config.bar.pinned) ? true : false

    readonly property bool barAlwaysVisible: !CompositorService.overviewOpen && (root.isPinned || !hasWindowTouchingTop)
    readonly property bool barNormallyVisible: barAlwaysVisible || isHovered || debounceActive

    readonly property bool shouldBeRevealed: {
        if (root.retractingToHidden)
            return false;
        if (currentMode === "osd")
            return true;
        if (root.isExpanded || root.isMorphing)
            return true;
        return barNormallyVisible || inlineOsdActive;
    }

    readonly property bool isFullyRetracted: !shouldBeRevealed && root.revealProgress <= 0.01
    readonly property bool hitboxExpanded: root.isExpanded || shouldBeRevealed || !isFullyRetracted

    property real containerY: -(pillHeight + topMargin + 10)

    NumberAnimation {
        id: slideDownAnim
        target: root
        property: "containerY"
        duration: Motion.expandDuration
        easing.type: Easing.OutBack
        easing.overshoot: Motion.overshoot
    }

    NumberAnimation {
        id: slideUpAnim
        target: root
        property: "containerY"
        duration: Motion.collapseDuration
        easing.type: Easing.InCubic
        onFinished: {
            root.finishRetraction();
        }
    }

    NumberAnimation {
        id: barHoverAnim
        target: root
        property: "containerY"
        duration: root.shouldBeRevealed ? Motion.expandDuration : Motion.collapseDuration
        easing.type: root.shouldBeRevealed ? Easing.OutBack : Easing.InCubic
        easing.overshoot: Motion.overshoot
    }

    onShouldBeRevealedChanged: {
        if (root.isExpanded || root.retractingToHidden)
            return;
        root.animateReveal(root.shouldBeRevealed ? 0 : -(root.pillHeight + root.topMargin + 10));
    }

    readonly property real revealProgress: (root.targetHeight + root.topMargin) > 0 ? Math.max(0, 1 + root.containerY / (root.targetHeight + root.topMargin)) : 0
    readonly property real revealClamped: Math.min(1, root.revealProgress)
    readonly property real contentReveal: Math.max(0, Math.min(1, (root.revealProgress - 0.4) / 0.6))

    function animateReveal(target: real) {
        barHoverAnim.stop();
        if (!Motion.enabled || Math.abs(root.containerY - target) < 0.5) {
            root.containerY = target;
            return;
        }
        barHoverAnim.from = root.containerY;
        barHoverAnim.to = target;
        barHoverAnim.start();
    }

    // Shared enter/leave choreography for every surface. Each page lays out at
    // its own final size (the card clips it while morphing), so content never
    // reflows mid-animation. It fades in a beat after the card starts growing
    // and leaves on a short monotonic fade.
    component IslandPage: Item {
        id: page

        required property bool active
        required property string mode

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.calculateTargetWidth(page.mode)
        height: root.calculateTargetHeight(page.mode)
        // The entering page stacks above the leaving one, so the leaving page's
        // input shield never swallows clicks meant for the new page.
        z: page.active ? 1 : 0
        // Stay visible while the fade-in is paused at opacity 0 so the page can
        // take keyboard focus as soon as it opens.
        visible: page.active || opacity > 0.001
        // Disable only once hidden: a MouseArea disabled under the pointer keeps
        // containsMouse stuck. Leaving pages are shielded from input instead.
        enabled: page.visible

        MouseArea {
            z: 999
            anchors.fill: parent
            visible: !page.active || root.retractingToHidden
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => mouse.accepted = true
            onWheel: wheel => wheel.accepted = true
        }

        // No scale: nearly all text uses NativeRendering, which snaps glyphs
        // to the pixel grid and shimmers under a scaling transform.
        property real drift: -Motion.drift
        opacity: 0
        transform: Translate {
            y: page.drift
        }

        states: State {
            name: "shown"
            when: page.active
            PropertyChanges {
                page.opacity: 1
                page.drift: 0
            }
        }

        transitions: [
            Transition {
                to: "shown"
                enabled: Motion.enabled
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.isMorphing ? Motion.contentEnterDelay : 0
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            duration: Motion.fadeInDuration
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "drift"
                            duration: Motion.expandDuration
                            easing.type: Easing.OutBack
                            easing.overshoot: Motion.overshoot
                        }
                    }
                }
            },
            Transition {
                from: "shown"
                enabled: Motion.enabled
                NumberAnimation {
                    properties: "opacity,drift"
                    duration: Motion.fadeOutDuration
                    easing.type: Easing.OutQuad
                }
            }
        ]
    }

    function calculateTargetWidth(mode: string): int {
        switch (mode) {
        case "osd":
            return Math.min(300, root.width - 32);
        case "apps":
        case "projects":
        case "alerts":
            return Math.min(480, root.width - 32);
        case "wallpapers":
            return Math.min(540, root.width - 32);
        case "sound":
        case "mic":
        case "wifi":
        case "bluetooth":
            return Math.min(400, root.width - 32);
        default:
            return Math.min(420, root.width - 32);
        }
    }

    function calculateTargetHeight(mode: string): int {
        switch (mode) {
        case "osd":
            return osdView.implicitHeight > 0 ? osdView.implicitHeight : 48;
        case "notification":
            return (notificationView.implicitHeight > 0) ? Math.max(notificationView.implicitHeight, 96) : 96;
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
            return (launcherViewWrapper.implicitHeight > 0) ? launcherViewWrapper.implicitHeight : 336;
        default:
            return root.pillHeight;
        }
    }

    readonly property int targetWidth: calculateTargetWidth(root.currentMode)
    readonly property int targetHeight: calculateTargetHeight(root.currentMode)

    // Content that resizes while open retargets the card and the geometry
    // Behaviors carry it there. Mid-morph changes wait for onIsMorphingChanged
    // so live content loading during an open doesn't restart the spring.
    onTargetHeightChanged: {
        if (root.isExpanded && !root.isMorphing && !root.snapGeometry) {
            root.targetCardHeight = root.targetHeight;
        }
    }

    onTargetWidthChanged: {
        if (root.isExpanded && !root.isMorphing && !root.snapGeometry) {
            root.targetCardWidth = root.targetWidth;
            root.targetCardX = Math.round((root.width - root.targetWidth) / 2);
        }
    }

    property Item activeSourcePill: null

    function sourcePillForMode(mode: string): Item {
        switch (mode) {
        case "apps":
        case "projects":
        case "media":
            return contextPill;
        case "alerts":
        case "notification":
            return (alertsPill.visible ? alertsPill : statusPill);
        case "osd":
        case "sound":
        case "mic":
        case "battery":
        case "wifi":
        case "bluetooth":
        case "stats":
            return statusPill;
        case "calendar":
        case "dashboard":
        case "power":
        case "weather":
        case "wallpapers":
        case "time":
        default:
            return timePill;
        }
    }

    function updateSourcePill(mode: string) {
        activeSourcePill = sourcePillForMode(mode);
    }

    readonly property Item resolvedSourcePill: activeSourcePill ?? timePill
    readonly property real sourcePillLeftInRoot: {
        const pill = resolvedSourcePill;
        if (!pill)
            return Math.round((root.width - root.targetWidth) / 2);
        const rowLeft = Math.round((root.width - pillsRow.implicitWidth) / 2);
        return rowLeft + pill.x;
    }
    readonly property real sourcePillWidth: {
        const pill = resolvedSourcePill;
        if (!pill)
            return root.pillHeight;
        return (pill.implicitWidth > 0) ? pill.implicitWidth : (pill.width > 0 ? pill.width : root.pillHeight);
    }

    property real targetCardWidth: Math.round(sourcePillWidth)
    property real targetCardHeight: root.pillHeight
    property real targetCardX: sourcePillLeftInRoot
    property real targetCardRadius: root.pillRadius
    readonly property real targetCardOpacity: (root.isExpanded || root.retractingToHidden || root.isMorphing) ? 1.0 : 0.0

    onCurrentModeChanged: {
        if (currentMode !== "collapsed" && !root.retractingToHidden) {
            root.updateSourcePill(currentMode);
        }
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
            launcherView.cancelFocusRetry();
            Qt.callLater(() => {
                root.forceActiveFocus();
            });
        } else if (currentMode === "collapsed" && root.hasNotifications) {
            Qt.callLater(() => {
                if (root.currentMode === "collapsed" && root.hasNotifications) {
                    root.openedFromHidden = !root.barAlwaysVisible;
                    root.expand("notification");
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

    // Inline OSD State (Modesty non-disruptive inline status feedback)
    property bool inlineOsdActive: false
    property string inlineOsdIcon: Icons.speakerHigh
    property real inlineOsdValue: 0.0
    property string inlineOsdText: "0%"

    Timer {
        id: inlineOsdTimer
        interval: 1800
        repeat: false
        onTriggered: {
            root.inlineOsdActive = false;
        }
    }

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
        interval: Motion.collapseDuration + 60
        repeat: false
        onTriggered: {
            root.finishRetraction();
        }
    }

    function triggerOsd(indicator: string, value: real, muted: bool) {
        root.osdIndicator = indicator;
        root.osdValue = value;
        root.osdMuted = muted;
        if (root.currentMode === "collapsed") {
            root.inlineOsdIcon = indicator === "brightness" ? Icons.sun
                : (indicator === "mic" ? (muted ? Icons.micSlash : Icons.mic)
                    : (muted ? Icons.speakerSlash : Icons.speakerHigh));
            root.inlineOsdValue = value;
            root.inlineOsdText = muted ? "Muted" : (Math.round(value * 100) + "%");
            root.inlineOsdActive = true;
            inlineOsdTimer.restart();
        } else if (root.currentMode === "osd") {
            if (root.retractingToHidden) {
                root.retractingToHidden = false;
                retractFinishTimer.stop();
                slideUpAnim.stop();
                root.animateReveal(0);
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
    readonly property int barTargetHeight: pillHeight
    // Keep one floating gap at the screen edge and another below the pills so
    // tiled windows do not touch them.
    readonly property int baseOuterMargin: topMargin * 2
    readonly property int totalBarHeight: pillHeight + topMargin
    readonly property bool timerInputActive: false
    readonly property bool dashboardInputActive: islandActive && currentMode === "dashboard"

    property alias barHitbox: activeBarHitbox
    readonly property Item dropHitbox: null

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
        width: root.isExpanded
            ? Math.max(expandedCard.width, pillsRow.implicitWidth + 16)
            : Math.max(200, pillsRow.implicitWidth + 16)
        height: root.isExpanded
            ? (root.topMargin + expandedCard.height + 8)
            : (root.hitboxExpanded ? (root.topMargin + root.pillHeight + 8) : Math.max(16, root.triggerHeight + root.topMargin))
    }

    // ═════════════════════════════════════════════════════════════
    // COLLAPSED BAR STATE: SEPARATE FLOATING PILLS
    // ═════════════════════════════════════════════════════════════
    Item {
        id: collapsedPillsLayer
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.topMargin + root.containerY
        width: pillsRow.implicitWidth
        height: root.pillHeight
        visible: !root.retractingToHidden && !root.openedFromHidden && root.revealProgress > 0.001
        enabled: !root.isExpanded && !root.retractingToHidden && !root.isMorphing
        opacity: root.contentReveal

            RowLayout {
                id: pillsRow
                anchors.centerIn: parent
                spacing: 8

                // ── PILL 1: CONTEXT PILL (ACTIVE WINDOW / MEDIA TITLE) ──
                StyledRect {
                    id: contextPill
                    implicitHeight: root.pillHeight
                    implicitWidth: Math.min(
                        fluidContextText.implicitWidth + contextContent.anchors.leftMargin
                            + contextContent.anchors.rightMargin
                            + (root.isMediaPlaying ? mediaVisualizer.implicitWidth + contextContent.spacing : 0),
                        root.isMediaPlaying ? 340 : 236
                    )
                    variant: "pane"
                    radius: root.pillRadius
                    enableBorder: true
                    enableShadow: true
                    backgroundOpacity: 1.0

                    readonly property bool isHovered: contextHover.hovered && !root.isExpanded && !root.isMorphing
                    readonly property bool isPressed: contextMouse.pressed && isHovered

                    scale: isPressed ? 0.94 : 1.0
                    opacity: root.isExpanded ? 0.0 : 1.0

                    Behavior on opacity {
                        enabled: Motion.enabled
                        NumberAnimation {
                            duration: root.isExpanded ? Motion.fadeOutDuration : Motion.collapseDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    transform: Translate {
                        y: (contextPill.isHovered && !contextPill.isPressed) ? -1.5 : 0
                        Behavior on y {
                            enabled: Motion.enabled
                            NumberAnimation {
                                duration: Motion.hoverDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    SurfaceLighting {
                        anchors.fill: parent
                        radius: contextPill.radius
                        active: !root.isExpanded
                        interactive: true
                    }

                    PressBehavior on scale {
                        pressed: contextPill.isPressed
                    }

                    HoverHandler {
                        id: contextHover
                        enabled: !root.isExpanded && !root.isMorphing
                    }

                    RowLayout {
                        id: contextContent
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 2
                        anchors.bottomMargin: 3
                        spacing: root.isMediaPlaying ? 6 : 0

                        // 4 subtle animated media visualizer bars
                        Row {
                            id: mediaVisualizer
                            spacing: 2
                            visible: root.isMediaPlaying
                            Layout.alignment: Qt.AlignVCenter

                            Repeater {
                                model: 4
                                Rectangle {
                                    id: vizBar
                                    required property int index
                                    width: 2.5
                                    radius: 1.25
                                    color: Colors.primary
                                    height: root.isMediaPlaying ? (4 + ((index * 3 + 2) % 10)) : 3

                                    SequentialAnimation on height {
                                        running: root.isMediaPlaying && vizBar.visible
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            to: 12 - (vizBar.index % 3) * 3
                                            duration: 180 + vizBar.index * 45
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation {
                                            to: 4 + (vizBar.index % 2) * 2
                                            duration: 160 + vizBar.index * 40
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }
                            }
                        }

                        FluidTextProgress {
                            id: fluidContextText
                            Layout.fillWidth: true
                            Layout.fillHeight: true
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
                    }

                    MouseArea {
                        id: contextMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: false
                        onClicked: {
                            if (root.isMediaPlaying)
                                root.expand("media");
                            else
                                root.expand("apps");
                        }
                    }

                    StyledToolTip {
                        show: contextPill.isHovered
                        tooltipText: root.isMediaPlaying ? "Now Playing: " + root.contextLabel : ((root.screenFocusedClient && root.screenFocusedClient.title) ? root.screenFocusedClient.title : "Active Window")
                        description: root.isMediaPlaying ? "Click to open Media Center" : "Click to switch windows / apps"
                    }
                }

                // ── PILL 2: TIME PILL ──
                StyledRect {
                    id: timePill
                    implicitHeight: root.pillHeight
                    implicitWidth: timeText.implicitWidth + 24
                    variant: "pane"
                    radius: root.pillRadius
                    enableBorder: true
                    enableShadow: true
                    backgroundOpacity: 1.0

                    readonly property bool isHovered: timeHover.hovered && !root.isExpanded && !root.isMorphing
                    readonly property bool isPressed: timeMouse.pressed && isHovered

                    scale: isPressed ? 0.94 : 1.0
                    opacity: root.isExpanded ? 0.0 : 1.0

                    Behavior on opacity {
                        enabled: Motion.enabled
                        NumberAnimation {
                            duration: root.isExpanded ? Motion.fadeOutDuration : Motion.collapseDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    transform: Translate {
                        y: (timePill.isHovered && !timePill.isPressed) ? -1.5 : 0
                        Behavior on y {
                            enabled: Motion.enabled
                            NumberAnimation {
                                duration: Motion.hoverDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    SurfaceLighting {
                        anchors.fill: parent
                        radius: timePill.radius
                        active: !root.isExpanded
                        interactive: true
                    }

                    PressBehavior on scale {
                        pressed: timePill.isPressed
                    }

                    HoverHandler {
                        id: timeHover
                        enabled: !root.isExpanded && !root.isMorphing
                    }

                    SlidingDigits {
                        id: timeText
                        anchors.centerIn: parent
                        text: root.formattedTime
                        color: timePill.isHovered ? Colors.primary : Colors.overBackground
                    }

                    MouseArea {
                        id: timeMouse
                        anchors.fill: parent
                        hoverEnabled: false
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

                    StyledToolTip {
                        show: timePill.isHovered
                        tooltipText: root.formattedDate
                        description: "Left-click: Dashboard • Right-click: Calendar"
                    }
                }

                // ── PILL 3: WORKSPACES PILL ──
                StyledRect {
                    id: workspacesPill
                    implicitHeight: root.pillHeight
                    implicitWidth: taskbar.implicitWidth + 12
                    variant: "pane"
                    radius: root.pillRadius
                    enableBorder: true
                    enableShadow: true
                    backgroundOpacity: 1.0
                    opacity: root.isExpanded ? 0.0 : 1.0

                    Behavior on opacity {
                        enabled: Motion.enabled
                        NumberAnimation {
                            duration: root.isExpanded ? Motion.fadeOutDuration : Motion.collapseDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    SurfaceLighting {
                        anchors.fill: parent
                        radius: workspacesPill.radius
                        active: !root.isExpanded
                        interactive: true
                    }

                    NonchalantTaskbar {
                        id: taskbar
                        anchors.centerIn: parent
                        bar: root
                        showBackground: false
                    }
                }

                // ── PILL 4: STATUS ICONS PILL (BRIGHTNESS, VOLUME, BATTERY) ──
                StyledRect {
                    id: statusPill
                    implicitHeight: root.pillHeight
                    implicitWidth: root.inlineOsdActive ? (statusIcons.implicitWidth + 140) : (statusIcons.implicitWidth + 16)
                    variant: "pane"
                    radius: root.pillRadius
                    enableBorder: true
                    enableShadow: true
                    backgroundOpacity: 1.0
                    opacity: root.isExpanded ? 0.0 : 1.0

                    readonly property bool isHovered: statusHover.hovered && !root.isExpanded && !root.isMorphing

                    Behavior on opacity {
                        enabled: Motion.enabled
                        NumberAnimation {
                            duration: root.isExpanded ? Motion.fadeOutDuration : Motion.collapseDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on implicitWidth {
                        enabled: Motion.enabled
                        NumberAnimation {
                            duration: Motion.fadeInDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    transform: Translate {
                        y: statusPill.isHovered ? -1.5 : 0
                        Behavior on y {
                            enabled: Motion.enabled
                            NumberAnimation {
                                duration: Motion.hoverDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    SurfaceLighting {
                        anchors.fill: parent
                        radius: statusPill.radius
                        active: !root.isExpanded
                        interactive: true
                    }

                    HoverHandler {
                        id: statusHover
                        enabled: !root.isExpanded && !root.isMorphing
                    }

                    // Collapsed standard status icons
                    IslandStatusIcons {
                        id: statusIcons
                        anchors.centerIn: parent
                        bar: root
                        visible: opacity > 0.001
                        opacity: root.inlineOsdActive ? 0.0 : 1.0
                        Behavior on opacity {
                            enabled: Motion.enabled
                            NumberAnimation { duration: Motion.hoverDuration; easing.type: Easing.OutCubic }
                        }
                    }

                    // Modesty inline OSD slider and percentage
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        visible: opacity > 0.001
                        opacity: root.inlineOsdActive ? 1.0 : 0.0
                        Behavior on opacity {
                            enabled: Motion.enabled
                            NumberAnimation { duration: Motion.hoverDuration; easing.type: Easing.OutCubic }
                        }

                        // The OSD covers the icons after the first scroll step, so
                        // it keeps adjusting whichever level it is showing.
                        WheelHandler {
                            enabled: root.inlineOsdActive
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                const step = statusIcons.wheelStep(event.angleDelta.y, event.pixelDelta.y);
                                if (root.osdIndicator === "brightness")
                                    statusIcons.adjustBrightness(step);
                                else if (root.osdIndicator === "mic")
                                    statusIcons.adjustMic(step);
                                else
                                    statusIcons.adjustVolume(step);
                                inlineOsdTimer.restart();
                            }
                        }

                        StyledText {
                            text: root.inlineOsdIcon
                            font.family: Icons.font
                            font.pixelSize: 13
                            color: Colors[Colors.accentRole(root.osdIndicator)]
                            renderType: Text.NativeRendering
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                            radius: 2
                            color: Colors.withAlpha(Colors.overBackground, 0.15)
                            clip: true

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, root.inlineOsdValue))
                                height: 4
                                radius: 2
                                color: Colors[Colors.accentRole(root.osdIndicator)]
                                Behavior on width {
                                    enabled: Motion.enabled
                                    SmoothedAnimation {
                                        velocity: -1
                                        duration: 90
                                        reversingMode: SmoothedAnimation.Immediate
                                    }
                                }
                            }
                        }

                        StyledText {
                            text: root.inlineOsdText
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(-2)
                            font.bold: true
                            color: Colors.overBackground
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // ── PILL 5: ALERTS PILL (NOTIFICATION COUNTER) ──
                StyledRect {
                    id: alertsPill
                    visible: !Notifications.silent && (root.alertsCount > 0 || root.hasNotifications)
                    implicitHeight: root.pillHeight
                    implicitWidth: alertsRow.implicitWidth + 16
                    variant: "pane"
                    radius: root.pillRadius
                    enableBorder: true
                    enableShadow: true
                    backgroundOpacity: 1.0

                    readonly property bool isHovered: alertsHover.hovered && !root.isExpanded && !root.isMorphing
                    readonly property bool isPressed: alertsMouse.pressed && isHovered

                    scale: isPressed ? 0.90 : 1.0
                    opacity: root.isExpanded ? 0.0 : 1.0

                    Behavior on opacity {
                        enabled: Motion.enabled
                        NumberAnimation {
                            duration: root.isExpanded ? Motion.fadeOutDuration : Motion.collapseDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    transform: Translate {
                        y: (alertsPill.isHovered && !alertsPill.isPressed) ? -1.5 : 0
                        Behavior on y {
                            enabled: Motion.enabled
                            NumberAnimation {
                                duration: Motion.hoverDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    SurfaceLighting {
                        anchors.fill: parent
                        radius: alertsPill.radius
                        active: !root.isExpanded
                        interactive: true
                    }

                    PressBehavior on scale {
                        pressed: alertsPill.isPressed
                    }

                    HoverHandler {
                        id: alertsHover
                        enabled: !root.isExpanded && !root.isMorphing
                    }

                    RowLayout {
                        id: alertsRow
                        anchors.centerIn: parent
                        spacing: 4

                        StyledText {
                            text: Icons.bell
                            font.family: Icons.font
                            font.pixelSize: 13
                            color: root.hasNotifications ? Colors.primary : (alertsPill.isHovered ? Colors.primary : Colors.overBackground)
                            renderType: Text.NativeRendering
                        }

                        StyledText {
                            text: String(root.alertsCount)
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(-2)
                            font.bold: true
                            color: root.hasNotifications ? Colors.primary : (alertsPill.isHovered ? Colors.primary : Colors.overBackground)
                            renderType: Text.NativeRendering
                        }
                    }

                    MouseArea {
                        id: alertsMouse
                        anchors.fill: parent
                        hoverEnabled: false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expand("alerts")
                    }

                    StyledToolTip {
                        show: alertsPill.isHovered
                        tooltipText: root.alertsCount + " notification" + (root.alertsCount === 1 ? "" : "s")
                        description: "Click to open alerts panel"
                    }
                }
            }
        }

    // ═════════════════════════════════════════════════════════════
    // EXPANDED STATE: UNIFIED FLOATING CARD
    // ═════════════════════════════════════════════════════════════
    StyledRect {
        id: expandedCard
        x: root.targetCardX
        y: root.topMargin + root.containerY
        width: root.targetCardWidth
        height: root.targetCardHeight
        variant: "pane"
        radius: root.targetCardRadius
        enableBorder: true
        enableShadow: true
        backgroundOpacity: 1.0
        clip: true
        visible: (root.isExpanded || root.retractingToHidden || root.isMorphing || opacity > 0.001) && root.revealProgress > 0.001
        opacity: (root.isExpanded || root.retractingToHidden || root.isMorphing) ? 1.0 : 0.0
        z: 10

        Behavior on opacity {
            enabled: Motion.enabled && !root.snapGeometry
            NumberAnimation {
                duration: root.isExpanded ? 0 : Motion.fadeOutDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on x {
            enabled: Motion.enabled && (root.shouldBeRevealed || root.isExpanded) && !root.retractingToHidden && !root.snapGeometry
            NumberAnimation {
                duration: root.isExpanded ? Motion.expandDuration : Motion.collapseDuration
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: Motion.overshoot
            }
        }

        Behavior on width {
            enabled: Motion.enabled && (root.shouldBeRevealed || root.isExpanded) && !root.retractingToHidden && !root.snapGeometry
            NumberAnimation {
                duration: root.isExpanded ? Motion.expandDuration : Motion.collapseDuration
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: Motion.overshoot
            }
        }

        Behavior on height {
            enabled: Motion.enabled && (root.shouldBeRevealed || root.isExpanded) && !root.retractingToHidden && !root.snapGeometry
            NumberAnimation {
                duration: root.isExpanded ? Motion.expandDuration : Motion.collapseDuration
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: Motion.overshoot
            }
        }

        Behavior on radius {
            enabled: Motion.enabled && (root.shouldBeRevealed || root.isExpanded) && !root.retractingToHidden && !root.snapGeometry
            NumberAnimation {
                duration: root.isExpanded ? Motion.expandDuration : Motion.collapseDuration
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: Motion.overshoot
            }
        }

        SurfaceLighting {
            anchors.fill: parent
            radius: root.targetCardRadius
            active: root.isExpanded || root.isMorphing
            interactive: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                FocusGrabManager.clearTopGrab();
                Visibilities.closeActiveBarPopup();
            }
        }

            Item {
                id: pageLayer
                anchors.fill: parent

                // ── OSD BANNER (Volume / Brightness / Mic) ──
                IslandPage {
                    active: root.currentMode === "osd"
                    mode: "osd"

                    IslandOsdBanner {
                        id: osdView
                        bar: root
                        width: parent.width
                        indicator: root.osdIndicator
                        value: root.osdValue
                        muted: root.osdMuted
                    }
                }

                // ── NOTIFICATION BANNER ──
                IslandPage {
                    active: !Notifications.silent && root.currentMode === "notification" && root.hasNotifications && notificationView.activeNotif !== null
                    mode: "notification"

                    IslandNotificationBanner {
                        id: notificationView
                        width: parent.width

                        onDismissRequested: {
                            if (root.currentMode === "notification")
                                root.collapse();
                        }
                    }
                }

                // ── MAIN DASHBOARD HUB ──
                IslandPage {
                    active: root.currentMode === "dashboard"
                    mode: "dashboard"

                    IslandDashboard {
                        id: dashboardView
                        screen: root.screen
                        width: parent.width
                        lyricsActive: root.currentMode === "dashboard" && !root.retractingToHidden
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

                // ── POWER MENU ──
                IslandPage {
                    active: root.currentMode === "power"
                    mode: "power"

                    IslandPowerPanel {
                        id: powerView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                        onActionTriggered: root.collapse()
                    }
                }

                // ── SOUND PANEL ──
                IslandPage {
                    active: root.currentMode === "sound"
                    mode: "sound"

                    IslandSoundPanel {
                        id: soundView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ── MICROPHONE PANEL ──
                IslandPage {
                    active: root.currentMode === "mic"
                    mode: "mic"

                    IslandMicPanel {
                        id: micView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ── WI-FI NETWORKS PANEL ──
                IslandPage {
                    active: root.currentMode === "wifi"
                    mode: "wifi"

                    IslandWifiPanel {
                        id: wifiView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ── BLUETOOTH PANEL ──
                IslandPage {
                    active: root.currentMode === "bluetooth"
                    mode: "bluetooth"

                    IslandBluetoothPanel {
                        id: bluetoothView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ── SYSTEM STATS PANEL ──
                IslandPage {
                    active: root.currentMode === "stats"
                    mode: "stats"

                    IslandStatsPanel {
                        id: statsView
                        width: parent.width
                        height: implicitHeight
                    }
                }

                // ── ALERTS PANEL ──
                IslandPage {
                    active: root.currentMode === "alerts"
                    mode: "alerts"

                    IslandAlertsPanel {
                        id: alertsView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ── WALLPAPERS PANEL ──
                IslandPage {
                    active: root.currentMode === "wallpapers"
                    mode: "wallpapers"

                    IslandWallpaperPanel {
                        id: wallpapersView
                        screen: root.screen
                        width: parent.width
                        height: implicitHeight
                    }
                }

                // ── BATTERY PANEL ──
                IslandPage {
                    active: root.currentMode === "battery"
                    mode: "battery"

                    IslandBatteryPanel {
                        id: batteryView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ── WEATHER PANEL ──
                IslandPage {
                    active: root.currentMode === "weather"
                    mode: "weather"

                    IslandWeatherPanel {
                        id: weatherView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ── MEDIA CENTER PANEL ──
                IslandPage {
                    active: root.currentMode === "media"
                    mode: "media"

                    IslandMediaCenterPanel {
                        id: mediaCenterView
                        width: parent.width
                        maximumHeight: Math.max(0, root.screen.height - 32)
                        lyricsActive: root.currentMode === "media" && !root.retractingToHidden
                        height: implicitHeight
                    }
                }

                // ── CALENDAR PANEL ──
                IslandPage {
                    active: root.currentMode === "calendar"
                    mode: "calendar"

                    IslandCalendarPanel {
                        id: calendarView
                        width: parent.width
                        height: implicitHeight

                        onBackRequested: root.expand("dashboard")
                    }
                }

                // ── APPS & PROJECTS LAUNCHER ──
                IslandPage {
                    active: root.currentMode === "apps" || root.currentMode === "projects"
                    mode: "apps"

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

    // Single hover zone for the autohide reveal
    Item {
        id: hoverZone
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        z: 1000
        width: Math.max(200, pillsRow.implicitWidth + 16)
        height: root.hitboxExpanded
            ? (root.topMargin + root.pillHeight + 12)
            : Math.max(16, root.triggerHeight + root.topMargin)

        HoverHandler {
            id: revealHoverHandler
            blocking: false
        }
    }
}
