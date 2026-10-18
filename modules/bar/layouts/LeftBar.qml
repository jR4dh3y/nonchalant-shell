pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.config
import qs.modules.bar.clock
import qs.modules.bar.workspaces
import qs.modules.bar.systray
import qs.modules.components
import qs.modules.services
import qs.modules.services.compositor
import qs.modules.theme
import ".."

Item {
    id: root

    required property ShellScreen screen

    readonly property bool fullscreenOnScreen: CompositorService.fullscreenOutputs.indexOf(root.screen.name) !== -1
    readonly property bool reveal: !CompositorService.overviewOpen && !fullscreenOnScreen
    onRevealChanged: {
        if (!root.reveal)
            trayPopup.close();
    }

    readonly property real outerRadius: Styling.radius(-4)
    readonly property int controlSize: Math.max(36, Config.theme.fontSize + 20)
    readonly property int edgeMargin: 4
    readonly property int contentPadding: 8
    readonly property int barWidth: controlSize + contentPadding * 2
    readonly property int barTargetHeight: barWidth
    readonly property int totalBarHeight: barTargetHeight + root.edgeMargin

    // Keep one floating gap at the screen edge and another beside the dock so
    // tiled windows do not touch the pills.
    readonly property int baseOuterMargin: root.edgeMargin * 2
    readonly property bool shadowsEnabled: false

    readonly property list<CompositorWorkspace> visibleWorkspaces: CompositorService.workspacesForOutput(root.screen.name)
    // Keep delegates alive when only workspace/window state changes.
    readonly property string workspaceOrder: JSON.stringify(visibleWorkspaces.map(workspace => workspace.id))
    property list<string> workspaceIds: []
    onWorkspaceOrderChanged: workspaceIds = visibleWorkspaces.map(workspace => workspace.id)
    Component.onCompleted: workspaceIds = visibleWorkspaces.map(workspace => workspace.id)

    readonly property int activeWorkspaceIndex: visibleWorkspaces.findIndex(workspace => workspace.active)
    readonly property Item activeWorkspaceButton: {
        const count = workspaceRepeater.count;
        return activeWorkspaceIndex >= 0 && activeWorkspaceIndex < count
            ? workspaceRepeater.itemAt(activeWorkspaceIndex) : null;
    }

    readonly property string networkTooltip: {
        if (NetworkService.ethernet)
            return "Ethernet";
        if (!NetworkService.wifiEnabled)
            return "Wi-Fi disabled";
        if (!NetworkService.wifiConnected)
            return "Wi-Fi disconnected";
        return NetworkService.activeSsid || "Wi-Fi";
    }

    property alias barHitbox: hitbox
    readonly property alias timerInputActive: clock.timeToolsOpen
    readonly property alias dashboardInputActive: clock.menuOpen
    readonly property alias trayInputActive: trayPopup.isOpen
    readonly property alias dashboardHitbox: clock.dashboardHitbox
    readonly property bool islandActive: false

    // One footprint for launcher, workspace and status controls.
    component DockIconButton: Item {
        id: button

        required property string tooltipText
        // Glyph or image, whichever the call site provides. An image source
        // wins; both render in the same state colors.
        property string iconText: ""
        property string iconSource: ""
        property string description: ""
        property bool selected: false
        property bool externalHighlight: false
        property bool muted: false
        property bool textLabel: false
        property bool showLabel: true
        property bool occupied: false
        property bool urgent: false
        readonly property color foregroundColor: button.urgent ? Colors.red
            : button.selected ? buttonSurface.item
            : button.occupied ? Styling.srItem("overprimary") : Colors.overBackground

        signal scrolled(real delta)
        signal secondaryClicked
        signal clicked

        implicitWidth: root.controlSize
        implicitHeight: root.controlSize
        Layout.alignment: Qt.AlignHCenter
        Accessible.role: Accessible.Button
        Accessible.name: tooltipText
        scale: buttonMouse.pressed ? 0.90 : 1.0

        PressBehavior on scale {
            pressed: buttonMouse.pressed
        }

        StyledRect {
            id: buttonSurface
            anchors.fill: parent
            variant: button.selected ? "focus" : "common"
            backgroundOpacity: button.selected && !button.externalHighlight ? 1 : 0
            enableBorder: !button.externalHighlight
            radius: root.outerRadius
            enableShadow: false

            HoverTint {
                hovered: buttonMouse.containsMouse && !(button.externalHighlight && button.selected)
                pressed: buttonMouse.pressed
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: button.showLabel && button.iconSource === ""
            text: button.iconText
            font.family: button.textLabel ? Config.theme.font : Icons.font
            font.pixelSize: button.textLabel ? Config.theme.fontSize : Styling.fontSize(4)
            font.weight: button.selected || button.occupied ? Font.DemiBold : Font.Medium
            color: button.foregroundColor
            opacity: button.muted ? 0.5 : 1
        }

        // Tinted like the glyph so the logo follows light/dark, selection
        // and urgent states instead of keeping its baked-in colors. The SVG
        // pads its ink inside a 64px box, so the box is sized up to land the
        // visible mark at the glyph height.
        Image {
            id: iconImage

            readonly property real markSize: Math.round(Styling.fontSize(4) * 1.4)

            anchors.centerIn: parent
            visible: button.showLabel && button.iconSource !== ""
            source: button.iconSource
            sourceSize.width: iconImage.markSize * 2
            sourceSize.height: iconImage.markSize * 2
            width: iconImage.markSize
            height: iconImage.markSize
            fillMode: Image.PreserveAspectFit
            opacity: button.muted ? 0.5 : 1
            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1.0
                colorizationColor: button.foregroundColor
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    button.secondaryClicked();
                else
                    button.clicked();
            }
            onWheel: wheel => {
                const delta = wheel.angleDelta.y || wheel.angleDelta.x;
                button.scrolled(delta);
                wheel.accepted = true;
            }
        }

        StyledToolTip {
            x: button.width + root.contentPadding
            y: (button.height - height) / 2
            show: buttonMouse.containsMouse
            tooltipText: button.tooltipText
            description: button.description
        }
    }

    Item {
        id: hitbox
        width: root.reveal ? root.totalBarHeight : 0
        height: root.height

        Item {
            id: bar
            x: root.edgeMargin
            y: root.edgeMargin
            width: root.barTargetHeight
            height: parent.height - root.edgeMargin * 2

            // Hidden for overview and fullscreen: retracts past the left
            // screen edge on a monotonic curve and springs back in with the
            // island's overshoot.
            property real retraction: 0
            transform: Translate {
                x: -bar.retraction * (root.totalBarHeight + root.edgeMargin)
            }

            states: State {
                name: "hidden"
                when: !root.reveal
                PropertyChanges {
                    bar.retraction: 1
                    bar.opacity: 0
                }
            }

            transitions: [
                Transition {
                    from: "hidden"
                    enabled: Motion.enabled
                    ParallelAnimation {
                        NumberAnimation {
                            property: "retraction"
                            duration: Motion.expandDuration
                            easing.type: Easing.OutBack
                            easing.overshoot: Motion.overshoot
                        }
                        NumberAnimation {
                            property: "opacity"
                            duration: Motion.fadeInDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                },
                Transition {
                    to: "hidden"
                    enabled: Motion.enabled
                    NumberAnimation {
                        properties: "retraction,opacity"
                        duration: Motion.collapseDuration
                        easing.type: Easing.InCubic
                    }
                }
            ]

            StyledRect {
                anchors.fill: parent
                variant: "pane"
                radius: Styling.radius(0)
                backgroundOpacity: 1

                Item {
                    id: dockContent
                    anchors.fill: parent
                    anchors.margins: root.contentPadding

                    ColumnLayout {
                        id: topControls
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Math.max(0, (mediaPill.visible ? mediaPill.y : bottomControls.y) - spacing)
                        spacing: 4

                        DockIconButton {
                            iconSource: Qt.resolvedUrl("../../../assets/nonchalant/nonchalant-icon.svg")
                            tooltipText: "Run menu"
                            selected: Visibilities.currentActiveModule === "launcher"
                            onClicked: GlobalShortcuts.toggleLauncher()
                        }

                        Separator {
                            Layout.fillWidth: false
                            Layout.preferredWidth: root.controlSize / 2
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentHeight: workspaceColumn.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            // Keep the target stable when compositor updates recreate delegates.
                            Item {
                                id: workspaceHighlightTarget
                                visible: false
                                x: (workspaceColumn.width - root.controlSize) / 2
                                y: Math.max(0, root.activeWorkspaceIndex) * (root.controlSize + workspaceColumn.spacing)
                                width: root.controlSize
                                height: Math.max(root.controlSize, root.activeWorkspaceButton?.implicitHeight ?? 0)
                            }

                            ElasticHighlight {
                                objectName: "verticalWorkspaceHighlight"
                                targetItem: workspaceHighlightTarget
                                variant: "focus"
                                radius: root.outerRadius
                                opacity: root.activeWorkspaceIndex >= 0 ? 1 : 0
                                scale: root.activeWorkspaceButton?.scale ?? 1
                            }

                            ColumnLayout {
                                id: workspaceColumn
                                z: 1
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    id: workspaceRepeater
                                    model: root.workspaceIds

                                    DockIconButton {
                                        id: workspaceButton
                                        required property string modelData
                                        readonly property CompositorWorkspace workspace: CompositorService.workspaceById(modelData)
                                        readonly property list<CompositorWindow> windows: CompositorService.windowsForWorkspace(modelData)
                                        readonly property bool showWindows: selected && windows.length > 0
                                        implicitHeight: showWindows ? Math.max(root.controlSize, windowList.implicitHeight + root.contentPadding) : root.controlSize
                                        showLabel: !showWindows
                                        objectName: "verticalWorkspaceButton-" + modelData
                                        externalHighlight: true
                                        iconText: String(workspace?.idx ?? "")
                                        textLabel: true
                                        selected: workspace?.active ?? false
                                        occupied: windows.length > 0
                                        urgent: workspace?.is_urgent ?? false
                                        tooltipText: workspace?.isNamed ? workspace.name : "Workspace " + (workspace?.idx ?? "")
                                        description: windows.length + (windows.length === 1 ? " window" : " windows")

                                        WorkspaceWindowList {
                                            id: windowList
                                            objectName: "verticalWorkspaceWindows-" + workspaceButton.modelData
                                            z: 1
                                            anchors.centerIn: parent
                                            vertical: true
                                            windows: workspaceButton.showWindows ? workspaceButton.windows : []
                                            visible: workspaceButton.showWindows
                                        }

                                        onClicked: CompositorService.focusWorkspace(modelData)
                                        onScrolled: delta => {
                                            if (delta !== 0)
                                                CompositorService.focusAdjacentWorkspace(root.screen.name, delta < 0 ? 1 : -1);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VerticalMediaWidget {
                        id: mediaPill
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.min((dockContent.height - height) / 2,
                            bottomControls.y - height - topControls.spacing)
                        width: implicitWidth
                        height: implicitHeight
                        buttonSize: root.controlSize
                        maximumHeight: Math.min(root.controlSize * 5, root.height / 4,
                            Math.max(root.controlSize, (bottomControls.y - dockContent.height / 2 - topControls.spacing) * 2))
                        onActivated: clock.openControlMenu("media")
                    }

                    ColumnLayout {
                        id: bottomControls
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: topControls.spacing

                        DockIconButton {
                            id: trayButton
                            objectName: "verticalTrayButton"
                            visible: trayPopup.hasItems
                            iconText: trayPopup.isOpen ? Icons.caretLeft : Icons.caretRight
                            tooltipText: "System tray"
                            selected: trayPopup.isOpen
                            onClicked: trayPopup.toggle()

                            TrayFlyout {
                                id: trayPopup
                                anchorItem: trayButton
                                edgeItem: root.barHitbox
                                controlSize: root.controlSize
                                maximumHeight: Math.max(root.controlSize * 2, root.height / 2)
                            }
                        }

                        DockIconButton {
                            id: soundButton
                            iconText: Audio.sink?.audio?.muted ? Icons.speakerSlash : Icons.speakerHigh
                            muted: Audio.sink?.audio?.muted ?? false
                            tooltipText: (muted ? "Muted" : "Volume " + Math.round(Audio.value * 100) + "%")
                            description: "Click for sound · Right-click to mute · Scroll to adjust"
                            onClicked: clock.openControlMenu("sound")
                            onSecondaryClicked: Audio.toggleMute()
                            onScrolled: delta => {
                                if (delta !== 0)
                                    Audio.setVolume(Math.max(0, Math.min(1, Audio.value + (delta > 0 ? 0.05 : -0.05))));
                            }
                        }

                        DockIconButton {
                            id: micButton
                            iconText: Audio.source?.audio?.muted ? Icons.micSlash : Icons.mic
                            muted: Audio.source?.audio?.muted ?? false
                            tooltipText: muted ? "Microphone muted" : "Microphone " + Math.round((Audio.source?.audio?.volume ?? 0) * 100) + "%"
                            description: "Click for microphone · Right-click to mute · Scroll to adjust"
                            onClicked: clock.openControlMenu("mic")
                            onSecondaryClicked: Audio.toggleMicMute()
                            onScrolled: delta => {
                                if (delta !== 0)
                                    Audio.setMicVolume(Math.max(0, Math.min(1, (Audio.source?.audio?.volume ?? 0) + (delta > 0 ? 0.05 : -0.05))));
                            }
                        }

                        BrightnessSlider {
                            objectName: "verticalBrightnessControl"
                            Layout.alignment: Qt.AlignHCenter
                            flat: true
                            meterSize: root.controlSize
                            bar: root
                        }

                        DockIconButton {
                            id: deviceStatusButton
                            objectName: "verticalDeviceStatusButton"
                            showLabel: false
                            selected: clock.deviceMenuActive
                            tooltipText: (Battery.available ? Math.round(Battery.percentage) + "% battery"
                                + (Battery.isCharging ? " · Charging" : (Battery.isPluggedIn ? " · Plugged in" : "")) : "AC power")
                                + "\n" + root.networkTooltip + " · " + (!BluetoothService.enabled
                                ? "Bluetooth off" : (BluetoothService.firstConnectedDeviceName || "Bluetooth on"))
                            description: "Open Wi-Fi, Bluetooth and battery"
                            onClicked: clock.toggleDeviceMenu()

                            DeviceStatusIcon {
                                objectName: "verticalDeviceStatusIcon"
                                anchors.centerIn: parent
                                width: implicitWidth
                                height: implicitHeight
                                foregroundColor: deviceStatusButton.foregroundColor
                                selected: deviceStatusButton.selected
                            }
                        }

                        Separator {
                            Layout.fillWidth: false
                            Layout.preferredWidth: root.controlSize / 2
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                        }

                        Clock {
                            id: clock
                            Layout.alignment: Qt.AlignHCenter
                            vertical: true
                            verticalWidth: root.controlSize
                            mediaAnchor: mediaPill
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.outerRadius
                            endRadius: root.outerRadius
                        }
                    }
                }
            }
        }
    }
}
