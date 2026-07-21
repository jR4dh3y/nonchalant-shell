import QtQuick
import qs.modules.components
import qs.modules.theme

ActionGrid {
    id: root

    signal itemSelected

    layout: "grid"
    columns: 2
    buttonSize: 36
    iconSize: 18
    spacing: 4

    Component.onCompleted: {
        root.forceActiveFocus();
    }

    actions: [
        {
            icon: Icons.lock,
            tooltip: "Lock Session",
            command: "loginctl lock-session"
        },
        {
            icon: Icons.suspend,
            tooltip: "Suspend",
            command: "systemctl suspend"
        },
        {
            icon: Icons.hibernate,
            tooltip: "Hibernate",
            command: "systemctl hibernate"
        },
        {
            icon: Icons.logout,
            tooltip: "Exit Niri",
            command: "niri msg action quit --skip-confirmation"
        },
        {
            icon: Icons.reboot,
            tooltip: "Reboot",
            command: "systemctl reboot"
        },
        {
            icon: Icons.shutdown,
            tooltip: "Power Off",
            command: "systemctl poweroff"
        }
    ]

    onActionTriggered: root.itemSelected()
}
