pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

Item {
    id: root

    implicitWidth: 400
    implicitHeight: 38

    readonly property real position: MprisController.activePlayer?.position ?? 0.0
    readonly property real length: Math.max(1.0, MprisController.activePlayer?.length ?? 1.0)
    readonly property real progress: Math.min(1.0, Math.max(0.0, root.position / root.length))

    readonly property bool isPlaying: MprisController.isPlaying

    function formatTime(seconds: real): string {
        const totalSecs = Math.max(0, Math.floor(seconds));
        const mins = Math.floor(totalSecs / 60);
        const secs = totalSecs % 60;
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    Timer {
        running: MprisController.isPlaying
        interval: 1000
        repeat: true
        onTriggered: {
            MprisController.activePlayer?.positionChanged();
        }
    }

    function seekTo(fraction: real) {
        if (!MprisController.activePlayer)
            return;
        const targetPos = Math.max(0.0, Math.min(root.length, fraction * root.length));
        if (MprisController.activePlayer.canSeek) {
            MprisController.activePlayer.position = targetPos;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // Wavy progress line area
        Item {
            id: waveformArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            MouseArea {
                id: waveMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    const fraction = Math.max(0.0, Math.min(1.0, mouse.x / width));
                    root.seekTo(fraction);
                }

                onPositionChanged: mouse => {
                    if (pressed) {
                        const fraction = Math.max(0.0, Math.min(1.0, mouse.x / width));
                        root.seekTo(fraction);
                    }
                }
            }

            // Unplayed track
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: 0
                width: parent.width
                height: 2
                radius: 1
                color: Colors.surfaceBright
            }

            // Played portion: wavy line clipped to progress
            Item {
                anchors.verticalCenter: parent.verticalCenter
                x: 0
                width: Math.max(0, parent.width * root.progress)
                height: 16
                clip: true

                CarouselProgress {
                    anchors.fill: parent
                    frequency: root.isPlaying ? 8 : 0
                    color: Colors.primary
                    amplitudeMultiplier: root.isPlaying ? 1 : 0.0
                    dotSize: 2
                    fullLength: waveformArea.width
                    running: root.isPlaying
                }
            }

            // Playhead handle
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, parent.width * root.progress - width / 2))
                width: waveMouseArea.containsMouse || waveMouseArea.pressed ? 2 : 4
                height: waveMouseArea.containsMouse || waveMouseArea.pressed ? 20 : 16
                radius: 2
                color: Colors.overBackground
            }
        }

        // Time labels
        RowLayout {
            Layout.fillWidth: true

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: root.formatTime(root.position)
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: root.formatTime(root.length)
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
            }
        }
    }
}
