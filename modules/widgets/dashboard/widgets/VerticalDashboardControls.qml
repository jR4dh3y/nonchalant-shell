pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    property string dashboardSection: "notifications"
    signal sectionRequested(string section)
    readonly property Item selectedControl: root.dashboardSection === "notifications" ? notificationsButton
        : root.dashboardSection === "wallpapers" ? wallpapersButton
        : root.dashboardSection === "stats" ? statsButton : null
    implicitWidth: viewIsland.implicitWidth
    implicitHeight: viewIsland.implicitHeight + staticIsland.implicitHeight + islands.spacing * 2

    ColumnLayout {
        id: islands
        anchors.fill: parent
        spacing: 8

        StyledRect {
            id: viewIsland
            objectName: "dashboardViewControlsIsland"
            variant: "pane"
            radius: Styling.radius(4)
            implicitWidth: viewButtons.implicitWidth + 16
            implicitHeight: viewButtons.implicitHeight + 16
            Layout.fillWidth: true

            ElasticHighlight {
                objectName: "dashboardViewHighlight"
                targetItem: root.selectedControl
                originX: viewButtons.x
                originY: viewButtons.y
                radius: Styling.radius(0)
                variant: root.selectedControl?.isHovered ? "primaryfocus" : "primary"
                scale: root.selectedControl?.scale ?? 1
            }

            ColumnLayout {
                id: viewButtons
                z: 1
                anchors.centerIn: parent
                spacing: 4

                ControlButton {
                    id: notificationsButton
                    externalHighlight: true
                    objectName: "dashboardNotificationsButton"
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    iconName: Icons.bell
                    isActive: root.dashboardSection === "notifications"
                    tooltipText: "Notifications"
                    onClicked: root.sectionRequested("notifications")
                }

                ControlButton {
                    id: wallpapersButton
                    externalHighlight: true
                    objectName: "dashboardWallpapersButton"
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    iconName: Icons.wallpapers
                    isActive: root.dashboardSection === "wallpapers"
                    tooltipText: "Wallpapers"
                    onClicked: root.sectionRequested("wallpapers")
                }

                ControlButton {
                    id: statsButton
                    externalHighlight: true
                    objectName: "dashboardStatsButton"
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    iconName: Icons.circuitry
                    isActive: root.dashboardSection === "stats"
                    tooltipText: "System Monitor"
                    onClicked: root.sectionRequested("stats")
                }
            }
        }

        Item { Layout.fillHeight: true }

        StyledRect {
            id: staticIsland
            objectName: "dashboardStaticControlsIsland"
            variant: "pane"
            radius: Styling.radius(4)
            implicitWidth: staticButtons.implicitWidth + 16
            implicitHeight: staticButtons.implicitHeight + 16
            Layout.fillWidth: true

            ColumnLayout {
                id: staticButtons
                anchors.centerIn: parent
                spacing: 4

                ControlButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    iconName: Icons.gear
                    isActive: GlobalStates.settingsWindowVisible
                    tooltipText: "Settings"
                    onClicked: GlobalShortcuts.toggleSettings()
                }

                CircularControl {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    icon: Icons.nightLight
                    value: NightLightService.normalizedTemperature
                    accentColor: Styling.srItem("overprimary")
                    isToggleable: true
                    isToggled: NightLightService.active
                    showMeter: NightLightService.active
                    tooltipText: NightLightService.active
                        ? "Night Light: " + NightLightService.temperature + " K"
                        : "Night Light: Off"
                    onControlValueChanged: newValue => NightLightService.setTemperatureFromNormalized(newValue)
                    onToggled: NightLightService.toggle()
                }
            }
        }
    }
}
