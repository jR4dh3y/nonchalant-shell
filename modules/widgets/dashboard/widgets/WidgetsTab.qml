import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import "calendar"

Rectangle {
    color: "transparent"
    implicitWidth: 544
    implicitHeight: 750

    property int leftPanelWidth: 0

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
