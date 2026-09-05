pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    implicitWidth: 480
    implicitHeight: 125

    signal backRequested()
    signal actionTriggered()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: backMouse.containsMouse ? "focus" : "common"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowLeft
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: Colors.overBackground
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Power"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
            }

            Item { Layout.fillWidth: true }
        }

        // Action Buttons Row (Sleep, Lock, Log out, Restart, Shut down)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Sleep
            StyledRect {
                id: sleepBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                radius: Styling.radius(2)
                variant: sleepMouse.containsMouse ? "focus" : "internalbg"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.suspend
                        font.family: Icons.font
                        font.pixelSize: 20
                        color: Colors.overBackground
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: "Sleep"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                    }
                }

                MouseArea {
                    id: sleepMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["systemctl", "suspend"]);
                        root.actionTriggered();
                    }
                }
            }

            // Lock
            StyledRect {
                id: lockBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                radius: Styling.radius(2)
                variant: lockMouse.containsMouse ? "focus" : "internalbg"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.lock
                        font.family: Icons.font
                        font.pixelSize: 20
                        color: Colors.overBackground
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: "Lock"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                    }
                }

                MouseArea {
                    id: lockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        LockscreenService.lock();
                        root.actionTriggered();
                    }
                }
            }

            // Log out
            StyledRect {
                id: logoutBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                radius: Styling.radius(2)
                variant: logoutMouse.containsMouse ? "focus" : "internalbg"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.logout
                        font.family: Icons.font
                        font.pixelSize: 20
                        color: Colors.overBackground
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: "Log out"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                    }
                }

                MouseArea {
                    id: logoutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]);
                        root.actionTriggered();
                    }
                }
            }

            // Restart
            StyledRect {
                id: rebootBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                radius: Styling.radius(2)
                variant: rebootMouse.containsMouse ? "focus" : "internalbg"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.reboot
                        font.family: Icons.font
                        font.pixelSize: 20
                        color: Colors.overBackground
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: "Restart"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                    }
                }

                MouseArea {
                    id: rebootMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["systemctl", "reboot"]);
                        root.actionTriggered();
                    }
                }
            }

            // Shut down
            StyledRect {
                id: shutdownBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                radius: Styling.radius(2)
                variant: shutdownMouse.containsMouse ? "focus" : "internalbg"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.shutdown
                        font.family: Icons.font
                        font.pixelSize: 20
                        color: Colors.red
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: "Shut down"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.red
                    }
                }

                MouseArea {
                    id: shutdownMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["systemctl", "poweroff"]);
                        root.actionTriggered();
                    }
                }
            }
        }
    }
}
