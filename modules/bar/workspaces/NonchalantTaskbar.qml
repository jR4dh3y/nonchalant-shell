pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    required property var bar

    readonly property var visibleWorkspaces: NiriService.workspaces.values
        .filter(workspace => {
            if (workspace.output !== root.bar.screen.name)
                return false;
            return workspace.isNamed || workspace.active || root.windowsForWorkspace(workspace.id).length > 0;
        })
        .sort((left, right) => left.idx - right.idx)
    readonly property int activeWorkspaceIndex: visibleWorkspaces.findIndex(workspace => workspace.active)
    readonly property Item activeWorkspaceButton: {
        const count = workspaceRepeater.count;
        return activeWorkspaceIndex >= 0 && activeWorkspaceIndex < count
            ? workspaceRepeater.itemAt(activeWorkspaceIndex)
            : null;
    }

    function windowsForWorkspace(workspaceId) {
        return NiriService.clients.values.filter(window => window.workspace.id === workspaceId);
    }

    function iconForWindow(window) {
        const entry = DesktopEntries.heuristicLookup(window.appId);
        return entry?.icon || AppSearch.guessIcon(window.appId) || "image-missing";
    }

    implicitWidth: workspaceRow.implicitWidth + 8
    implicitHeight: 36

    StyledRect {
        anchors.fill: parent
        variant: "bg"
        radius: Styling.radius(7)
        enableShadow: false
    }

    StyledRect {
        id: activeIndicator
        variant: "focus"
        z: 1
        x: root.activeWorkspaceButton ? workspaceRow.x + root.activeWorkspaceButton.x : workspaceRow.x
        y: workspaceRow.y
        width: root.activeWorkspaceButton ? root.activeWorkspaceButton.width : 0
        height: workspaceRow.height
        radius: Styling.radius(5)
        opacity: root.activeWorkspaceButton ? 1 : 0
        enableShadow: false

        Behavior on x {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuad
            }
        }
    }

    RowLayout {
        id: workspaceRow
        z: 2
        anchors.fill: parent
        anchors.margins: 4
        spacing: 2

        Repeater {
            id: workspaceRepeater
            model: root.visibleWorkspaces

            Item {
                id: workspaceButton

                required property var modelData
                readonly property var workspace: modelData
                readonly property bool active: workspace.active
                readonly property var windows: root.windowsForWorkspace(workspace.id)
                readonly property bool occupied: windows.length > 0
                readonly property string displayName: workspace.isNamed ? workspace.name : String(workspace.idx)
                readonly property bool showLabel: !active || !occupied

                Layout.preferredWidth: showLabel ? workspaceName.implicitWidth + 16 : Math.max(32, appsRow.implicitWidth + 10)
                Layout.preferredHeight: 28

                Behavior on Layout.preferredWidth {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                StyledRect {
                    anchors.fill: parent
                    variant: "transparent"
                    radius: Styling.radius(5)
                    enableShadow: false

                    Rectangle {
                        anchors.fill: parent
                        color: Styling.srItem("overprimary")
                        opacity: workspaceMouse.containsMouse && !workspaceButton.active ? 0.12 : 0
                        radius: Styling.radius(5)
                    }
                }

                Text {
                    id: workspaceName
                    z: 1
                    anchors.centerIn: parent
                    visible: opacity > 0
                    opacity: workspaceButton.showLabel ? 1 : 0
                    scale: workspaceButton.showLabel ? 1 : 0.85
                    text: workspaceButton.displayName
                    color: workspaceButton.workspace.is_urgent
                        ? Colors.red
                        : (workspaceButton.active
                            ? activeIndicator.item
                            : (workspaceButton.occupied ? Styling.srItem("overprimary") : Colors.overBackground))
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: workspaceButton.occupied ? Font.DemiBold : Font.Medium

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuad
                        }
                    }

                    Behavior on scale {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.1
                        }
                    }
                }

                Row {
                    id: appsRow
                    z: 2
                    anchors.centerIn: parent
                    visible: opacity > 0
                    opacity: workspaceButton.active && workspaceButton.occupied ? 1 : 0
                    scale: workspaceButton.active && workspaceButton.occupied ? 1 : 0.85
                    spacing: 3

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuad
                        }
                    }

                    Behavior on scale {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.1
                        }
                    }

                    Repeater {
                        model: workspaceButton.windows

                        Item {
                            id: appButton

                            required property var modelData
                            readonly property var windowData: modelData
                            readonly property string iconName: root.iconForWindow(windowData)

                            width: 24
                            height: 24

                            Rectangle {
                                anchors.fill: parent
                                radius: Styling.radius(4)
                                color: appButton.windowData.is_focused ? Colors.primary : Styling.srItem("overprimary")
                                opacity: appButton.windowData.is_focused ? 1 : (appMouse.containsMouse ? 0.18 : 0)
                                border.width: appButton.windowData.is_focused ? 1 : 0
                                border.color: Colors.primaryFixed

                                Behavior on opacity {
                                    NumberAnimation { duration: Math.min(Config.animDuration, 150) }
                                }
                            }

                            IconImage {
                                id: appIcon
                                anchors.centerIn: parent
                                width: appButton.windowData.is_focused ? 19 : 16
                                height: width
                                opacity: appButton.windowData.is_focused ? 1 : 0.62
                                source: "image://icon/" + appButton.iconName
                                asynchronous: true

                                onStatusChanged: {
                                    if (status === Image.Error && appButton.iconName !== "image-missing")
                                        source = "image://icon/image-missing";
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1
                                width: 10
                                height: 2
                                radius: 1
                                color: Colors.primaryFixed
                                visible: appButton.windowData.is_focused
                            }

                            MouseArea {
                                id: appMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    NiriService.focusWindow(appButton.windowData.id);
                                }
                            }

                            StyledToolTip {
                                show: appMouse.containsMouse
                                tooltipText: appButton.windowData.title || appButton.windowData.appId
                            }
                        }
                    }
                }

                MouseArea {
                    id: workspaceMouse
                    anchors.fill: parent
                    z: 1
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NiriService.focusWorkspace(workspaceButton.workspace.id)
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y < 0)
                NiriService.runNiriAction(["focus-workspace-down"]);
            else if (event.angleDelta.y > 0)
                NiriService.runNiriAction(["focus-workspace-up"]);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }
}
