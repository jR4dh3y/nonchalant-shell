pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme

// Deck's popup controller. Dashboard pages share one fixed-size dash with a
// page rail; Battery and Power are compact bespoke flyouts under their triggers.
FocusScope {
    id: root
    required property Item bar
    required property ShellScreen screen
    property bool isOpen: false
    property string mode: "controls"
    property string tab: ""
    property Item trigger: null
    property date currentDate: wallClock.date
    // -1 when the new page sits above the old one on the rail, 1 when below.
    property int pageDirection: 0
    readonly property bool bottomPosition: (Config.bar?.position ?? "top") === "bottom"
    readonly property Item hitbox: progress > 0.001 ? frame : null
    property real progress: isOpen ? 1 : 0
    readonly property bool sampling: isOpen && mode === "stats"
    readonly property real em: Styling.fontSize(0)
    readonly property real gap: em * 0.5
    readonly property list<string> pages: ["controls", "connections", "today", "alerts", "tray", "wallpapers", "stats"]
    readonly property bool dash: pages.includes(mode)
    readonly property real preferredWidth: dash ? em * 52 : em * (mode === "battery" ? 22 : 21)
    readonly property real preferredHeight: dash ? em * 31
        : mode === "battery" ? em * (10.5 + (PowerProfile.availableProfiles.length > 0 ? 3.4 + PowerProfile.availableProfiles.length * 2.5 : 0))
        : em * (19 + (!Battery.available && PowerProfile.availableProfiles.length > 0 ? 3.4 + PowerProfile.availableProfiles.length * 2.5 : 0))

    objectName: "deckDrawer"
    width: Math.max(0, Math.min(parent.width - em, preferredWidth))
    height: Math.max(0, Math.min(parent.height - root.bar.totalBarHeight - em * 2, preferredHeight))
    // The dash stays put while its rail switches pages; flyouts follow their trigger.
    x: dash ? Math.max(em / 2, parent.width - width - em / 2)
        : Math.max(em / 2, Math.min(parent.width - width - em / 2, root.bar.popupAnchorX - width / 2))
    y: root.bottomPosition ? parent.height - root.bar.totalBarHeight - height - em / 2 : root.bar.totalBarHeight + em / 2
    visible: progress > 0.001
    z: 1000

    function pageLabel(page: string): string {
        return ({ controls: "Controls", connections: "Network", today: "Today", alerts: "Inbox", tray: "Tray", wallpapers: "Wallpapers", stats: "Resources" })[page] ?? "";
    }
    function pageIcon(page: string): string {
        return ({ controls: Icons.faders, connections: Icons.wifiHigh, today: Icons.clock, alerts: Icons.bell, tray: Icons.dotsThree, wallpapers: Icons.wallpapers, stats: Icons.cpu })[page] ?? Icons.faders;
    }
    function open(page: string): void {
        if (!root.bar.reveal) return;
        if (root.isOpen && root.mode !== page) root.leavePage();
        const before = root.pages.indexOf(root.mode);
        const after = root.pages.indexOf(page);
        root.pageDirection = root.isOpen && before >= 0 && after >= 0 ? Math.sign(after - before) : 0;
        root.mode = page;
        Visibilities.claimBarPopup(root);
        root.isOpen = true;
        Qt.callLater(() => {
            if (!root.isOpen) return;
            root.forceActiveFocus();
        });
    }
    // Rail navigation keeps the trigger that opened the dash.
    function showPage(page: string): void {
        if (page === root.mode) return;
        root.open(page);
    }
    function cyclePage(step: int): void {
        const index = root.pages.indexOf(root.mode);
        if (index < 0) return;
        root.showPage(root.pages[(index + step + root.pages.length) % root.pages.length]);
    }
    function leavePage(): void {
        if (root.mode === "power") pageLoader.item?.cancelConfirmation();
        if (root.mode === "connections") pageLoader.item?.stopDiscovery();
    }
    function close(): void {
        root.leavePage();
        root.isOpen = false;
        Visibilities.releaseBarPopup(root);
    }
    function openSettings(page: string): void {
        root.close();
        GlobalShortcuts.toggleSettings(root.screen.name);
        GlobalStates.openSettings(page);
    }
    function executePower(action: string): void {
        root.close();
        if (action === "lock") LockscreenService.lock();
        else if (action === "logout") CompositorService.logout();
        else if (action === "suspend" || action === "hibernate" || action === "reboot" || action === "poweroff")
            Quickshell.execDetached(["systemctl", action]);
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
        enabled: DeckMotion.enabled
        NumberAnimation {
            duration: root.isOpen ? DeckMotion.openDuration : DeckMotion.closeDuration
            easing.type: root.isOpen ? DeckMotion.openEasing : DeckMotion.closeEasing
        }
    }
    Behavior on x { enabled: DeckMotion.enabled && root.isOpen; NumberAnimation { duration: DeckMotion.resizeDuration; easing.type: DeckMotion.openEasing } }
    Behavior on width { enabled: DeckMotion.enabled && root.isOpen; NumberAnimation { duration: DeckMotion.resizeDuration; easing.type: DeckMotion.openEasing } }
    Behavior on height { enabled: DeckMotion.enabled && root.isOpen; NumberAnimation { duration: DeckMotion.resizeDuration; easing.type: DeckMotion.openEasing } }
    FocusGrab { active: root.isOpen; onCleared: root.close() }
    Keys.onEscapePressed: {
        if (root.mode === "power" && pageLoader.item?.armedAction) pageLoader.item.cancelConfirmation();
        else root.close();
    }
    // Ctrl+Tab walks the rail; plain arrows stay with the focused control.
    Keys.onPressed: event => {
        if (!root.dash || !(event.modifiers & Qt.ControlModifier)) return;
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_PageDown) root.cyclePage(1);
        else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp) root.cyclePage(-1);
        else return;
        event.accepted = true;
    }
    SystemClock { id: wallClock; precision: SystemClock.Minutes }

    Item {
        id: frame
        objectName: "deckDrawerFrame"
        width: parent.width
        // The surface unrolls from the bar along its rail.
        height: parent.height * Math.max(0, Math.min(1, root.progress))
        y: root.bottomPosition ? parent.height - height : 0
        clip: true
        StyledRect { anchors.fill: parent; variant: "popup"; radius: Styling.radius(0) }

        Item {
            id: contents
            x: root.gap
            y: (root.bottomPosition ? frame.height - root.height : 0) + root.gap
                + (root.bottomPosition ? 1 : -1) * (1 - root.progress) * root.em * DeckMotion.railTravel
            width: root.width - root.gap * 2
            height: root.height - root.gap * 2
            opacity: Math.max(0, Math.min(1, root.progress * 1.6 - 0.3))

            ColumnLayout {
                id: rail
                objectName: "deckPageRail"
                visible: root.dash
                width: visible ? Math.min(root.em * 10.5, contents.width * 0.34) : 0
                height: parent.height
                spacing: root.gap

                DeckCard {
                    objectName: "deckPageNavigation"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    order: -1
                    padding: root.em * 0.35
                    Item {
                        id: tabs
                        Layout.fillWidth: true
                        Layout.preferredHeight: tabColumn.implicitHeight
                        readonly property Item current: tabRepeater.itemAt(Math.max(0, root.pages.indexOf(root.mode)))
                        StyledRect {
                            id: indicator
                            objectName: "deckRailIndicator"
                            width: parent.width
                            height: tabs.current?.height ?? 0
                            y: tabs.current?.y ?? 0
                            variant: "primary"
                            radius: Styling.radius(-6)
                            enableBorder: false
                            Behavior on y {
                                enabled: DeckMotion.enabled && root.progress > 0.99
                                NumberAnimation { duration: DeckMotion.detentDuration; easing.type: DeckMotion.detentEasing; easing.overshoot: DeckMotion.detentOvershoot }
                            }
                        }
                        ColumnLayout {
                            id: tabColumn
                            width: parent.width
                            spacing: root.em * 0.15
                            Repeater {
                                id: tabRepeater
                                model: root.pages
                                DeckAction {
                                    required property string modelData
                                    objectName: "deckPage-" + modelData
                                    kind: DeckAction.Tab
                                    Layout.fillWidth: true
                                    controlHeight: root.em * 2.3
                                    glyph: root.pageIcon(modelData)
                                    label: root.pageLabel(modelData)
                                    selected: root.mode === modelData
                                    onClicked: root.showPage(modelData)
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
                DeckCard {
                    Layout.fillWidth: true
                    order: -1
                    padding: root.em * 0.35
                    RowLayout {
                        Layout.fillWidth: true
                        DeckAction {
                            objectName: "deckDashSettings"
                            kind: DeckAction.Icon
                            glyph: Icons.gear
                            description: "Shell settings"
                            onClicked: root.openSettings("shell")
                        }
                        Item { Layout.fillWidth: true }
                        DeckAction {
                            objectName: "deckDashPower"
                            kind: DeckAction.Icon
                            glyph: Icons.power
                            description: "Power and session"
                            onClicked: root.bar.openControlMenu("power")
                        }
                    }
                }
            }

            Item {
                id: pageHost
                x: rail.visible ? rail.width + root.gap : 0
                width: contents.width - x
                height: contents.height
                clip: true
                Loader {
                    id: pageLoader
                    objectName: "deckPageContent"
                    active: root.visible
                    width: parent.width
                    height: parent.height
                    transform: Translate { id: pageShift }
                    onLoaded: {
                        if (root.pageDirection === 0 || !DeckMotion.enabled) return;
                        pageShift.y = root.pageDirection * root.em * DeckMotion.pageTravel;
                        pageEntrance.restart();
                    }
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
                        default: return controls;
                        }
                    }
                }
                NumberAnimation {
                    id: pageEntrance
                    target: pageShift
                    property: "y"
                    to: 0
                    duration: DeckMotion.pageDuration
                    easing.type: DeckMotion.travelEasing
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
    Component { id: resources; DeckResources {} }
    Component { id: battery; DeckBattery { onPowerRequested: root.bar.openControlMenu("power") } }
    Component { id: power; DeckPower { onActionRequested: action => root.executePower(action) } }
}
