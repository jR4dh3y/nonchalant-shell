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

    color: "transparent"
    implicitWidth: 544
    implicitHeight: 750

    RowLayout {
        anchors.fill: parent
        spacing: 8

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
                            if (expandedPanel === -1)
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
                            implicitHeight: settingsButton.implicitHeight + 8

                            ControlButton {
                                id: settingsButton
                                anchors.centerIn: parent
                                implicitWidth: 48
                                implicitHeight: 48
                                iconName: Icons.gear
                                isActive: GlobalStates.settingsWindowVisible
                                tooltipText: "Settings"
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
