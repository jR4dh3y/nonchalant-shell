pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

// Compact power action chain — circular buttons that cascade in under the bar.
FocusScope {
    id: root

    signal itemSelected
    property bool expanded: false

    readonly property var actions: [
        { id: "lock", icon: Icons.lock, tooltip: "Lock", destructive: false },
        { id: "suspend", icon: Icons.suspend, tooltip: "Suspend", command: "systemctl suspend", destructive: false },
        { id: "hibernate", icon: Icons.hibernate, tooltip: "Hibernate", command: "systemctl hibernate", destructive: false },
        { id: "logout", icon: Icons.logout, tooltip: "Log out", command: "niri msg action quit --skip-confirmation", destructive: false },
        { id: "reboot", icon: Icons.reboot, tooltip: "Reboot", command: "systemctl reboot", destructive: true },
        { id: "shutdown", icon: Icons.shutdown, tooltip: "Power off", command: "systemctl poweroff", destructive: true }
    ]

    // Match bar pill size for visual consistency.
    readonly property real buttonSize: 36
    readonly property real chainSpacing: 6
    readonly property int animMs: Config.animDuration > 0 ? Config.animDuration : 0

    implicitWidth: buttonSize
    implicitHeight: actions.length * buttonSize + (actions.length - 1) * chainSpacing
    property int currentIndex: 0

    onExpandedChanged: {
        currentIndex = 0;
        for (let i = 0; i < actionRepeater.count; i++) {
            const button = actionRepeater.itemAt(i);
            if (!button)
                continue;
            if (root.expanded) {
                button.entered = false;
                button.enterTimer.restart();
            } else {
                button.enterTimer.stop();
                button.entered = false;
            }
        }
        if (root.expanded)
            Qt.callLater(() => {
                const first = actionRepeater.itemAt(0);
                if (first)
                    first.forceActiveFocus();
            });
    }

    function trigger(index) {
        const action = actions[index];
        if (!action)
            return;
        if (action.id === "lock") {
            LockscreenService.lock();
        } else if (action.command) {
            commandRunner.command = ["bash", "-c", action.command];
            commandRunner.running = true;
        }
        root.itemSelected();
    }

    function focusIndex(index) {
        currentIndex = Math.max(0, Math.min(index, actions.length - 1));
        const button = actionRepeater.itemAt(currentIndex);
        if (button)
            button.forceActiveFocus();
    }

    Process {
        id: commandRunner
        running: false
    }

    Column {
        id: chain
        anchors.centerIn: parent
        spacing: root.chainSpacing

        Repeater {
            id: actionRepeater
            model: root.actions

            delegate: Item {
                id: actionWrap

                required property var modelData
                required property int index

                property bool entered: false
                property alias enterTimer: enterDelay

                width: root.buttonSize
                height: root.buttonSize

                // Cascade-in: fade + rise + scale.
                opacity: entered ? 1 : 0
                scale: entered ? (actionMouse.pressed ? 0.92 : (actionMouse.containsMouse || actionButton.activeFocus ? 1.08 : 1)) : 0.75
                transform: Translate {
                    y: actionWrap.entered ? 0 : 10
                    Behavior on y {
                        enabled: root.animMs > 0
                        NumberAnimation {
                            duration: Math.max(root.animMs / 2, 100)
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.15
                        }
                    }
                }

                Behavior on opacity {
                    enabled: root.animMs > 0
                    NumberAnimation {
                        duration: Math.max(root.animMs / 2, 100)
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    enabled: root.animMs > 0
                    NumberAnimation {
                        duration: Math.max(root.animMs / 3, 80)
                        easing.type: Easing.OutCubic
                    }
                }

                Timer {
                    id: enterDelay
                    interval: actionWrap.index * 45
                    repeat: false
                    onTriggered: actionWrap.entered = true
                }

                Button {
                    id: actionButton
                    anchors.fill: parent
                    focusPolicy: Qt.StrongFocus
                    // Visual handled by our StyledRect; keep Control chrome empty.
                    background: Item {}
                    contentItem: Item {}
                    onClicked: root.trigger(actionWrap.index)
                    Keys.onReturnPressed: root.trigger(actionWrap.index)
                    Keys.onSpacePressed: root.trigger(actionWrap.index)
                }

                StyledRect {
                    id: circle
                    anchors.fill: parent
                    variant: {
                        if (actionWrap.modelData.destructive && (actionMouse.containsMouse || actionButton.activeFocus))
                            return "error";
                        if (actionMouse.containsMouse || actionButton.activeFocus)
                            return "focus";
                        return "popup";
                    }
                    radius: width / 2
                    enableBorder: false
                    enableShadow: false

                    // Soft focus ring
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 4
                        height: parent.height + 4
                        radius: width / 2
                        color: "transparent"
                        border.width: actionButton.activeFocus ? 2 : 0
                        border.color: actionWrap.modelData.destructive ? Colors.error : Styling.srItem("overprimary")
                        opacity: actionButton.activeFocus ? 0.85 : 0
                        z: -1
                        Behavior on opacity {
                            enabled: root.animMs > 0
                            NumberAnimation { duration: root.animMs / 3 }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: actionWrap.modelData.icon
                        color: circle.item
                        font.family: Icons.font
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Keep Button focus/keys; MouseArea handles hover + click.
                    onClicked: {
                        actionButton.forceActiveFocus();
                        root.trigger(actionWrap.index);
                    }
                    onEntered: root.currentIndex = actionWrap.index
                }

                StyledToolTip {
                    show: actionMouse.containsMouse && actionWrap.entered
                    tooltipText: actionWrap.modelData.tooltip
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            root.focusIndex(root.currentIndex + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.focusIndex(root.currentIndex - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            root.focusIndex(0);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.focusIndex(root.actions.length - 1);
            event.accepted = true;
        }
    }
}
