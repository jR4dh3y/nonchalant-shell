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

    readonly property var namedWorkspaces: NiriService.workspaces.values
        .filter(workspace => workspace.output === root.bar.screen.name && workspace.isNamed)
        .sort((left, right) => left.idx - right.idx)

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

    RowLayout {
        id: workspaceRow
        anchors.fill: parent
        anchors.margins: 4
        spacing: 2

        Repeater {
            model: root.namedWorkspaces

            Item {
                id: workspaceButton

                required property var modelData
                readonly property var workspace: modelData
                readonly property bool active: workspace.active
                readonly property var windows: root.windowsForWorkspace(workspace.id)
                readonly property bool occupied: windows.length > 0

                Layout.preferredWidth: active ? Math.max(32, appsRow.implicitWidth + 10) : workspaceName.implicitWidth + 16
                Layout.preferredHeight: 28

                StyledRect {
                    anchors.fill: parent
                    variant: workspaceButton.active ? "primary" : "bg"
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
                    visible: !workspaceButton.active
                    text: workspaceButton.workspace.name
                    color: workspaceButton.workspace.is_urgent
                        ? Colors.red
                        : (workspaceButton.occupied ? Styling.srItem("overprimary") : Colors.overBackground)
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: workspaceButton.occupied ? Font.DemiBold : Font.Medium
                }

                Row {
                    id: appsRow
                    z: 2
                    anchors.centerIn: parent
                    visible: workspaceButton.active
                    spacing: 3

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
                                color: Styling.srItem("overprimary")
                                opacity: appButton.windowData.is_focused ? 0.38 : (appMouse.containsMouse ? 0.16 : 0)

                                Behavior on opacity {
                                    NumberAnimation { duration: Math.min(Config.animDuration, 150) }
                                }
                            }

                            IconImage {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 17
                                height: 17
                                source: "image://icon/" + appButton.iconName
                                asynchronous: true

                                onStatusChanged: {
                                    if (status === Image.Error && appButton.iconName !== "image-missing")
                                        source = "image://icon/image-missing";
                                }
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
