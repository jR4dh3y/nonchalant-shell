pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme

ScrollView {
    id: root

    property QsMenuHandle menu: null
    signal actionTriggered()

    implicitWidth: Styling.fontSize(0) * 16
    implicitHeight: itemsColumn.implicitHeight
    contentWidth: availableWidth
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    QsMenuOpener {
        id: menuOpener
        menu: root.menu
    }

    ColumnLayout {
        id: itemsColumn
        width: root.availableWidth
        spacing: 2

        Repeater {
            model: menuOpener.children?.values ?? []

            delegate: ColumnLayout {
                id: menuGroup
                required property QsMenuEntry modelData
                property bool submenuExpanded: false
                Layout.fillWidth: true
                spacing: 2

                SystrayMenuItem {
                    objectName: "trayMenuAction_" + textStr
                    Layout.fillWidth: true
                    textStr: menuGroup.modelData?.text ?? ""
                    iconSource: menuGroup.modelData?.icon ?? ""
                    isImageIcon: iconSource.includes("/") || iconSource.includes(".")
                    isSeparator: menuGroup.modelData?.isSeparator ?? false
                    enabled: (menuGroup.modelData?.enabled ?? false) && !isSeparator
                    hasSubmenu: menuGroup.modelData?.hasChildren ?? false
                    expanded: menuGroup.submenuExpanded
                    buttonType: menuGroup.modelData?.buttonType ?? 0
                    checkState: menuGroup.modelData?.checkState ?? 0
                    onClicked: {
                        if (!menuGroup.modelData)
                            return;
                        if (menuGroup.modelData.hasChildren) {
                            menuGroup.submenuExpanded = !menuGroup.submenuExpanded;
                        } else {
                            menuGroup.modelData.triggered();
                            root.actionTriggered();
                        }
                    }
                }

                ColumnLayout {
                    visible: menuGroup.submenuExpanded && (menuGroup.modelData?.hasChildren ?? false)
                    Layout.fillWidth: true
                    spacing: 2

                    QsMenuOpener {
                        id: subMenuOpener
                        menu: menuGroup.submenuExpanded ? menuGroup.modelData : null
                    }

                    Repeater {
                        model: subMenuOpener.children?.values ?? []

                        delegate: SystrayMenuItem {
                            required property QsMenuEntry modelData
                            objectName: "trayMenuAction_" + textStr
                            Layout.fillWidth: true
                            depth: 1
                            textStr: modelData?.text ?? ""
                            iconSource: modelData?.icon ?? ""
                            isImageIcon: iconSource.includes("/") || iconSource.includes(".")
                            isSeparator: modelData?.isSeparator ?? false
                            enabled: (modelData?.enabled ?? false) && !isSeparator
                            buttonType: modelData?.buttonType ?? 0
                            checkState: modelData?.checkState ?? 0
                            onClicked: {
                                if (!modelData)
                                    return;
                                modelData.triggered();
                                root.actionTriggered();
                            }
                        }
                    }
                }
            }
        }
    }
}
