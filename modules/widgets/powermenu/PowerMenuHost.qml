pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.components
import qs.modules.theme
import qs.modules.services
import qs.config

// Invisible power-menu host: no bar icon. Opened via Super+X / IPC only.
// Anchor sits at the top-right of the shell panel (where the pill used to be).
Item {
    id: root

    required property var bar
    required property var panel

    readonly property bool popupOpen: powerPopup.isOpen
    width: 36
    height: 36

    // Track bar edge so the popup still opens near the old control position.
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: {
        if (!bar)
            return 8;
        if (bar.barPosition === "top")
            return Math.max(bar.topOuterMargin || 0, 4);
        if (bar.barPosition === "bottom")
            return Math.max((panel?.height || 0) - (bar.totalBarHeight || 44) - 4, 4);
        return 8;
    }
    anchors.rightMargin: {
        if (!bar)
            return 8;
        return Math.max(bar.rightOuterMargin || 0, 8) + 4;
    }

    function togglePopup() {
        if (powerPopup.isOpen)
            powerPopup.close();
        else {
            Visibilities.setActiveModule("");
            powerPopup.open();
        }
    }

    BarPopup {
        id: powerPopup
        anchorItem: root
        bar: root.bar
        variant: "transparent"
        popupPadding: 0
        visualMargin: 8
        // Keyboard must reach ActionGrid for arrow navigation.
        closeOnFocusLost: true

        contentWidth: powerWrapper.width
        contentHeight: powerWrapper.height

        onIsOpenChanged: {
            if (isOpen) {
                Qt.callLater(() => {
                    powerMenuView.forceActiveFocus();
                    powerMenuView.focusMenu();
                });
            }
        }

        StyledRect {
            id: powerWrapper
            variant: "popup"
            radius: Styling.radius(8)
            enableShadow: false
            width: powerMenuView.implicitWidth + 12
            height: powerMenuView.implicitHeight + 12

            PowerMenuView {
                id: powerMenuView
                anchors.centerIn: parent
                popupMode: true
                expanded: powerPopup.isOpen
                onCloseRequested: powerPopup.close()
            }
        }
    }

    Component.onCompleted: {
        const screenName = root.bar?.screen?.name ?? "";
        if (screenName)
            Visibilities.registerPowerMenuButton(screenName, root);
    }

    Component.onDestruction: {
        const screenName = root.bar?.screen?.name ?? "";
        if (screenName)
            Visibilities.unregisterPowerMenuButton(screenName, root);
    }
}
