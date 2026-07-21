import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme

// Ambxst-style horizontal ActionGrid power menu.
ActionGrid {
    id: root

    signal itemSelected

    layout: "row"
    buttonSize: 48
    iconSize: 20
    spacing: 8

    Component.onCompleted: {
        root.forceActiveFocus();
    }

    actions: [
        {
            icon: Icons.lock,
            tooltip: "Lock Session",
            command: ""
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
            tooltip: "Log out",
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

    onActionTriggered: action => {
        // Lock is handled by the shell, not a shell-out.
        if (action.tooltip === "Lock Session")
            LockscreenService.lock();
        root.itemSelected();
    }
}
