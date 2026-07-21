import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

FocusScope {
    id: root

    signal itemSelected
    property bool expanded: false

    readonly property var actions: [
        { id: "lock", icon: Icons.lock, tooltip: "Lock Session" },
        { id: "suspend", icon: Icons.suspend, tooltip: "Suspend", command: "systemctl suspend" },
        { id: "hibernate", icon: Icons.hibernate, tooltip: "Hibernate", command: "systemctl hibernate" },
        { id: "logout", icon: Icons.logout, tooltip: "Exit Niri", command: "niri msg action quit --skip-confirmation" },
        { id: "reboot", icon: Icons.reboot, tooltip: "Reboot", command: "systemctl reboot" },
        { id: "shutdown", icon: Icons.shutdown, tooltip: "Power Off", command: "systemctl poweroff" }
    ]

    readonly property real buttonSize: Styling.fontSize(0) * 2.6
    readonly property real chainSpacing: Styling.fontSize(0) * 0.35
    implicitWidth: buttonSize
    implicitHeight: actions.length * buttonSize + (actions.length - 1) * chainSpacing
    property int currentIndex: 0

    onExpandedChanged: {
        for (let i = 0; i < actionRepeater.count; i++) {
            const button = actionRepeater.itemAt(i);
            if (button)
                button.entered = false;
        }
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

            delegate: Button {
                id: actionButton

                required property var modelData
                required property int index
                property bool entered: false

                width: root.buttonSize
                height: width
                focusPolicy: Qt.StrongFocus
                opacity: entered ? 1 : 0

                transform: Translate {
                    y: actionButton.entered ? 0 : root.chainSpacing * 2

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutBack }
                    }
                }

                Timer {
                    interval: index * 60
                    running: root.expanded && !actionButton.entered
                    onTriggered: actionButton.entered = true
                }

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
                }
                background: StyledRect {
                    variant: actionButton.activeFocus || actionMouse.containsMouse ? "focus" : "popup"
                    radius: width / 2
                    enableBorder: false
                    enableShadow: false
                }

                contentItem: Text {
                    text: actionButton.modelData.icon
                    color: actionButton.background.item
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(1)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.trigger(actionButton.index)
                }

                Keys.onReturnPressed: root.trigger(actionButton.index)
                Keys.onSpacePressed: root.trigger(actionButton.index)

                StyledToolTip {
                    show: actionMouse.containsMouse
                    tooltipText: actionButton.modelData.tooltip
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            currentIndex = Math.min(currentIndex + 1, actions.length - 1);
            chain.children[currentIndex].forceActiveFocus();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            currentIndex = Math.max(currentIndex - 1, 0);
            chain.children[currentIndex].forceActiveFocus();
            event.accepted = true;
        }
    }
}
