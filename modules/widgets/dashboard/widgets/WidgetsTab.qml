import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import "calendar"

Rectangle {
    id: root

    color: "transparent"
    implicitWidth: 544
    implicitHeight: 750

    RowLayout {
        anchors.fill: parent
        spacing: 8

        FullPlayer {
            Layout.preferredWidth: 216
            Layout.fillHeight: true
        }

        ClippingRectangle {
            id: widgetsContainer
            Layout.preferredWidth: quickControls.implicitWidth
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
                        id: quickControls
                    }

                    Calendar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width
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
