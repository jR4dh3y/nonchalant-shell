import QtQuick
import Quickshell
import qs.modules.services

// History / popup list of app groups. Popup toasts use NotificationPopup's
// own Repeater over popupList; this view still powers any external consumers.
ListView {
    id: root
    property bool popup: false

    spacing: 8
    clip: true

    model: root.popup ? Notifications.popupAppNameList : Notifications.appNameList

    delegate: NotificationGroup {
        required property int index
        required property var modelData

        width: root.width
        popup: root.popup
        expanded: root.popup
        notificationGroup: root.popup
            ? Notifications.popupGroupsByAppName[modelData]
            : Notifications.groupsByAppName[modelData]
    }
}
