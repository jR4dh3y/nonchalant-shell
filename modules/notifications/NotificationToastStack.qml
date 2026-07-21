pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

// In-panel toast stack. Visual card is non-interactive; a full-card MouseArea
// sits on top and dismisses by Notif id (app-name matching was unreliable).
Item {
    id: root

    readonly property int popupCount: Notifications.popupList ? Notifications.popupList.length : 0
    readonly property bool hasPopups: popupCount > 0
    readonly property Item hitbox: hasPopups ? toastColumn : null

    visible: hasPopups
    width: 360
    height: Math.max(toastColumn.implicitHeight, 1)
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: 56
    anchors.rightMargin: 12
    z: 200

    Column {
        id: toastColumn
        width: parent.width
        spacing: 8

        Repeater {
            model: root.popupCount

            delegate: Item {
                id: toastRoot
                required property int index

                readonly property var notif: {
                    const list = Notifications.popupList;
                    if (!list || toastRoot.index < 0 || toastRoot.index >= list.length)
                        return null;
                    return list[toastRoot.index];
                }
                readonly property int notifId: notif && notif.id !== undefined ? Number(notif.id) : NaN
                readonly property string appName: notif ? String(notif.appName || "") : ""
                readonly property string summary: notif ? String(notif.summary || "") : ""
                readonly property string body: notif ? String(notif.body || "") : ""
                readonly property bool isCritical: {
                    if (!notif)
                        return false;
                    const u = notif.urgency;
                    return u === 2 || u === "critical" || String(u).toLowerCase() === "critical";
                }

                width: toastColumn.width
                height: Math.max(bodyCol.implicitHeight + 24, 72)
                visible: notif !== null

                // Visual only — must not steal mouse.
                StyledRect {
                    anchors.fill: parent
                    variant: "popup"
                    radius: Styling.radius(8)
                    enableShadow: false
                    enabled: false

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: toastRoot.isCritical ? 2 : 0
                        border.color: Colors.error
                        enabled: false
                    }

                    ColumnLayout {
                        id: bodyCol
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 12
                        }
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: toastRoot.isCritical ? Icons.alert : Icons.bell
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: toastRoot.isCritical ? Colors.error : Styling.srItem("overprimary")
                            }

                            Text {
                                Layout.fillWidth: true
                                text: toastRoot.appName || "Notification"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.DemiBold
                                color: Colors.overBackground
                                elide: Text.ElideRight
                            }

                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: cardMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.cancel
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: cardMa.containsMouse ? Colors.overBackground : Colors.outline
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: toastRoot.summary.length > 0
                            text: toastRoot.summary
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Medium
                            color: Colors.overBackground
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: toastRoot.body.length > 0
                            text: toastRoot.body
                            textFormat: Text.StyledText
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.outline
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                        }
                    }
                }

                // Full-card click target ON TOP of the visual card.
                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    z: 100
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: {
                        console.log("Toast dismiss click id=", toastRoot.notifId, "app=", toastRoot.appName);
                        root.dismissToast(toastRoot.notifId, toastRoot.appName);
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (!toastRoot.appName)
                            return;
                        if (hovered)
                            Notifications.pauseGroupTimers(toastRoot.appName);
                        else
                            Notifications.resumeGroupTimers(toastRoot.appName);
                    }
                }
            }
        }
    }

    function dismissToast(notifId, appName) {
        console.log("NotificationToastStack.dismissToast", notifId, appName, "popupCount=", root.popupCount);
        if (!isNaN(Number(notifId)))
            Notifications.clearPopupById(notifId);
        if (appName)
            Notifications.dismissPopupApp(appName);

        // If that id is still showing, clear everything rather than leave a stuck toast.
        Qt.callLater(() => {
            const list = Notifications.popupList || [];
            for (let i = 0; i < list.length; i++) {
                if (!isNaN(Number(notifId)) && Number(list[i].id) === Number(notifId)) {
                    console.warn("Toast still present after dismiss; clearing all popups");
                    Notifications.dismissAllPopups();
                    return;
                }
            }
        });
    }
}
