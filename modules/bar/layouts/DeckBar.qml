pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.config
import qs.modules.bar.deck
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme

Item {
    id: root
    required property ShellScreen screen
    readonly property bool bottomPosition: (Config.bar?.position ?? "top") === "bottom"
    readonly property bool reveal: !CompositorService.overviewOpen && CompositorService.fullscreenOutputs.indexOf(screen.name) === -1
    readonly property real unit: Styling.fontSize(0) * 2
    readonly property int gap: Math.max(1, Math.round(Styling.fontSize(0) / 4))
    readonly property int padding: Math.max(1, Math.round(Styling.fontSize(0) / 7))
    readonly property int barTargetHeight: Math.ceil(root.unit + root.padding * 2)
    readonly property int baseOuterMargin: gap * 2
    readonly property int totalBarHeight: barTargetHeight + gap
    readonly property bool compact: root.width < Styling.fontSize(0) * 72
    readonly property bool minimal: root.width < Styling.fontSize(0) * 40
    readonly property bool timerInputActive: false
    readonly property bool dashboardInputActive: desk.isOpen
    readonly property bool trayInputActive: desk.isOpen && desk.mode === "tray"
    readonly property Item dashboardHitbox: desk.hitbox
    readonly property alias barHitbox: hitbox
    readonly property bool menuOpen: desk.isOpen
    readonly property string controlMode: desk.mode
    readonly property string networkLabel: NetworkService.ethernet ? "Wired" : NetworkService.wifiConnected ? NetworkService.activeSsid : "Offline"

    onRevealChanged: if (!reveal) desk.close()
    onVisibleChanged: if (!visible) desk.close()
    function triggerFor(page: string): Item {
        switch (page) {
        case "connections": return networkButton;
        case "controls": return volumeButton;
        case "battery": return batteryButton;
        case "alerts": return inboxButton;
        case "tray": return trayButton;
        case "today": return clockButton;
        case "power": return powerButton;
        default: return null;
        }
    }
    readonly property real popupAnchorX: {
        // Include the status row's layout geometry, not only the button's local x.
        const button = desk.trigger;
        return button?.visible ? surface.x + statusZone.x + status.x + button.x + button.width / 2 : root.width;
    }
    function toggleCenterMenu(): void { openControlMenu("controls"); }
    function toggleWallpapers(): void { openControlMenu("wallpapers"); }
    function openControlMenu(mode: string): void {
        if (mode === "windows") {
            desk.close();
            CompositorService.toggleOverview();
            return;
        }
        const page = ["wifi", "bluetooth", "network"].includes(mode) ? "connections"
            : ["sound", "mic", "audio", "media"].includes(mode) ? "controls"
            : ["battery", "powerprofile"].includes(mode) ? (Battery.available ? "battery" : "power")
            : ["calendar", "datetime", "weather"].includes(mode) ? "today"
            : ["notifications", "alerts"].includes(mode) ? "alerts"
            : ["resources", "system-monitor"].includes(mode) ? "stats"
            : mode === "powermenu" ? "power" : mode;
        const tab = mode === "bluetooth" ? "bluetooth" : "wifi";
        if (!["controls", "connections", "battery", "today", "alerts", "tray", "power", "wallpapers", "stats"].includes(page)) return;
        if (desk.isOpen && desk.mode === page && (page !== "connections" || desk.tab === tab)) desk.close();
        else {
            desk.tab = tab;
            desk.trigger = triggerFor(page);
            desk.open(page);
        }
    }
    Component.onCompleted: Visibilities.registerDashboardController(screen.name, root)
    Component.onDestruction: Visibilities.unregisterDashboardController(screen.name, root)
    SystemClock { id: wallClock; precision: SystemClock.Minutes }

    Item {
        id: hitbox
        objectName: "deckHitbox"
        x: root.gap
        y: root.bottomPosition ? root.height - root.totalBarHeight : root.gap
        width: root.reveal ? Math.max(0, root.width - root.gap * 2) : 0
        height: root.reveal ? root.barTargetHeight : 0
    }
    RowLayout {
        id: surface
        objectName: "deckSurface"
        x: root.gap
        y: hitbox.y
        width: Math.max(0, root.width - root.gap * 2)
        height: root.barTargetHeight
        spacing: root.gap
        opacity: root.reveal ? 1 : 0
        property real retraction: root.reveal ? 0 : 1
        transform: Translate { y: (root.bottomPosition ? 1 : -1) * surface.retraction * root.totalBarHeight }
        Behavior on retraction {
            enabled: DeckMotion.enabled
            NumberAnimation {
                duration: root.reveal ? DeckMotion.openDuration : DeckMotion.closeDuration
                easing.type: root.reveal ? DeckMotion.openEasing : DeckMotion.closeEasing
            }
        }
        Behavior on opacity { enabled: DeckMotion.enabled; NumberAnimation { duration: DeckMotion.closeDuration } }

        StyledRect {
            objectName: "deckNavigationZone"
            Layout.preferredWidth: Math.min(root.width * (root.minimal ? 0.42 : 0.28), navigation.implicitWidth + root.padding * 2)
            Layout.fillHeight: true
            variant: "pane"
            radius: Styling.radius(-8)
            RowLayout {
                id: navigation
                anchors.fill: parent
                anchors.margins: root.padding
                spacing: root.padding
                DeckAction {
                    objectName: "deckLauncher"
                    glyph: Icons.squaresFour
                    description: "Open an app"
                    selected: Visibilities.currentActiveModule === "launcher"
                    onClicked: GlobalShortcuts.toggleLauncher()
                }
                DeckWorkspaces {
                    objectName: "deckWorkspaces"
                    Layout.fillWidth: true
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: root.unit
                    screen: root.screen
                    compact: root.compact
                }
            }
        }
        StyledRect {
            id: taskZone
            objectName: "deckTaskZone"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.minimal && tasks.ids.length > 0
            variant: "pane"
            radius: Styling.radius(-8)
            DeckTasks {
                id: tasks
                objectName: "deckTasks"
                anchors.fill: parent
                anchors.margins: root.padding
                screen: root.screen
                compact: root.compact
                onWindowsRequested: root.openControlMenu("windows")
            }
        }
        Item {
            Layout.fillWidth: true
            visible: !root.minimal && !taskZone.visible
        }
        StyledRect {
            id: statusZone
            objectName: "deckStatusZone"
            Layout.preferredWidth: status.implicitWidth + root.padding * 2
            Layout.fillWidth: root.minimal
            Layout.fillHeight: true
            variant: "pane"
            radius: Styling.radius(-8)
            RowLayout {
                id: status
                anchors.fill: parent
                anchors.margins: root.padding
                spacing: 0
                DeckAction {
                    id: networkButton
                    objectName: "deckNetwork"
                    visible: !root.compact
                    glyph: NetworkService.ethernet ? Icons.ethernet : NetworkService.wifiConnected ? Icons.wifiHigh : Icons.wifiOff
                    label: NetworkService.ethernet || NetworkService.wifiConnected ? root.networkLabel : ""
                    maximumLabelWidth: Styling.fontSize(0) * 7
                    selected: desk.isOpen && desk.mode === "connections"
                    description: root.networkLabel + " · Open connections"
                    onClicked: root.openControlMenu("connections")
                }
                DeckAction {
                    id: volumeButton
                    objectName: "deckVolume"
                    glyph: Audio.sink?.audio?.muted ? Icons.speakerSlash : Icons.speakerHigh
                    label: root.minimal ? "" : Math.round((Audio.sink?.audio?.volume ?? 0) * 100) + "%"
                    description: "Volume · Scroll to adjust · Right-click to mute"
                    selected: desk.isOpen && desk.mode === "controls"
                    onClicked: root.openControlMenu("controls")
                    onSecondaryClicked: Audio.toggleMute()
                    wheelEnabled: true
                    onScrolled: delta => { if (delta > 0) Audio.incrementVolume(); else if (delta < 0) Audio.decrementVolume(); }
                }
                DeckAction {
                    id: batteryButton
                    objectName: "deckBattery"
                    visible: !root.compact && Battery.available
                    glyph: Battery.isCharging ? Icons.batteryCharging : Icons.batteryHigh
                    label: Math.round(Battery.percentage) + "%"
                    description: "Battery and power controls"
                    selected: desk.isOpen && desk.mode === "battery"
                    onClicked: root.openControlMenu("battery")
                }
                DeckAction {
                    id: inboxButton
                    objectName: "deckInbox"
                    visible: !root.minimal
                    glyph: Notifications.silent ? Icons.bellSlash : Icons.bell
                    label: Notifications.list.length > 0 ? String(Notifications.list.length) : ""
                    description: "Notifications"
                    selected: desk.isOpen && desk.mode === "alerts"
                    onClicked: root.openControlMenu("alerts")
                }
                DeckAction {
                    id: trayButton
                    objectName: "deckTray"
                    visible: !root.compact && SystemTray.items.values.length > 0
                    glyph: Icons.dotsThree
                    description: "Background apps"
                    selected: desk.isOpen && desk.mode === "tray"
                    onClicked: root.openControlMenu("tray")
                }
                DeckAction {
                    id: powerButton
                    objectName: "deckPowerTrigger"
                    glyph: Icons.power
                    description: "Power and session"
                    selected: desk.isOpen && desk.mode === "power"
                    onClicked: root.openControlMenu("power")
                }
                DeckAction {
                    id: clockButton
                    objectName: "deckClock"
                    label: Qt.formatDateTime(wallClock.date, Config.bar.use12hFormat ? "h:mm ap" : "hh:mm")
                    description: Qt.formatDateTime(wallClock.date, "dddd, d MMMM yyyy") + " · Open calendar"
                    selected: desk.isOpen && desk.mode === "today"
                    onClicked: root.openControlMenu("today")
                }

            }
        }
    }
    DeckDrawer { id: desk; bar: root; screen: root.screen }
}
