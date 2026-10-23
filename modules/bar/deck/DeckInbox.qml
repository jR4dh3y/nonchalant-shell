pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services
import qs.modules.theme

ColumnLayout {
    id: root
    spacing: Styling.fontSize(0)
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        DeckAction {
            objectName: "deckInboxDnd"
            glyph: Notifications.silent ? Icons.bellSlash : Icons.bell
            label: "Do not disturb"
            selected: Notifications.silent
            description: Notifications.silent ? "Do not disturb is on" : "Do not disturb is off"
            onClicked: Notifications.toggleSilent()
        }
        DeckAction {
            objectName: "deckInboxClear"
            glyph: Icons.trash
            label: "Clear all"
            description: "Clear all notifications"
            enabled: Notifications.list.length > 0
            onClicked: Notifications.discardAllNotifications()
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
            spacing: Styling.fontSize(0)
            Repeater {
                model: Notifications.list.slice().reverse()
                DeckSection {
                    id: notice
                    required property Notifications.Notif modelData
                    Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Styling.fontSize(0) * 0.3
                            StyledText {
                                Layout.fillWidth: true
                                text: notice.modelData.appName + " · " + Qt.formatDateTime(new Date(notice.modelData.time), "hh:mm")
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overSurfaceVariant
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: notice.modelData.summary
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                                font.weight: Font.Medium
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
                                color: Colors.overSurfaceVariant
                            }
                            Flow {
                                Layout.fillWidth: true
                                Layout.preferredHeight: implicitHeight
                                spacing: Styling.fontSize(0) * 0.3
                                Repeater {
                                    model: notice.modelData.actions
                                    DeckAction {
                                        required property var modelData
                                        objectName: "deckNoticeAction-" + notice.modelData.id + "-" + modelData.identifier
                                        label: modelData.text
                                        onClicked: Notifications.attemptInvokeAction(notice.modelData.id, modelData.identifier)
                                    }
                                }
                            }
                        }
                        DeckAction {
                            objectName: "deckNoticeDismiss-" + notice.modelData.id
                            glyph: Icons.cancel
                            description: "Dismiss " + notice.modelData.summary
                            onClicked: Notifications.discardNotification(notice.modelData.id)
                        }
                    }
                }
            }
            StyledText {
                visible: Notifications.list.length === 0
                text: "You're all caught up. New notifications will appear here."
                color: Colors.overSurfaceVariant
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
