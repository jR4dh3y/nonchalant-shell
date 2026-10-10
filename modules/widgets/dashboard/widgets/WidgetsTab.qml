import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import "calendar"

Rectangle {
    id: root
    property bool lyricsActive: false

    color: "transparent"
    implicitWidth: 544
    implicitHeight: 750

    RowLayout {
        anchors.fill: parent
        spacing: 8

        FullPlayer {
            Layout.preferredWidth: 216
            lyricsActive: root.lyricsActive
            Layout.fillHeight: true
        }

        ClippingRectangle {
            id: widgetsContainer
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

                        onExpandedPanelChanged: {
                            widgetsFlickable.contentY = 0;
                        }
                    }

                    Calendar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width
                    }

                    StyledRect {
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
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
