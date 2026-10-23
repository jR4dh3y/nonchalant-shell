pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.config
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme

FocusScope {
    id: root
    required property Item bar
    required property ShellScreen screen
    property bool isOpen: false
    property string mode: "controls"
    property string tab: ""
    property Item trigger: null
    property date currentDate: wallClock.date
    readonly property bool bottomPosition: (Config.bar?.position ?? "top") === "bottom"
    readonly property Item hitbox: progress > 0.001 ? frame : null
    property real progress: isOpen ? 1 : 0
    readonly property bool sampling: isOpen && mode === "stats"
    readonly property real em: Styling.fontSize(0)
    readonly property real preferredWidth: ({ controls: 32, connections: 26, today: 23, alerts: 30, tray: 23, wallpapers: 40, stats: 34, battery: 24, power: 22, media: 28 })[mode] * em
    readonly property real calendarHeight: em * (8 + Math.ceil((calendarMonth.getDay() + 6) % 7 / 7 + new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + 1, 0).getDate() / 7) * 2.25)
    readonly property date calendarMonth: pageLoader.item?.objectName === "deckCalendar" ? pageLoader.item.month : new Date(currentDate.getFullYear(), currentDate.getMonth(), 1)
    readonly property real preferredHeight: mode === "today" ? calendarHeight
        : mode === "alerts" ? em * Math.min(32, Notifications.list.length > 0 ? 9 + Notifications.list.length * 7 : 10)
        : mode === "tray" ? em * Math.min(28, 6 + SystemTray.items.values.length * 2.6)
        : mode === "power" ? em * (19
            + (!Battery.available && PowerProfile.availableProfiles.length > 0 ? 3 + PowerProfile.availableProfiles.length * 2.1 : 0))
        : em * (({ controls: 23, connections: 30, wallpapers: 29, stats: 22, battery: 17, media: 13 })[mode] ?? 23)

    objectName: "deckDrawer"
    width: Math.max(0, Math.min(parent.width - em, preferredWidth))
    height: Math.max(0, Math.min(parent.height - root.bar.totalBarHeight - em * 2, preferredHeight))
    x: Math.max(em / 2, Math.min(parent.width - width - em / 2, root.bar.popupAnchorX - width / 2))
    y: root.bottomPosition ? parent.height - root.bar.totalBarHeight - height - em / 2 : root.bar.totalBarHeight + em / 2
    visible: progress > 0.001
    z: 1000

    function open(page: string): void {
        if (!root.bar.reveal) return;
        root.mode = page;
        Visibilities.claimBarPopup(root);
        root.isOpen = true;
        Qt.callLater(() => {
            if (!root.isOpen) return;
            root.forceActiveFocus();
        });
    }
    function close(): void {
        if (root.mode === "power") pageLoader.item?.cancelConfirmation();
        if (root.mode === "connections") pageLoader.item?.stopDiscovery();
        root.isOpen = false;
        Visibilities.releaseBarPopup(root);
    }
    function openSettings(page: string): void {
        root.close();
        GlobalShortcuts.toggleSettings(root.screen.name);
        GlobalStates.openSettings(page);
    }
    onIsOpenChanged: {
        if (isOpen) GlobalStates.dashboardPopupScreen = screen.name;
        else if (GlobalStates.dashboardPopupScreen === screen.name) GlobalStates.dashboardPopupScreen = "";
    }
    onSamplingChanged: {
        if (sampling) GlobalStates.systemMonitorPopupScreen = screen.name;
        else if (GlobalStates.systemMonitorPopupScreen === screen.name) GlobalStates.systemMonitorPopupScreen = "";
    }
    Component.onDestruction: {
        Visibilities.releaseBarPopup(root);
        if (GlobalStates.dashboardPopupScreen === screen.name) GlobalStates.dashboardPopupScreen = "";
        if (GlobalStates.systemMonitorPopupScreen === screen.name) GlobalStates.systemMonitorPopupScreen = "";
    }
    Behavior on progress {
        enabled: Motion.enabled
        NumberAnimation {
            duration: root.isOpen ? Motion.expandDuration : Motion.collapseDuration
            easing.type: root.isOpen ? Easing.OutBack : Easing.InCubic
            easing.overshoot: Motion.overshoot
        }
    }
    Behavior on x { enabled: Motion.enabled && root.isOpen; NumberAnimation { duration: Motion.collapseDuration; easing.type: Easing.OutCubic } }
    Behavior on width { enabled: Motion.enabled && root.isOpen; NumberAnimation { duration: Motion.expandDuration; easing.type: Easing.OutCubic } }
    Behavior on height { enabled: Motion.enabled && root.isOpen; NumberAnimation { duration: Motion.expandDuration; easing.type: Easing.OutCubic } }
    FocusGrab { active: root.isOpen; onCleared: root.close() }
    Keys.onEscapePressed: {
        if (root.mode === "power" && pageLoader.item?.armedAction) pageLoader.item.cancelConfirmation();
        else root.close();
    }
    SystemClock { id: wallClock; precision: SystemClock.Minutes }

    Item {
        id: frame
        objectName: "deckDrawerFrame"
        width: parent.width
        height: parent.height * Math.max(0, Math.min(1, root.progress))
        y: root.bottomPosition ? parent.height - height : 0
        clip: true
        StyledRect { anchors.fill: parent; variant: "pane"; radius: Styling.radius(-4) }
        Loader {
            id: pageLoader
            objectName: "deckPageContent"
            active: root.visible
            x: root.em
            y: root.bottomPosition ? frame.height - root.height + root.em : root.em
            width: root.width - root.em * 2
            height: root.height - root.em * 2
            sourceComponent: {
                switch (root.mode) {
                case "connections": return connections;
                case "today": return today;
                case "alerts": return inbox;
                case "tray": return tray;
                case "stats": return resources;
                case "wallpapers": return wallpapers;
                case "battery": return battery;
                case "power": return power;
                case "media": return media;
                default: return controls;
                }
            }
        }
    }
    Component { id: controls; DeckControls { screen: root.screen; onSettingsRequested: page => root.openSettings(page); onMenuRequested: page => root.bar.openControlMenu(page) } }
    Component { id: connections; DeckConnections { bluetooth: root.tab === "bluetooth"; onTabRequested: tab => root.bar.openControlMenu(tab); onSettingsRequested: page => root.openSettings(page) } }
    Component { id: today; DeckCalendar { today: root.currentDate } }
    Component { id: inbox; DeckInbox {} }
    Component { id: tray; DeckTray { onActionTriggered: root.close() } }
    Component { id: wallpapers; DeckWallpapers { screen: root.screen } }
    Component { id: resources; DeckResources { availableHeight: pageLoader.height } }
    Component { id: battery; DeckBattery { onPowerRequested: root.bar.openControlMenu("power") } }
    Component { id: power; DeckPower { onActionRequested: action => root.executePower(action) } }
    Component { id: media; DeckMedia {} }

    function executePower(action: string): void {
        root.close();
        if (action === "lock") LockscreenService.lock();
        else if (action === "logout") CompositorService.logout();
        else if (action === "suspend" || action === "hibernate" || action === "reboot" || action === "poweroff")
            Quickshell.execDetached(["systemctl", action]);
    }
}
