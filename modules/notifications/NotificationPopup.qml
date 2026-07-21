pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

// Toast host: top-right overlay. Driven by popupAppNameList (string model)
// which is reliably reassigned in Notifications.rebuildGroups().
Scope {
    id: notificationPopup

    readonly property bool hasPopups: Notifications.popupAppNameList.length > 0

    PanelWindow {
        id: root

        visible: notificationPopup.hasPopups
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

        WlrLayershell.namespace: "nonchalant:notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        anchors {
            top: true
            right: true
        }

        WlrLayershell.margins.top: 52
        WlrLayershell.margins.right: 12

        color: "transparent"
        implicitWidth: 380
        implicitHeight: Math.max(toastColumn.implicitHeight + 8, 1)

        // Input only on the toast cards, rest of screen is pass-through.
        mask: Region {
            item: toastColumn
        }

        Column {
            id: toastColumn
            width: parent.width
            spacing: 8

            Repeater {
                id: toastRepeater
                model: Notifications.popupAppNameList

                delegate: Item {
                    id: toastRoot
                    required property int index
                    required property var modelData

                    // modelData is the app name string
                    readonly property string appName: String(modelData || "")
                    readonly property var group: Notifications.popupGroupsByAppName[appName] || null
                    readonly property var latest: {
                        const list = group && group.notifications ? group.notifications : [];
                        if (!list.length)
                            return null;
                        let best = list[0];
                        for (let i = 1; i < list.length; i++) {
                            if ((list[i].time || 0) > (best.time || 0))
                                best = list[i];
                        }
                        return best;
                    }
                    readonly property bool isCritical: {
                        const u = latest?.urgency;
                        return u === 2 || u === "critical" || String(u).toLowerCase() === "critical";
                    }

                    width: toastColumn.width
                    height: card.implicitHeight
                    visible: latest !== null

                    StyledRect {
                        id: card
                        anchors.fill: parent
                        implicitHeight: bodyCol.implicitHeight + 24
                        variant: "popup"
                        radius: Styling.radius(8)
                        enableShadow: true

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

                                Text {
                                    text: Icons.cancel
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    color: Colors.outline

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const list = toastRoot.group?.notifications || [];
                                            list.forEach(n => {
                                                if (n && n.id !== undefined)
                                                    Notifications.timeoutNotification(n.id);
                                            });
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: !!(toastRoot.latest?.summary)
                                text: toastRoot.latest?.summary || ""
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Medium
                                color: Colors.overBackground
                                wrapMode: Text.Wrap
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: !!(toastRoot.latest?.body)
                                text: toastRoot.latest?.body || ""
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

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.MiddleButton
                        onClicked: {
                            const list = toastRoot.group?.notifications || [];
                            const ids = list.map(n => n.id).filter(id => id !== undefined);
                            if (ids.length)
                                Notifications.discardNotifications(ids);
                        }
                    }
                }
            }
        }
    }
}
