pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

// In-panel toast stack (not a separate layer-shell window).
// Lives inside UnifiedShellPanel so clicks are not stolen by the full-screen
// bar surface's input region.
Item {
    id: root

    readonly property bool hasPopups: Notifications.popupAppNameList.length > 0
    // Expose for the panel mask so the bar surface accepts clicks on toasts.
    readonly property Item hitbox: hasPopups ? toastColumn : null

    visible: hasPopups
    width: 360
    height: toastColumn.implicitHeight
    // Sit under the bar pills; panel is full-screen so use absolute coords.
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
            model: Notifications.popupAppNameList

            delegate: Item {
                id: toastRoot
                required property int index
                required property var modelData

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
                height: Math.max(bodyCol.implicitHeight + 24, 72)
                visible: latest !== null

                StyledRect {
                    anchors.fill: parent
                    variant: "popup"
                    radius: Styling.radius(8)
                    enableShadow: false

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
                                    color: dismissMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.cancel
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: dismissMa.containsMouse ? Colors.overBackground : Colors.outline
                                }

                                MouseArea {
                                    id: dismissMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    // Prefer press so it wins over HoverHandlers/Flickables.
                                    onPressed: mouse => {
                                        mouse.accepted = true;
                                        Notifications.dismissPopupApp(toastRoot.appName);
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
            }
        }
    }
}
