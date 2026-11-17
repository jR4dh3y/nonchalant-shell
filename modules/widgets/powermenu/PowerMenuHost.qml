pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.components
import qs.modules.theme
import qs.modules.services
import qs.config

// Super+X / IPC host. A revealed left dock turns its own controls into power
// actions; every other layout gets the popup.
Item {
    id: root

    required property ShellScreen targetScreen

    property bool menuOpen: false
    property bool revealed: false
    readonly property int bottomOffset: 48
    // Set by a revealed LeftBar on this screen while it exists.
    property bool dockShown: false
    readonly property bool inDock: Config.bar.style === "left" && dockShown
    readonly property bool dockModeOpen: menuOpen && inDock
    readonly property alias dockMode: dockMode
    readonly property bool fullyHidden: powerSurface.fullyHidden
    onFullyHiddenChanged: {
        if (fullyHidden && !menuOpen)
            powerWindow.visible = false;
    }
    // The dock or popup this menu opened in went away.
    onInDockChanged: closeMenu()

    readonly property bool popupOpen: menuOpen
    // Keep a tiny host for Visibilities registration; real UI is powerWindow
    // or the dock.
    width: 1
    height: 1
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter

    function togglePopup() {
        if (menuOpen)
            closeMenu();
        else
            openMenu();
    }

    function openMenu() {
        Visibilities.setActiveModule("");
        Visibilities.closeActiveBarPopup();

        menuOpen = true;
        if (inDock) {
            // A popup still collapsing from a dock switch must not keep
            // its exclusive keyboard focus and backdrop.
            root.revealed = false;
            powerWindow.visible = false;
            dockMode.show();
            return;
        }
        powerWindow.visible = true;

        Qt.callLater(() => {
            if (!root.menuOpen)
                return;
            root.revealed = true;
            menuLoader.item?.focusMenu();
        });
    }

    function closeMenu() {
        if (!menuOpen)
            return;

        menuOpen = false;
        dockMode.hide();
        root.revealed = false;
        if (root.fullyHidden)
            powerWindow.visible = false;
    }

    function run(action: string): void {
        closeMenu();
        if (action === "lock") LockscreenService.lock();
        else if (action === "logout") CompositorService.logout();
        else if (["suspend", "hibernate", "reboot", "poweroff"].includes(action))
            Quickshell.execDetached(["systemctl", action]);
    }

    LeftPowerMode {
        id: dockMode
        onActionRequested: action => root.run(action)
        onCloseRequested: root.closeMenu()
    }

    // Another shell surface, or focus on another monitor, takes over.
    Connections {
        target: Visibilities
        function onCurrentActiveModuleChanged() {
            if (Visibilities.currentActiveModule)
                root.closeMenu();
        }
        function onActiveBarPopupChanged() {
            if (Visibilities.activeBarPopup)
                root.closeMenu();
        }
    }

    Connections {
        target: CompositorService
        function onFocusedMonitorChanged() {
            const name = CompositorService.focusedMonitor?.name ?? "";
            if (name && name !== root.screenName)
                root.closeMenu();
        }
    }

    // A separate layer owns keyboard focus without changing bar input regions.
    PanelWindow {
        id: powerWindow
        screen: root.targetScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        visible: false

        WlrLayershell.namespace: "nonchalant:powermenu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        WlrLayershell.margins.bottom: 0

        color: "transparent"
        implicitHeight: powerSurface.contentHeight + root.bottomOffset + powerSurface.maxStretch

        // Click outside the pill dismisses.
        MouseArea {
            anchors.fill: parent
            enabled: root.menuOpen
            onClicked: root.closeMenu()
        }

        FocusGrab {
            active: root.menuOpen
            windows: [powerWindow]
            onCleared: root.closeMenu()
        }

        MorphSurface {
            id: powerSurface
            objectName: "powerMenuMorph"

            contentWidth: (menuLoader.item?.implicitWidth ?? 0) + padding * 2
            contentHeight: (menuLoader.item?.implicitHeight ?? 0) + padding * 2
            originWidth: contentHeight
            fromBottom: true
            shown: root.revealed
            radius: Styling.radius(16)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.bottomOffset * powerSurface.revealClamped

            // Block backdrop click-through on the pill itself.
            MouseArea {
                anchors.fill: parent
                enabled: root.menuOpen
                onClicked: {}
            }

            Loader {
                id: menuLoader
                focus: true
                anchors.centerIn: parent
                onLoaded: { if (root.menuOpen) item.focusMenu(); }
                sourceComponent: PowerMenuView {
                    popupMode: true
                    expanded: root.menuOpen
                    onCloseRequested: root.closeMenu()
                }
            }
        }
    }

    readonly property string screenName: root.targetScreen?.name ?? ""
    property string registeredScreenName: ""

    function syncRegistration(): void {
        if (registeredScreenName === screenName)
            return;
        if (registeredScreenName)
            Visibilities.unregisterPowerMenuButton(registeredScreenName, root);
        registeredScreenName = screenName;
        if (registeredScreenName)
            Visibilities.registerPowerMenuButton(registeredScreenName, root);
    }

    onScreenNameChanged: {
        closeMenu();
        syncRegistration();
    }
    Component.onCompleted: syncRegistration()
    Component.onDestruction: {
        if (registeredScreenName)
            Visibilities.unregisterPowerMenuButton(registeredScreenName, root);
    }
}
