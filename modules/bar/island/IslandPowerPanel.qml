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

    // Keyboard selection: -1 = none. IslandBar routes Left/Right/Return here.
    property int selectedIndex: -1
    readonly property int actionCount: 5

    function resetSelection() {
        selectedIndex = -1;
    }

    function moveSelection(delta: int) {
        selectedIndex = (((selectedIndex + delta) % actionCount) + actionCount) % actionCount;
    }

    function activateSelected() {
        if (selectedIndex === 0)
            doSuspend();
        else if (selectedIndex === 1)
            doLock();
        else if (selectedIndex === 2)
            doLogout();
        else if (selectedIndex === 3)
            doReboot();
        else if (selectedIndex === 4)
            doShutdown();
    }

    function doSuspend() {
        Quickshell.execDetached(["systemctl", "suspend"]);
        root.actionTriggered();
    }

    function doLock() {
        LockscreenService.lock();
        root.actionTriggered();
    }

    function doLogout() {
        Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]);
        root.actionTriggered();
    }

    function doReboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
        root.actionTriggered();
    }

    function doShutdown() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
        root.actionTriggered();
    }

    onVisibleChanged: {
        if (!visible)
            resetSelection();
    }

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

        // Action Buttons Row (icon-only, arrow-key navigable)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Sleep
            StyledRect {
                id: sleepBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: Styling.radius(2)
                variant: (sleepMouse.containsMouse || root.selectedIndex === 0) ? "focus" : "internalbg"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.suspend
                    font.family: Icons.font
                    font.pixelSize: 20
                    color: Colors.overBackground
                }

                MouseArea {
                    id: sleepMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doSuspend()
                }
            }

            // Lock
            StyledRect {
                id: lockBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: Styling.radius(2)
                variant: (lockMouse.containsMouse || root.selectedIndex === 1) ? "focus" : "internalbg"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.lock
                    font.family: Icons.font
                    font.pixelSize: 20
                    color: Colors.overBackground
                }

                MouseArea {
                    id: lockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doLock()
                }
            }

            // Log out
            StyledRect {
                id: logoutBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: Styling.radius(2)
                variant: (logoutMouse.containsMouse || root.selectedIndex === 2) ? "focus" : "internalbg"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.logout
                    font.family: Icons.font
                    font.pixelSize: 20
                    color: Colors.overBackground
                }

                MouseArea {
                    id: logoutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doLogout()
                }
            }

            // Restart
            StyledRect {
                id: rebootBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: Styling.radius(2)
                variant: (rebootMouse.containsMouse || root.selectedIndex === 3) ? "focus" : "internalbg"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.reboot
                    font.family: Icons.font
                    font.pixelSize: 20
                    color: Colors.overBackground
                }

                MouseArea {
                    id: rebootMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doReboot()
                }
            }

            // Shut down
            StyledRect {
                id: shutdownBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: Styling.radius(2)
                variant: (shutdownMouse.containsMouse || root.selectedIndex === 4) ? "focus" : "internalbg"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.shutdown
                    font.family: Icons.font
                    font.pixelSize: 20
                    color: Colors.red
                }

                MouseArea {
                    id: shutdownMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doShutdown()
                }
            }
        }
    }
}
