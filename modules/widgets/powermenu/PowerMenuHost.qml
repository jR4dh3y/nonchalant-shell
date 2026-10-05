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

    required property var panel

    property bool menuOpen: false
    readonly property int bottomOffset: 48

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

        menuOpen = true;
        powerWindow.visible = true;

        Qt.callLater(() => {
            if (!root.menuOpen)
                return;
            powerSurface.shown = true;
            powerMenuView.forceActiveFocus();
            powerMenuView.focusMenu();
        });
    }

    function closeMenu() {
        if (!menuOpen)
            return;

        menuOpen = false;
        powerSurface.shown = false;
        if (powerSurface.fullyHidden)
            powerWindow.visible = false;
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
        WlrLayershell.margins.bottom: 0

        color: "transparent"
        implicitHeight: 80 + root.bottomOffset

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

            contentWidth: powerMenuView.implicitWidth + padding * 2
            contentHeight: powerMenuView.implicitHeight + padding * 2
            originWidth: contentHeight
            fromBottom: true
            radius: Styling.radius(16)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.bottomOffset

            // Unmap only once the surface has fully retracted.
            onFullyHiddenChanged: {
                if (fullyHidden && !root.menuOpen)
                    powerWindow.visible = false;
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

        // Escape via Keys on the window content
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeMenu();
                event.accepted = true;
            }
        }
    }

    Component.onCompleted: {
        const screenName = root.panel?.targetScreen?.name ?? "";
        if (screenName)
            Visibilities.registerPowerMenuButton(screenName, root);
    }

    Component.onDestruction: {
        const screenName = root.panel?.targetScreen?.name ?? "";
        if (screenName)
            Visibilities.unregisterPowerMenuButton(screenName, root);
    }
}
