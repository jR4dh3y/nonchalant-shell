import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme

// Ambxst-style horizontal ActionGrid. ←/→ or ↑/↓ move, Enter activates.
ActionGrid {
    id: root

    signal itemSelected

    layout: "row"
    buttonSize: 48
    iconSize: 20
    spacing: 8
    focus: true

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
            command: "",
            action: "logout"
        },
        {
            icon: Icons.reboot,
            tooltip: "Reboot",
            command: "systemctl reboot"
        },
        {
            icon: Icons.shutdown,
            tooltip: "Power Off",
            command: "systemctl poweroff",
            variant: "errorcontainer",
            danger: true
        }
    ]

    onActionTriggered: action => {
        if (action.tooltip === "Lock Session")
            LockscreenService.lock();
        if (action.action === "logout")
            CompositorService.logout();
        root.itemSelected();
    }
}
