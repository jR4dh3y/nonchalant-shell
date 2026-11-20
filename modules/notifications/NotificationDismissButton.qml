import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.components
import qs.config

Button {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)
    property bool visibleWhen: true
    property int urgency: NotificationUrgency.Normal

    anchors.fill: parent
    hoverEnabled: true
    visible: visibleWhen
    scale: root.pressed ? 0.92 : 1.0

    PressBehavior on scale {
        pressed: root.pressed
    }

    background: StyledRect {
        id: buttonBg
        // Quiet at rest, danger on hover, a paired error container on press;
        // critical cards keep the error fill with its own ink.
        readonly property color iconColor: root.urgency === NotificationUrgency.Critical || root.pressed ? buttonBg.item
            : (root.hovered ? root.shellPalette.danger : root.shellPalette.overSurfaceVariant)

        variant: root.urgency === NotificationUrgency.Critical
            ? "error"
            : (root.pressed ? "errorcontainer" : (root.hovered ? "focus" : "common"))
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
