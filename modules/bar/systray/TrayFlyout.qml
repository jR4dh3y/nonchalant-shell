pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.modules.components
import qs.modules.theme

BarPopup {
    id: root
    objectName: "verticalTrayFlyout"

    property int controlSize: Styling.fontSize(0) + 20
    property real maximumHeight: controlSize * 6
    property SystemTrayItem menuItem: null
    readonly property list<SystemTrayItem> trayItems: SystemTray.items.values
    readonly property bool hasItems: trayItems.length > 0
    readonly property int columns: Math.max(1, Math.min(4, trayItems.length))

    contentWidth: root.menuItem ? menu.implicitWidth + popupPadding * 2
        : grid.implicitWidth + popupPadding * 2
    contentHeight: Math.min(body.implicitHeight + popupPadding * 2, maximumHeight)

    onIsOpenChanged: {
        if (isOpen)
            root.menuItem = null;
    }
    onHasItemsChanged: {
        if (!root.hasItems)
            root.close();
    }
    onTrayItemsChanged: {
        if (root.menuItem && !root.trayItems.includes(root.menuItem))
            root.menuItem = null;
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root.isOpen
        onActivated: root.close()
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        spacing: root.popupPadding

        RowLayout {
            visible: root.menuItem !== null
            Layout.fillWidth: true
            Layout.preferredHeight: root.controlSize
            spacing: root.popupPadding

            Button {
                id: backButton
                objectName: "trayFlyoutBack"
                Layout.preferredWidth: root.controlSize
                Layout.preferredHeight: root.controlSize
                Accessible.name: "Back to system tray"
                scale: pressed ? 0.90 : 1
                PressBehavior on scale { pressed: backButton.pressed }
                background: StyledRect {
                    id: backSurface
                    variant: "common"
                    radius: Styling.radius(0)
                    HoverTint {
                        color: backSurface.item
                        hovered: backButton.hovered
                        pressed: backButton.pressed
                    }
                }
                contentItem: StyledText {
                    text: Icons.caretLeft
                    font.family: Icons.font
                    color: backSurface.item
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.menuItem = null
            }

            StyledText {
                Layout.fillWidth: true
                text: root.menuItem?.title ?? ""
                font.weight: Font.DemiBold
                color: Colors.overBackground
                elide: Text.ElideRight
            }
        }

        ScrollView {
            visible: root.menuItem === null
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: grid.implicitHeight
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            GridLayout {
                id: grid
                columns: root.columns
                columnSpacing: root.popupPadding
                rowSpacing: root.popupPadding

                Repeater {
                    model: SystemTray.items
                    delegate: SysTrayItem {
                        required property SystemTrayItem modelData
                        objectName: "trayFlyoutItem_" + modelData.id
                        item: modelData
                        Layout.preferredWidth: root.controlSize
                        Layout.preferredHeight: root.controlSize
                        hitboxSize: root.controlSize
                        trayItemSize: Styling.fontSize(6)
                        menuInFlyout: true
                        showHoverBackground: true
                        onMenuRequested: root.menuItem = modelData
                    }
                }
            }
        }

        SysTrayMenu {
            id: menu
            objectName: "trayFlyoutMenu"
            visible: root.menuItem !== null
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: implicitHeight
            menu: root.menuItem?.menu ?? null
            onActionTriggered: root.close()
        }
    }
}
