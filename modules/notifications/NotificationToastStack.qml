pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

// In-panel toast stack. Enter: fade + light drop. Exit: fade + slight up.
// Avoid sliding on +x while the host is right-anchored (that looked like
// toasts "spawning away" off the right edge).
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

    property int exitingCount: 0

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

                property bool closing: false
                property bool entered: false
                property real toastOpacity: 0
                property real slideY: -12

                // Match app launcher / system monitor content inset.
                readonly property int contentPad: Math.max(Styling.radius(3), 12)
                readonly property int chromeSize: 20

                width: toastColumn.width
                height: Math.max(bodyCol.implicitHeight + contentPad * 2, 72)
                visible: notif !== null || closing
                opacity: toastOpacity
                transform: Translate {
                    y: toastRoot.slideY
                }

                Component.onCompleted: playEnter()

                function playEnter() {
                    if (closing || entered)
                        return;
                    if (root.animMs <= 0) {
                        toastOpacity = 1;
                        slideY = 0;
                        entered = true;
                        return;
                    }
                    enterAnim.start();
                }

                function playExit(thenClear) {
                    if (closing)
                        return;
                    closing = true;
                    entered = true;
                    root.exitingCount += 1;
                    cardMa.enabled = false;
                    enterAnim.stop();

                    if (root.animMs <= 0) {
                        finishExit(thenClear);
                        return;
                    }

                    exitAnim.thenClear = thenClear;
                    exitAnim.start();
                }

                ParallelAnimation {
                    id: enterAnim
                    running: false

                    NumberAnimation {
                        target: toastRoot
                        property: "toastOpacity"
                        from: 0
                        to: 1
                        duration: Math.max(root.animMs / 2, 80)
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: toastRoot
                        property: "slideY"
                        from: -12
                        to: 0
                        duration: root.animMs
                        easing.type: Easing.OutCubic
                    }

                    onStarted: {
                        toastRoot.toastOpacity = 0;
                        toastRoot.slideY = -12;
                    }
                    onFinished: toastRoot.entered = true
                }

                ParallelAnimation {
                    id: exitAnim
                    property bool thenClear: true
                    running: false

                    NumberAnimation {
                        target: toastRoot
                        property: "toastOpacity"
                        to: 0
                        duration: Math.max(root.animMs / 2, 80)
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: toastRoot
                        property: "slideY"
                        to: -10
                        duration: root.animMs
                        easing.type: Easing.InCubic
                    }

                    onFinished: toastRoot.finishExit(exitAnim.thenClear)
                }

                function finishExit(thenClear) {
                    if (thenClear)
                        root.commitDismiss(toastRoot.notifId, toastRoot.appName);
                    root.exitingCount = Math.max(0, root.exitingCount - 1);
                }

                Connections {
                    target: Notifications
                    function onTimeoutWithAnimation(id) {
                        if (!isNaN(toastRoot.notifId) && Number(id) === toastRoot.notifId)
                            toastRoot.playExit(false);
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
                        // Content-driven height: inset on all sides via top/left/right
                        // margins + parent height = content + pad*2 (bottom pad free).
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: toastRoot.contentPad
                        }
                        spacing: 6

                        // Header: matching left/right chrome so edge inset stays even.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Item {
                                Layout.preferredWidth: toastRoot.chromeSize
                                Layout.preferredHeight: toastRoot.chromeSize
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    anchors.centerIn: parent
                                    text: toastRoot.isCritical ? Icons.alert : Icons.bell
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: toastRoot.isCritical ? Colors.error : Styling.srItem("overprimary")
                                }
                            }

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: toastRoot.appName || "Notification"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.DemiBold
                                color: Colors.overBackground
                                elide: Text.ElideRight
                            }

                            Item {
                                Layout.preferredWidth: toastRoot.chromeSize
                                Layout.preferredHeight: toastRoot.chromeSize
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: toastRoot.chromeSize + 8
                                    height: toastRoot.chromeSize + 8
                                    radius: width / 2
                                    color: cardMa.containsMouse && !toastRoot.closing ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                }

                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    anchors.centerIn: parent
                                    text: Icons.cancel
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    color: cardMa.containsMouse && !toastRoot.closing ? Colors.overBackground : Colors.outline
                                }
                            }
                        }

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
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
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
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
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton && !isNaN(toastRoot.notifId)) {
                            Notifications.attemptInvokeAction(toastRoot.notifId, "default", false);
                        }
                        toastRoot.playExit(true);
                    }
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
