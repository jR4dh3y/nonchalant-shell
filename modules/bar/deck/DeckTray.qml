pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.modules.components
import qs.modules.theme

ColumnLayout {
    id: root
    property QsMenuHandle menu: null
    property SystemTrayItem menuItem: null
    readonly property list<SystemTrayItem> items: SystemTray.items.values
    property list<QsMenuHandle> history: []
    signal actionTriggered()
    function resetMenu(): void { menu = null; menuItem = null; history = []; }
    onItemsChanged: if (menuItem && !items.includes(menuItem)) resetMenu()
    spacing: Styling.fontSize(0) * 0.5
    DeckCard {
        objectName: "deckTrayHeader"
        Layout.fillWidth: true
        order: 0
        padding: Styling.fontSize(0) * 0.4
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Styling.fontSize(0) * 2
            DeckAction {
                objectName: "deckTrayBack"
                visible: root.menu !== null
                glyph: Icons.caretLeft
                label: "Back"
                onClicked: {
                    if (root.history.length > 0) {
                        root.menu = root.history[root.history.length - 1];
                        root.history = root.history.slice(0, -1);
                    } else root.resetMenu();
                }
            }
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: root.menu === null ? Styling.fontSize(0) * 0.4 : 0
                text: root.menuItem ? (root.menuItem.title || root.menuItem.id) : "Background apps"
                elide: Text.ElideRight
                font.weight: Font.DemiBold
            }
        }
    }
    DeckCard {
        objectName: "deckTrayBody"
        Layout.fillWidth: true
        Layout.fillHeight: true
        order: 1
        ScrollView {
            id: list
            objectName: "deckTrayList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ColumnLayout {
                width: list.availableWidth
                spacing: Styling.fontSize(0) * 0.5
                Flow {
                    visible: root.menu === null
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    spacing: Styling.fontSize(0) * 0.5
                    Repeater {
                        model: SystemTray.items
                        DeckAction {
                            required property SystemTrayItem modelData
                            objectName: "deckTrayItem-" + (modelData?.id ?? "")
                            imageSource: modelData?.icon ?? ""
                            label: modelData?.title || modelData?.id || "Background app"
                            description: label + " · Right-click for menu"
                            onClicked: {
                                if (!modelData) return;
                                if (modelData.onlyMenu && modelData.hasMenu) { root.menuItem = modelData; root.menu = modelData.menu; }
                                else { modelData.activate(); root.actionTriggered(); }
                            }
                            onSecondaryClicked: if (modelData?.hasMenu) { root.menuItem = modelData; root.menu = modelData.menu; }
                        }
                    }
                }
                QsMenuOpener { id: opener; menu: root.menu }
                Repeater {
                    model: root.menu ? (opener.children?.values ?? []) : []
                    DeckAction {
                        required property QsMenuEntry modelData
                        objectName: "deckTrayMenu-" + (modelData?.text ?? "")
                        Layout.fillWidth: true
                        visible: modelData !== null && !modelData.isSeparator
                        enabled: modelData?.enabled ?? false
                        imageSource: modelData?.icon ?? ""
                        glyph: modelData?.hasChildren ? Icons.caretRight : (modelData?.checkState === Qt.Checked ? Icons.check : "")
                        label: modelData?.text ?? ""
                        maximumLabelWidth: root.width
                        onClicked: {
                            if (!modelData) return;
                            if (modelData.hasChildren) {
                                root.history = root.history.concat([root.menu]);
                                root.menu = modelData;
                            } else { modelData.triggered(); root.actionTriggered(); }
                        }
                    }
                }
                StyledText {
                    visible: SystemTray.items.values.length === 0
                    text: "No background apps in the system tray."
                    color: Colors.overSurfaceVariant
                }
            }
        }
    }
    onVisibleChanged: if (!visible) resetMenu()
}
