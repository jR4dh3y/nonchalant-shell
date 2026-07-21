pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

// Compact top-right toast host.
// No full-screen stretch, no MultiEffect shadow (that was the huge blur strip),
// and no covering MouseArea that ate click events on dismiss buttons.
Scope {
    id: notificationPopup

    readonly property bool hasPopups: Notifications.popupAppNameList.length > 0
    readonly property int toastWidth: 360
    readonly property int maxStackHeight: {
        const h = Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 900;
        return Math.max(200, h - 80);
    }

    PanelWindow {
        id: root

        visible: notificationPopup.hasPopups
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

        WlrLayershell.namespace: "nonchalant:notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        // Anchor only top-right so the surface is the toast stack size, not a
        // full-height strip down the side of the screen.
        anchors {
            top: true
            right: true
        }

        WlrLayershell.margins.top: 52
        WlrLayershell.margins.right: 12

        color: "transparent"
        implicitWidth: notificationPopup.toastWidth
        implicitHeight: Math.min(toastFlick.contentHeight, notificationPopup.maxStackHeight)

        // Clickable region = the stack only (not a phantom full-height column).
        mask: Region {
            item: toastFlick
        }

        Flickable {
            id: toastFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: toastColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: toastColumn
                width: toastFlick.width
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
                        // Prefer content height; fall back so an empty/broken
                        // group never collapses the whole stack to 0 forever.
                        height: Math.max(bodyCol.implicitHeight + 24, 72)
                        visible: latest !== null

                        // Plain StyledRect — no layer shadow. MultiEffect shadow
                        // was painting a giant blurred band on the right edge.
                        StyledRect {
                            id: card
                            anchors.fill: parent
                            variant: "popup"
                            radius: Styling.radius(8)
                            enableShadow: false

                            // Critical outline without custom border props on ClippingRectangle
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: toastRoot.isCritical ? 2 : 0
                                border.color: Colors.error
                                z: 2
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

                                    // Explicit hit target for dismiss (not covered by another MouseArea)
                                    Item {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28

                                        Text {
                                            anchors.centerIn: parent
                                            text: Icons.cancel
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: dismissMa.containsMouse ? Colors.overBackground : Colors.outline
                                        }

                                        MouseArea {
                                            id: dismissMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            z: 10
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
                    }
                }
            }
        }
    }

}
