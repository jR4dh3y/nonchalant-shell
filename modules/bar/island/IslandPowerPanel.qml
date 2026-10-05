pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    implicitWidth: 420
    implicitHeight: mainColumn.implicitHeight + 28

    signal backRequested()
    signal actionTriggered()

    // Keyboard selection: -1 = none. IslandBar routes Left/Right/Return here.
    property int selectedIndex: -1

    readonly property var actions: [
        // Empty command = lock via LockscreenService.
        { icon: Icons.suspend, label: "Suspend", command: ["systemctl", "suspend"] },
        { icon: Icons.lock, label: "Lock Session", command: [] },
        { icon: Icons.logout, label: "Log out", command: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
        { icon: Icons.reboot, label: "Reboot", command: ["systemctl", "reboot"] },
        { icon: Icons.shutdown, label: "Power Off", command: ["systemctl", "poweroff"], danger: true }
    ]

    function resetSelection() {
        selectedIndex = -1;
    }

    function moveSelection(delta: int) {
        const count = actions.length;
        selectedIndex = selectedIndex < 0
            ? (delta > 0 ? 0 : count - 1)
            : (((selectedIndex + delta) % count) + count) % count;
    }

    function activateSelected() {
        if (selectedIndex >= 0)
            activate(selectedIndex);
    }

    function activate(index: int) {
        const command = actions[index]?.command ?? [];
        if (command.length > 0)
            Quickshell.execDetached(command);
        else
            LockscreenService.lock();
        root.actionTriggered();
    }

    onVisibleChanged: {
        if (!visible)
            resetSelection();
    }

    ColumnLayout {
        id: mainColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: backMouse.containsMouse ? "focus" : "common"
                scale: backMouse.pressed ? 0.92 : 1.0

                PressBehavior on scale {
                    pressed: backMouse.pressed
                }

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowLeft
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: Colors.overBackground
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Power"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
            }

            Item { Layout.fillWidth: true }
        }

        // Action buttons (icon-only, arrow-key navigable). One track with a
        // highlight that morphs between items, like the bar's power menu.
        StyledRect {
            id: actionTrack
            Layout.fillWidth: true
            Layout.preferredHeight: 52 + padding * 2
            readonly property int padding: 4
            radius: Styling.radius(2) + padding
            variant: "internalbg"

            ElasticHighlight {
                id: highlight
                radius: Styling.radius(2)
                targetItem: root.selectedIndex >= 0 ? actionRepeater.itemAt(root.selectedIndex) : null
                originX: actionRow.x
                originY: actionRow.y
            }

            RowLayout {
                id: actionRow
                anchors.fill: parent
                anchors.margins: actionTrack.padding
                spacing: 4

                Repeater {
                    id: actionRepeater
                    model: root.actions

                    delegate: Item {
                        id: actionItem

                        required property var modelData
                        required property int index

                        readonly property bool selected: root.selectedIndex === index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        scale: actionMouse.pressed ? 0.90 : 1.0

                        PressBehavior on scale {
                            pressed: actionMouse.pressed
                        }

                        Text {
                            anchors.centerIn: parent
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: actionItem.modelData.icon
                            font.family: Icons.font
                            font.pixelSize: 20
                            color: actionItem.selected ? highlight.item : (actionItem.modelData.danger ? Colors.red : Colors.overBackground)

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutQuart
                                }
                            }
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: {
                                if (containsMouse)
                                    root.selectedIndex = actionItem.index;
                            }
                            onClicked: root.activate(actionItem.index)
                        }

                        StyledToolTip {
                            visible: actionMouse.containsMouse
                            tooltipText: actionItem.modelData.label
                            delay: 500
                        }
                    }
                }
            }
        }
    }
}
