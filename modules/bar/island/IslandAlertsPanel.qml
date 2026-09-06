pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.notifications
import qs.config

Item {
    id: root

    implicitWidth: 480
    implicitHeight: 460

    signal backRequested()

    readonly property int totalCount: {
        let count = 0;
        const list = Notifications.appNameList;
        for (let i = 0; i < list.length; i++) {
            const grp = Notifications.groupsByAppName[list[i]];
            if (grp?.notifications)
                count += grp.notifications.length;
        }
        return count;
    }

    property var cascadeItems: []
    property int cascadeIndex: 0
    property bool isClearing: false

    function discardAllWithAnimation() {
        if (isClearing) return;

        const children = notificationList.contentItem.children;
        if (!children || children.length === 0) {
            Notifications.discardAllNotifications();
            return;
        }

        cascadeItems = [];
        for (let i = 0; i < children.length; i++) {
            if (children[i] && children[i].destroyWithAnimation) {
                cascadeItems.push(children[i]);
            }
        }

        if (cascadeItems.length === 0) {
            Notifications.discardAllNotifications();
            return;
        }

        isClearing = true;
        cascadeIndex = 0;

        // Animate first item immediately
        const first = cascadeItems[0];
        if (first && first.destroyWithAnimation) {
            first.destroyWithAnimation(true);
        }
        cascadeIndex = 1;

        if (cascadeItems.length > 1) {
            cascadeTimer.restart();
        } else {
            discardAllTimer.interval = Math.max(Config.animDuration || 240, 150) + 40;
            discardAllTimer.restart();
        }
    }

    Timer {
        id: cascadeTimer
        interval: 45
        repeat: true
        onTriggered: {
            if (cascadeIndex < cascadeItems.length) {
                const item = cascadeItems[cascadeIndex];
                if (item && item.destroyWithAnimation) {
                    item.destroyWithAnimation(true);
                }
                cascadeIndex++;
            } else {
                stop();
                const totalDelay = Math.max(Config.animDuration || 240, 150) + 40;
                discardAllTimer.interval = totalDelay;
                discardAllTimer.restart();
            }
        }
    }

    Timer {
        id: discardAllTimer
        interval: Math.max(Config.animDuration || 240, 150) + 40
        repeat: false
        onTriggered: {
            Notifications.discardAllNotifications();
            isClearing = false;
            cascadeItems = [];
        }
    }

    onVisibleChanged: {
        if (!visible && isClearing) {
            cascadeTimer.stop();
            discardAllTimer.stop();
            Notifications.discardAllNotifications();
            isClearing = false;
            cascadeItems = [];
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ═══════════════════════════════════════════════════════════════
        // UNIFIED HEADER: Back + Title + Count + Spacer + DND + Clear All
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 8

            // Back button
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

            // Title
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Alerts"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
            }

            // Count Pill
            StyledRect {
                visible: root.totalCount > 0
                implicitWidth: countText.implicitWidth + 12
                implicitHeight: 20
                radius: 10
                variant: "primary"

                Text {
                    id: countText
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: root.totalCount.toString()
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-3)
                    font.bold: true
                    color: Colors.overPrimary
                }
            }

            Item { Layout.fillWidth: true }

            // DND Toggle Button
            StyledRect {
                implicitWidth: 32
                implicitHeight: 28
                radius: Styling.radius(2)
                variant: Notifications.silent ? "primary" : (dndMouse.containsMouse ? "focus" : "common")

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Notifications.silent ? Icons.bellZ : Icons.bell
                    font.family: Icons.font
                    font.pixelSize: 15
                    color: Notifications.silent ? Colors.overPrimary : Colors.overBackground
                }

                MouseArea {
                    id: dndMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.silent = !Notifications.silent
                }
            }

            // Clear All Button
            StyledRect {
                visible: Notifications.appNameList.length > 0
                implicitWidth: 32
                implicitHeight: 28
                radius: Styling.radius(2)
                variant: root.isClearing ? "focus" : (broomMouse.containsMouse ? "error" : "common")

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.broom
                    font.family: Icons.font
                    font.pixelSize: 15
                    color: root.isClearing ? Colors.overSurfaceVariant : (broomMouse.containsMouse ? Colors.overError : Colors.overBackground)
                }

                MouseArea {
                    id: broomMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.isClearing
                    cursorShape: root.isClearing ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.discardAllWithAnimation()
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // NATIVE NOTIFICATIONS LIST (Single unified surface)
        // ═══════════════════════════════════════════════════════════════
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Styling.radius(2)
            variant: "internalbg"
            clip: true

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: Notifications.appNameList.length === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.bell
                    font.family: Icons.font
                    font.pixelSize: 32
                    color: Colors.overSurfaceVariant
                    opacity: 0.5
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: "No notifications"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overSurfaceVariant
                }
            }

            // Native scrollable notification list
            ListView {
                id: notificationList
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6
                model: Notifications.appNameList
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: Notifications.appNameList.length > 0

                delegate: NotificationGroup {
                    required property int index
                    required property string modelData
                    width: notificationList.width
                    notificationGroup: Notifications.groupsByAppName[modelData]
                    popup: false
                }
            }
        }
    }
}
