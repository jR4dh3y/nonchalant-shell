pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)

    required property PwNode node
    property string icon: ""
    property bool isMainDevice: false

    implicitHeight: 56
    implicitWidth: parent?.width ?? 300

    PwObjectTracker {
        objects: [root.node]
    }

    readonly property bool isMuted: root.node?.audio?.muted ?? false
    readonly property real volume: root.node?.audio?.volume ?? 0
    property real lastSetVolume: volume

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // First row: Icon + Slider
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Mute button with icon
            Button {
                id: muteButton
                flat: true
                implicitWidth: 32
                implicitHeight: 32
                Layout.preferredWidth: 32
                Layout.maximumWidth: 32
                Layout.fillWidth: false
                scale: muteButton.down ? 0.90 : 1.0

                PressBehavior on scale {
                    pressed: muteButton.down
                }

                background: StyledRect {
                    variant: muteButton.hovered ? "focus" : "common"
                    radius: Styling.radius(4)
                }

                contentItem: Item {
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        anchors.centerIn: parent
                        text: {
                            if (root.isMuted)
                                return Icons.speakerSlash;
                            if (root.icon)
                                return root.icon;
                            return Icons.speakerHigh;
                        }
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: root.isMuted ? root.shellPalette.overSurfaceVariant : root.shellPalette.overBackground

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                            }
                        }
                    }
                }

                onClicked: {
                    if (root.node?.audio) {
                        root.node.audio.muted = !root.node.audio.muted;
                    }
                }

                StyledToolTip {
                    show: muteButton.hovered
                    tooltipText: root.isMuted ? "Unmute" : "Mute"
                }
            }

            // Volume slider
            StyledSlider {
                id: volumeSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                value: root.volume
                scroll: false
                progressColor: {
                    if (root.isMuted)
                        return root.shellPalette.outlineVariant;
                    if (Audio.protectionTriggered && root.isMainDevice)
                        return root.shellPalette.warning;
                    return Styling.srItem("overprimary", root.shellPalette);
                }

                onValueChanged: {
                    if (root.node?.audio && Math.abs(value - root.volume) > 0.001) {
                        Audio.setNodeVolume(root.node, value);
                    }
                }

                Behavior on progressColor {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration / 2
                    }
                }
            }
        }

        // Second row: Name + Separator + Percentage
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Source name
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: root.isMainDevice ? Audio.friendlyDeviceName(root.node) : Audio.appNodeDisplayName(root.node)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: root.shellPalette.overSurfaceVariant
            }

            // Separator line
            Separator {
                Layout.fillWidth: true
            }

            // Protection indicator
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                visible: Audio.protectionTriggered && root.isMainDevice
                text: Icons.shieldCheck
                font.family: Icons.font
                font.pixelSize: 12
                color: root.shellPalette.warning

                StyledToolTip {
                    show: parent.visible && protectionIndicatorMa.containsMouse
                    tooltipText: "Volume protection active"
                }

                MouseArea {
                    id: protectionIndicatorMa
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // Percentage
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: `${Math.round(root.volume * 100)}%`
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: root.shellPalette.overSurfaceVariant
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
