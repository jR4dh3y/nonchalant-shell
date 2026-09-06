pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.notifications

Item {
    id: root

    readonly property var activeNotif: {
        const list = Notifications.popupList;
        if (!list || list.length === 0)
            return null;
        return list[list.length - 1];
    }
    readonly property int notifId: activeNotif && activeNotif.id !== undefined ? Number(activeNotif.id) : NaN
    readonly property string appName: activeNotif ? String(activeNotif.appName || "") : ""
    readonly property string summary: activeNotif ? String(activeNotif.summary || "") : ""
    readonly property string body: activeNotif ? String(activeNotif.body || "") : ""
    readonly property bool isCritical: {
        if (!activeNotif)
            return false;
        const u = activeNotif.urgency;
        return u === 2 || u === "critical" || String(u).toLowerCase() === "critical";
    }
    readonly property int count: Notifications.popupList ? Notifications.popupList.length : 0

    implicitWidth: 420
    implicitHeight: activeNotif ? Math.max(contentCol.implicitHeight + 24, 76) : 0

    signal dismissRequested

    onActiveNotifChanged: {
        if (!activeNotif) {
            root.dismissRequested();
        }
    }

    function dismissCurrent() {
        if (!isNaN(root.notifId)) {
            Notifications.clearPopupById(root.notifId);
        }
        if (root.appName) {
            Notifications.dismissPopupApp(root.appName);
        }
        if (isNaN(root.notifId) && !root.appName) {
            Notifications.dismissAllPopups();
        }
        root.dismissRequested();
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && !isNaN(root.notifId)) {
                Notifications.attemptInvokeAction(root.notifId, "default", false);
            }
            root.dismissCurrent();
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (!root.appName)
                return;
            if (hovered)
                Notifications.pauseGroupTimers(root.appName);
            else
                Notifications.resumeGroupTimers(root.appName);
        }
    }

    ColumnLayout {
        id: contentCol
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 6

        // Header: App icon / Bell + App Name + Count Badge + Dismiss Button
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter

                NotificationAppIcon {
                    id: appIconItem
                    anchors.centerIn: parent
                    size: 18
                    scale: 18 / 48
                    appIcon: root.activeNotif?.appIcon ?? ""
                    appName: root.appName
                    summary: root.summary
                    visible: (root.activeNotif?.appIcon ?? "").length > 0 && !appIconFailed
                }

                Text {
                    visible: !appIconItem.visible
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    anchors.centerIn: parent
                    text: root.isCritical ? Icons.alert : Icons.bell
                    font.family: Icons.font
                    font.pixelSize: 15
                    color: root.isCritical ? Colors.error : Styling.srItem("overprimary")
                }
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.appName || "Notification"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.overBackground
                elide: Text.ElideRight
            }

            Text {
                visible: root.count > 1
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                Layout.alignment: Qt.AlignVCenter
                text: "+" + (root.count - 1)
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.fontSize(-2)
                font.bold: true
                color: Styling.srItem("overprimary")
            }

            // Dismiss 'x' button
            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                }

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    anchors.centerIn: parent
                    text: Icons.cancel
                    font.family: Icons.font
                    font.pixelSize: 13
                    color: closeMouse.containsMouse ? Colors.overBackground : Colors.outline
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismissCurrent()
                }
            }
        }

        // Summary text
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            Layout.fillWidth: true
            visible: root.summary.length > 0
            text: root.summary
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize
            font.weight: Font.DemiBold
            color: Colors.overBackground
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        // Body text
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            Layout.fillWidth: true
            visible: root.body.length > 0
            text: root.body
            textFormat: Text.StyledText
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.outline
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }
}
