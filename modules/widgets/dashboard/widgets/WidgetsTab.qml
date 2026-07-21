import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import "calendar"

Rectangle {
    id: root

    color: "transparent"
    implicitWidth: 544
    implicitHeight: 750

    property int leftPanelWidth: 0

    component LaunchTile: StyledRect {
        id: tile

        required property string iconName
        required property string label

        signal clicked()

        variant: tileMouse.containsMouse ? "focus" : "internalbg"
        radius: Styling.radius(4)

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.iconName
                color: tile.item
                font.family: Icons.font
                font.pixelSize: 24
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                color: tile.item
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        FullPlayer {
            Layout.preferredWidth: 216
            Layout.fillHeight: true
        }

        ClippingRectangle {
            id: widgetsContainer
            Layout.preferredWidth: controlButtonsContainer.implicitWidth
            Layout.fillHeight: true
            radius: Styling.radius(4)
            color: "transparent"

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: columnLayout.implicitHeight
                clip: true

                ColumnLayout {
                    id: columnLayout
                    width: parent.width
                    spacing: 8

                    QuickControls {
                        id: controlButtonsContainer
                    }

                    Calendar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width
                    }

                    StyledRect {
                        variant: "pane"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            LaunchTile {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                iconName: Icons.wallpapers
                                label: "Wallpapers"
                                onClicked: GlobalStates.dashboardCurrentTab = 1
                            }

                            LaunchTile {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                iconName: Icons.gear
                                label: "Settings"
                                onClicked: GlobalShortcuts.toggleSettings()
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
