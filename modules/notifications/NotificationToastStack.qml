pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

// In-panel toast stack with enter/exit motion matching shell timing.
Item {
    id: root

    readonly property int popupCount: Notifications.popupList ? Notifications.popupList.length : 0
    readonly property bool hasPopups: popupCount > 0
    readonly property Item hitbox: hasPopups ? toastColumn : null
    readonly property int animMs: Config.animDuration > 0 ? Config.animDuration : 0

    visible: hasPopups || exitingCount > 0
    width: 360
    height: Math.max(toastColumn.implicitHeight, 1)
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: 56
    anchors.rightMargin: 12
    z: 200

    // Track exit animations so the host stays up until they finish.
    property int exitingCount: 0

    Column {
        id: toastColumn
        width: parent.width
        spacing: 8

        // Smooth reflow when a toast leaves the stack.
        move: Transition {
            enabled: root.animMs > 0
            NumberAnimation {
                properties: "y"
                duration: root.animMs / 2
                easing.type: Easing.OutCubic
            }
        }

        add: Transition {
            enabled: root.animMs > 0
            NumberAnimation {
                properties: "opacity"
                from: 0
                to: 1
                duration: 1
            }
        }

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

                property bool closing: false
                property real slideX: 48
                property real toastOpacity: 0
                property real toastScale: 0.92

                width: toastColumn.width
                height: Math.max(bodyCol.implicitHeight + 24, 72)
                visible: notif !== null || closing
                opacity: toastOpacity
                scale: toastScale
                transformOrigin: Item.Right
                x: slideX
                clip: false

                Behavior on toastOpacity {
                    enabled: root.animMs > 0 && !closing
                    NumberAnimation {
                        duration: root.animMs / 2
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on slideX {
                    enabled: root.animMs > 0 && !closing
                    NumberAnimation {
                        duration: root.animMs
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on toastScale {
                    enabled: root.animMs > 0 && !closing
                    NumberAnimation {
                        duration: root.animMs
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }

                // Enter
                Component.onCompleted: {
                    if (root.animMs <= 0) {
                        toastOpacity = 1;
                        slideX = 0;
                        toastScale = 1;
                        return;
                    }
                    // Next frame so Behaviors attach before values change.
                    Qt.callLater(() => {
                        if (closing)
                            return;
                        toastOpacity = 1;
                        slideX = 0;
                        toastScale = 1;
                    });
                }

                function playExit(thenClear) {
                    if (closing)
                        return;
                    closing = true;
                    root.exitingCount += 1;
                    cardMa.enabled = false;

                    // Disable enter Behaviors path; drive exit with explicit anim.
                    if (root.animMs <= 0) {
                        finishExit(thenClear);
                        return;
                    }

                    exitAnim.notifId = toastRoot.notifId
                    exitAnim.appName = toastRoot.appName
                    exitAnim.thenClear = thenClear
                    exitAnim.start()
                }

                ParallelAnimation {
                    id: exitAnim
                    property real notifId: NaN
                    property string appName: ""
                    property bool thenClear: true

                    NumberAnimation {
                        target: toastRoot
                        property: "toastOpacity"
                        to: 0
                        duration: root.animMs / 2
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: toastRoot
                        property: "slideX"
                        to: 56
                        duration: root.animMs
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: toastRoot
                        property: "toastScale"
                        to: 0.94
                        duration: root.animMs / 2
                        easing.type: Easing.InQuad
                    }

                    onFinished: toastRoot.finishExit(exitAnim.thenClear)
                }

                function finishExit(thenClear) {
                    if (thenClear)
                        root.commitDismiss(toastRoot.notifId, toastRoot.appName);
                    root.exitingCount = Math.max(0, root.exitingCount - 1);
                }

                // Auto-expire from the service: animate out before the list drops us.
                Connections {
                    target: Notifications
                    function onTimeoutWithAnimation(id) {
                        if (!isNaN(toastRoot.notifId) && Number(id) === toastRoot.notifId)
                            toastRoot.playExit(false); // service clears after its own delay
                    }
                }

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
                                    color: cardMa.containsMouse && !toastRoot.closing ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                    Behavior on color {
                                        enabled: root.animMs > 0
                                        ColorAnimation { duration: root.animMs / 3 }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.cancel
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: cardMa.containsMouse && !toastRoot.closing ? Colors.overBackground : Colors.outline
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

                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    z: 100
                    hoverEnabled: true
                    enabled: !toastRoot.closing
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: toastRoot.playExit(true)
                }

                HoverHandler {
                    enabled: !toastRoot.closing
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

    function commitDismiss(notifId, appName) {
        if (!isNaN(Number(notifId)))
            Notifications.clearPopupById(notifId);
        if (appName)
            Notifications.dismissPopupApp(appName);
    }
}
