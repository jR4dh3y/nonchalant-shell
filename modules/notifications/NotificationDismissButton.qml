import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.components
import qs.config

Button {
    id: root
    property bool visibleWhen: true
    property int urgency: NotificationUrgency.Normal

    anchors.fill: parent
    hoverEnabled: true
    visible: visibleWhen

    background: StyledRect {
        id: buttonBg
        readonly property color iconColor: root.urgency === NotificationUrgency.Critical
            ? Colors.shadow
            : (root.pressed ? Colors.overError : Colors.error)

        variant: root.urgency === NotificationUrgency.Critical
            ? "error"
            : (root.pressed ? "error" : (root.hovered ? "focus" : "common"))
        radius: Styling.radius(4)
    }

    contentItem: Text {
        text: Icons.cancel
        textFormat: Text.RichText
        font.family: Icons.font
        font.pixelSize: 16
        color: root.background.iconColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
