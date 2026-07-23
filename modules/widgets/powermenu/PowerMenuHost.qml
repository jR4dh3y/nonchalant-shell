pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.components
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.globals

// Keyboard-only power menu (Super+X). Same bottom-center band as volume OSD.
Item {
    id: root

    required property var bar
    required property var panel

    // Logical open state (true while open or mid-close animation).
    property bool menuOpen: false
    property bool menuShown: false
    property real menuOpacity: 0
    property real menuScale: 0.96

    readonly property bool popupOpen: menuOpen
    // Keep a tiny host for Visibilities registration; real UI is powerWindow.
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

        closeTimer.stop();
        menuOpen = true;
        menuShown = true;
        powerWindow.visible = true;

        // Start slightly present, then animate in next frame.
        if (menuOpacity < 0.01) {
            menuOpacity = 0;
            menuScale = 0.96;
        }

        Qt.callLater(() => {
            if (!root.menuOpen)
                return;
            menuOpacity = 1;
            menuScale = 1;
            powerMenuView.forceActiveFocus();
            powerMenuView.focusMenu();
        });
    }

    function closeMenu() {
        if (!menuOpen && !powerWindow.visible)
            return;

        menuOpen = false;
        menuOpacity = 0;
        menuScale = 0.96;
        closeTimer.interval = Config.animDuration > 0
            ? Math.max(Config.animDuration / 2, 80) + 40
            : 40;
        closeTimer.restart();
    }

    Timer {
        id: closeTimer
        interval: 40
        onTriggered: {
            if (root.menuOpen)
                return;
            root.menuShown = false;
            powerWindow.visible = false;
        }
    }

    // Dedicated overlay so position matches OSD (bottom center, 48px up).
    PanelWindow {
        id: powerWindow
        screen: root.panel?.targetScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        visible: false

        WlrLayershell.namespace: "nonchalant:powermenu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        WlrLayershell.margins.bottom: 48

        color: "transparent"
        implicitHeight: 80

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

        Item {
            anchors.fill: parent

            StyledRect {
                id: powerWrapper
                variant: "popup"
                radius: Styling.radius(16)
                enableShadow: false
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: powerMenuView.implicitWidth + 16
                height: powerMenuView.implicitHeight + 16
                visible: root.menuShown
                opacity: root.menuOpacity
                scale: root.menuScale
                transformOrigin: Item.Bottom

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on scale {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }

                // Block backdrop click-through on the pill itself.
                MouseArea {
                    anchors.fill: parent
                    enabled: root.menuOpen
                    onClicked: {}
                }

                PowerMenuView {
                    id: powerMenuView
                    anchors.centerIn: parent
                    popupMode: true
                    expanded: root.menuOpen
                    onCloseRequested: root.closeMenu()
                }
            }
        }

        // Escape via Keys on the window content
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeMenu();
                event.accepted = true;
            }
        }
    }

    Component.onCompleted: {
        const screenName = root.bar?.screen?.name ?? root.panel?.targetScreen?.name ?? "";
        if (screenName)
            Visibilities.registerPowerMenuButton(screenName, root);
    }

    Component.onDestruction: {
        const screenName = root.bar?.screen?.name ?? root.panel?.targetScreen?.name ?? "";
        if (screenName)
            Visibilities.unregisterPowerMenuButton(screenName, root);
    }
}
