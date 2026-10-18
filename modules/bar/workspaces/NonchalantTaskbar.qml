pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.compositor
import qs.modules.theme

Item {
    id: root

    required property Item bar
    // The island embeds the switcher on its own surface, so it hides this.
    property bool showBackground: true

    readonly property list<CompositorWorkspace> visibleWorkspaces: CompositorService.workspacesForOutput(root.bar.screen.name)
    // Keep delegates alive when only workspace/window state changes.
    readonly property string workspaceOrder: JSON.stringify(visibleWorkspaces.map(workspace => workspace.id))
    property list<string> workspaceIds: []
    onWorkspaceOrderChanged: workspaceIds = visibleWorkspaces.map(workspace => workspace.id)
    Component.onCompleted: workspaceIds = visibleWorkspaces.map(workspace => workspace.id)

    readonly property int activeWorkspaceIndex: visibleWorkspaces.findIndex(workspace => workspace.active)
    readonly property Item activeWorkspaceButton: {
        const count = workspaceRepeater.count;
        return activeWorkspaceIndex >= 0 && activeWorkspaceIndex < count
            ? workspaceRepeater.itemAt(activeWorkspaceIndex)
            : null;
    }

    implicitWidth: workspaceRow.implicitWidth + 8
    implicitHeight: 36

    StyledRect {
        visible: root.showBackground
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

        // Glides to the focused workspace with the shared spring.
        Behavior on x {
            enabled: Motion.enabled
            NumberAnimation {
                duration: Motion.expandDuration
                easing.type: Easing.OutBack
                easing.overshoot: Motion.overshoot
            }
        }

        Behavior on width {
            enabled: Motion.enabled
            NumberAnimation {
                duration: Motion.expandDuration
                easing.type: Easing.OutBack
                easing.overshoot: Motion.overshoot
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
            model: root.workspaceIds

            Item {
                id: workspaceButton

                required property string modelData
                readonly property CompositorWorkspace workspace: CompositorService.workspaceById(modelData)
                readonly property bool active: workspace?.active ?? false
                readonly property list<CompositorWindow> windows: CompositorService.windowsForWorkspace(modelData)
                readonly property bool occupied: windows.length > 0
                readonly property string displayName: workspace?.isNamed ? workspace.name : String(workspace?.idx ?? "")
                readonly property bool showLabel: !active || !occupied

                Layout.preferredWidth: showLabel ? workspaceName.implicitWidth + 16 : Math.max(32, appsRow.implicitWidth + 10)
                Layout.preferredHeight: 28
                scale: workspaceMouse.pressed ? 0.94 : 1.0

                PressBehavior on scale {
                    pressed: workspaceMouse.pressed
                }

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

                    HoverTint {
                        hovered: workspaceMouse.containsMouse && !workspaceButton.active
                        hoverOpacity: 0.12
                    }
                }

                StyledText {
                    id: workspaceName
                    z: 1
                    anchors.centerIn: parent
                    visible: opacity > 0
                    // Opacity-only show/hide — scale resamples glyphs soft.
                    opacity: workspaceButton.showLabel ? 1 : 0
                    text: workspaceButton.displayName
                    color: workspaceButton.workspace?.is_urgent
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
                }

                WorkspaceWindowList {
                    id: appsRow
                    windows: workspaceButton.windows
                    z: 2
                    anchors.centerIn: parent
                    visible: opacity > 0
                    opacity: workspaceButton.active && workspaceButton.occupied ? 1 : 0
                    scale: workspaceButton.active && workspaceButton.occupied ? 1 : 0.85

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

                MouseArea {
                    id: workspaceMouse
                    anchors.fill: parent
                    z: 1
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CompositorService.focusWorkspace(workspaceButton.modelData)
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y < 0)
                CompositorService.focusAdjacentWorkspace(root.bar.screen.name, 1);
            else if (event.angleDelta.y > 0)
                CompositorService.focusAdjacentWorkspace(root.bar.screen.name, -1);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }
}
