pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.components
import qs.modules.services
import qs.modules.theme

// Inbox: a fixed header card above a scrolling stack of notification cards.
ColumnLayout {
    id: root
    spacing: Styling.fontSize(0) * 0.5

    function ago(time: real): string {
        const minutes = Math.max(0, Math.floor((clock.date.getTime() - time) / 60000));
        return minutes < 1 ? "now" : minutes < 60 ? minutes + "m" : minutes < 1440 ? Math.floor(minutes / 60) + "h" : Math.floor(minutes / 1440) + "d";
    }
    function iconSource(notice: Notifications.Notif): string {
        const icon = notice.image || notice.appIcon;
        if (icon === "") return "";
        return icon.startsWith("/") ? "file://" + icon : icon.includes("://") ? icon : Quickshell.iconPath(icon, true);
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    DeckCard {
        objectName: "deckInboxHeader"
        Layout.fillWidth: true
        order: 0
        padding: Styling.fontSize(0) * 0.4
        RowLayout {
            Layout.fillWidth: true
            spacing: Styling.fontSize(0) * 0.3
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Styling.fontSize(0) * 0.4
                text: "Notifications"
                font.weight: Font.DemiBold
            }
            DeckAction {
                objectName: "deckInboxDnd"
                glyph: Notifications.silent ? Icons.bellSlash : Icons.bell
                label: "Do not disturb"
                accent: true
                selected: Notifications.silent
                description: Notifications.silent ? "Do not disturb is on" : "Do not disturb is off"
                onClicked: Notifications.toggleSilent()
            }
            DeckAction {
                objectName: "deckInboxClear"
                kind: DeckAction.Icon
                glyph: Icons.trash
                description: "Clear all notifications"
                enabled: Notifications.list.length > 0
                onClicked: Notifications.discardAllNotifications()
            }
        }
    }
    ScrollView {
        id: list
        objectName: "deckInboxList"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
            width: list.availableWidth
            spacing: Styling.fontSize(0) * 0.5
            Repeater {
                model: Notifications.list.slice().reverse()
                DeckCard {
                    id: notice
                    required property Notifications.Notif modelData
                    required property int index
                    Layout.fillWidth: true
                    order: index + 1
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Styling.fontSize(0) * 0.6
                        StyledRect {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: Styling.fontSize(0) * 2.8
                            Layout.preferredHeight: Layout.preferredWidth
                            variant: "internalbg"
                            radius: width / 2
                            enableBorder: false
                            Image {
                                id: noticeIcon
                                anchors.fill: parent
                                anchors.margins: parent.width * 0.2
                                source: root.iconSource(notice.modelData)
                                sourceSize.width: width * 2
                                sourceSize.height: height * 2
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            StyledText {
                                anchors.centerIn: parent
                                visible: !noticeIcon.visible
                                text: notice.modelData.urgency === "critical" ? Icons.bellRinging : Icons.bell
                                font.family: Icons.font
                                font.pixelSize: Styling.fontSize(2)
                                color: Colors.primary
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Styling.fontSize(0) * 0.15
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Styling.fontSize(0) * 0.3
                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: implicitWidth
                                    text: notice.modelData.summary
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Colors.primary
                                    font.weight: Font.DemiBold
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: notice.modelData.appName !== ""
                                    text: "· " + notice.modelData.appName
                                    elide: Text.ElideRight
                                    color: Colors.overSurfaceVariant
                                    font.pixelSize: Styling.fontSize(-3)
                                }
                                StyledText {
                                    text: root.ago(notice.modelData.time)
                                    color: Colors.overSurfaceVariant
                                    font.pixelSize: Styling.fontSize(-3)
                                }
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: notice.modelData.body
                                visible: text !== ""
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                font.pixelSize: Styling.fontSize(-1)
                            }
                        }
                        DeckAction {
                            objectName: "deckNoticeDismiss-" + notice.modelData.id
                            Layout.alignment: Qt.AlignTop
                            kind: DeckAction.Icon
                            controlHeight: Styling.fontSize(0) * 1.8
                            glyph: Icons.cancel
                            description: "Dismiss " + notice.modelData.summary
                            onClicked: Notifications.discardNotification(notice.modelData.id)
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: notice.modelData.actions.length > 0
                        spacing: Styling.fontSize(0) * 0.4
                        Repeater {
                            model: notice.modelData.actions
                            DeckAction {
                                required property var modelData
                                objectName: "deckNoticeAction-" + notice.modelData.id + "-" + modelData.identifier
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                kind: DeckAction.Action
                                label: modelData.text
                                maximumLabelWidth: width
                                onClicked: Notifications.attemptInvokeAction(notice.modelData.id, modelData.identifier)
                            }
                        }
                    }
                }
            }
            DeckCard {
                Layout.fillWidth: true
                visible: Notifications.list.length === 0
                order: 1
                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: Styling.fontSize(0)
                    Layout.bottomMargin: Styling.fontSize(0)
                    text: Notifications.silent ? "All caught up. Do not disturb is on." : "All caught up."
                    horizontalAlignment: Text.AlignHCenter
                    color: Colors.overSurfaceVariant
                }
            }
        }
    }
}
