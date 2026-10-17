import QtQuick
import qs.config
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import "calendar"

Item {
    id: root
    property bool lyricsActive: false
    property string screenName: ""
    readonly property bool verticalBar: Config.bar?.style === "left"
    readonly property Item dashboardController: Visibilities.dashboardControllers[root.screenName] ?? null
    readonly property string dashboardSection: root.dashboardController?.dashboardSection ?? "notifications"
    implicitWidth: root.verticalBar ? widgetsRow.implicitWidth : 544
    implicitHeight: root.verticalBar ? Math.max(verticalControls.implicitHeight, Styling.fontSize(0) * 26) : 750

    function focusSearchInput(): void {
        if (root.verticalBar)
            sidePane.focusCurrentSection();
        else
            root.forceActiveFocus();
    }

    RowLayout {
        id: widgetsRow
        anchors.fill: parent
        spacing: 8

        FullPlayer {
            visible: !root.verticalBar
            Layout.preferredWidth: 216
            lyricsActive: !root.verticalBar && root.lyricsActive
            Layout.fillHeight: true
        }

        Calendar {
            objectName: "dashboardCalendar"
            visible: root.verticalBar
            Layout.preferredWidth: Styling.fontSize(0) * 22
            Layout.fillHeight: true
        }

        VerticalDashboardControls {
            id: verticalControls
            visible: root.verticalBar
            Layout.preferredWidth: implicitWidth
            Layout.fillHeight: true
            dashboardSection: root.dashboardSection
            onSectionRequested: section => root.dashboardController?.showDashboardSection(section)
        }

        ClippingRectangle {
            id: widgetsContainer
            visible: !root.verticalBar
            Layout.preferredWidth: quickControls.implicitWidth
            Layout.fillHeight: true
            radius: Styling.radius(4)
            color: "transparent"

            Flickable {
                id: widgetsFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: scrollColumn.implicitHeight
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                onContentHeightChanged: {
                    const maximumContentY = Math.max(0, contentHeight - height);
                    if (contentY > maximumContentY)
                        contentY = maximumContentY;
                }

                ColumnLayout {
                    id: scrollColumn
                    width: parent.width
                    spacing: 8

                    QuickControls {
                        id: quickControls
                        dashboardSection: root.dashboardSection
                        onSectionRequested: section => root.dashboardController?.toggleDashboardSection(section)

                        onExpandedPanelChanged: {
                            widgetsFlickable.contentY = 0;
                        }
                    }

                    Calendar {
                        visible: !root.verticalBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: width
                    }

                    StyledRect {
                        visible: !root.verticalBar
                        variant: "pane"
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsInner.implicitHeight + 8
                        radius: Styling.radius(4)

                        StyledRect {
                            id: settingsInner
                            anchors.fill: parent
                            anchors.margins: 4
                            variant: "internalbg"
                            radius: Styling.radius(0)
                            implicitHeight: controlsRow.implicitHeight + 8

                            RowLayout {
                                id: controlsRow
                                anchors.centerIn: parent
                                spacing: 4

                                ControlButton {
                                    id: settingsButton
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    implicitWidth: 48
                                    implicitHeight: 48
                                    iconName: Icons.gear
                                    isActive: GlobalStates.settingsWindowVisible
                                    tooltipText: "Settings"
                                    onClicked: GlobalShortcuts.toggleSettings()
                                }

                                ControlButton {
                                    id: gpuButton
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    implicitWidth: 48
                                    implicitHeight: 48
                                    iconName: Icons.gpu
                                    isActive: GpuService.nvidiaActive
                                    tooltipText: "GPU: " + GpuService.modeLabel + " · Left: switch · Right: menu"
                                    onClicked: GpuService.toggle()
                                    onRightClicked: {
                                        widgetsFlickable.contentY = 0;
                                        quickControls.togglePanel(2);
                                    }
                                    onLongPressed: {
                                        widgetsFlickable.contentY = 0;
                                        quickControls.togglePanel(2);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        NotificationHistory {
            visible: !root.verticalBar
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        DashboardSidePane {
            id: sidePane
            visible: root.verticalBar
            Layout.fillWidth: true
            Layout.fillHeight: true
            section: root.verticalBar ? root.dashboardSection : ""
            screenName: root.screenName
        }
    }
}
