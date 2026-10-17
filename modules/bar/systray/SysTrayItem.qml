import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components

MouseArea {
    id: root

    required property SystemTrayItem item
    property int trayItemSize: 20
    property int hitboxSize: trayItemSize
    property bool vertical: false
    property bool isHovered: false
    property bool menuInFlyout: false
    property bool showHoverBackground: false
    signal menuRequested()

    function openMenu(): void {
        if (root.menuInFlyout)
            root.menuRequested();
        else
            systrayPopup.toggle();
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    Layout.fillHeight: true
    implicitWidth: hitboxSize
    implicitHeight: hitboxSize

    onClicked: event => {
        switch (event.button) {
        case Qt.LeftButton:
            if (item.onlyMenu && item.hasMenu) {
                root.openMenu();
            } else {
                Visibilities.closeActiveBarPopup();
                item.activate();
            }
            break;
        case Qt.RightButton:
            if (item.hasMenu) {
                root.openMenu();
            }
            break;
        }
        event.accepted = true;
    }

    BarPopup {
        id: systrayPopup
        anchorItem: root

        // Use a reasonable width for the menu
        contentWidth: 220
        // Height adapts to content, with a max limit if needed.
        // Must include vertical padding (8 top + 8 bottom = 16)
        contentHeight: Math.min(trayMenu.implicitHeight + 16, 400)

        popupPadding: 8
        // 8px standard margin + 8px SysTray container padding to ensure correct offset from the main bar
        visualMargin: 16

        SysTrayMenu {
            id: trayMenu
            anchors.fill: parent
            menu: root.menuInFlyout ? null : (root.item?.menu ?? null)
            onActionTriggered: systrayPopup.close()
        }
    }

    Item {
        id: iconContainer
        anchors.fill: parent
        scale: root.pressed ? 0.90 : 1.0

        PressBehavior on scale {
            pressed: root.pressed
        }

        StyledRect {
            anchors.fill: parent
            variant: "focus"
            backgroundOpacity: root.showHoverBackground && (root.isHovered || root.pressed) ? -1 : 0
            enableBorder: false
            radius: Styling.radius(0)
        }

        IconImage {
            id: trayIcon
            source: {
                const iconPath = String(root.item?.icon ?? "");
                if (iconPath.includes("spotify")) {
                    return Quickshell.iconPath("spotify-client");
                }
                return root.item?.icon ?? "";
            }
            anchors.centerIn: parent
            width: root.trayItemSize
            height: root.trayItemSize
            smooth: true
        }

        Tinted {
            sourceItem: trayIcon
            anchors.fill: trayIcon
        }
    }

    StyledToolTip {
        x: root.vertical ? root.width + 8 : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 : -height
        show: root.isHovered
        tooltipText: root.item?.tooltipTitle || root.item?.title || ""
        description: root.item?.tooltipDescription || ""
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }
}
