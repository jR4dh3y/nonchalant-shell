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

    readonly property int barCount: 36
    readonly property real barSpacing: 2
    readonly property real barWidth: Math.max(2, (waveformArea.width - (root.barCount - 1) * root.barSpacing) / root.barCount)

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

        // Waveform bars area
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

            Row {
                anchors.centerIn: parent
                spacing: root.barSpacing

                Repeater {
                    model: root.barCount

                    Item {
                        id: barItem
                        required property int index

                        width: root.barWidth
                        height: waveformArea.height

                        // Simulated audio waveform profile: higher in middle, subtle harmonics
                        readonly property real profile: {
                            const normalized = index / (root.barCount - 1);
                            const sinVal = Math.sin(normalized * Math.PI);
                            const harmonic = 0.3 * Math.sin(normalized * Math.PI * 4);
                            return Math.max(0.25, Math.min(1.0, sinVal * 0.75 + harmonic + 0.2));
                        }

                        readonly property real barHeight: Math.max(4, height * profile)
                        readonly property bool isPlayed: (index / root.barCount) <= root.progress

                        StyledRect {
                            anchors.centerIn: parent
                            width: root.barWidth
                            height: barItem.barHeight
                            radius: width / 2
                            variant: barItem.isPlayed ? "primary" : "common"
                            opacity: barItem.isPlayed ? 1.0 : (waveMouseArea.containsMouse ? 0.45 : 0.25)

                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                        }
                    }
                }
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
