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

    readonly property bool popupOpen: powerWindow.visible
    // Keep a tiny host for Visibilities registration; real UI is powerWindow.
    width: 1
    height: 1
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter

    function togglePopup() {
        if (powerWindow.visible)
            closeMenu();
        else
            openMenu();
    }

    function openMenu() {
        Visibilities.setActiveModule("");
        Visibilities.closeActiveBarPopup();
        powerWindow.visible = true;
        Qt.callLater(() => {
            powerMenuView.forceActiveFocus();
            powerMenuView.focusMenu();
        });
    }

    function closeMenu() {
        powerWindow.visible = false;
    }

    // Dedicated overlay so position matches OSD (bottom center, 48px up).
    PanelWindow {
        id: powerWindow
        screen: root.panel?.targetScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        visible: false

        WlrLayershell.namespace: "nonchalant:powermenu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
            onClicked: root.closeMenu()
        }

        FocusGrab {
            active: powerWindow.visible
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

                // Block backdrop click-through on the pill itself.
                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                PowerMenuView {
                    id: powerMenuView
                    anchors.centerIn: parent
                    popupMode: true
                    expanded: powerWindow.visible
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
