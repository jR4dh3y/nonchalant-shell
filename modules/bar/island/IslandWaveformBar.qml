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

    property bool isDragging: false
    property real dragProgress: 0.0
    readonly property real displayProgress: isDragging ? dragProgress : root.progress

    property real phase: 0.0
    property real currentAmplitude: (root.isPlaying ? 5.0 : 0.0)
    Behavior on currentAmplitude {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutCubic
        }
    }

    readonly property color primaryColor: Colors.primary
    readonly property color surfaceBrightColor: Colors.surfaceBright
    onPrimaryColorChanged: canvas.requestPaint()
    onSurfaceBrightColorChanged: canvas.requestPaint()
    onDisplayProgressChanged: canvas.requestPaint()
    onCurrentAmplitudeChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onVisibleChanged: if (visible) canvas.requestPaint()

    function formatTime(seconds: real): string {
        const totalSecs = Math.max(0, Math.floor(seconds));
        const mins = Math.floor(totalSecs / 60);
        const secs = totalSecs % 60;
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    Timer {
        running: MprisController.isPlaying && !root.isDragging
        interval: 1000
        repeat: true
        onTriggered: {
            MprisController.activePlayer?.positionChanged();
        }
    }

    function seekTo(fraction: real) {
        if (!MprisController.activePlayer)
            return;
        const player = MprisController.activePlayer;
        const targetPos = Math.max(0.0, Math.min(root.length, fraction * root.length));
        if (player.canSeek ?? true) {
            player.position = targetPos;
        }
    }

    readonly property bool shouldAnimate: (root.isPlaying || root.currentAmplitude > 0.01)
        && root.visible
        && root.opacity > 0
        && root.width > 0

    FrameAnimation {
        id: waveAnim
        running: root.shouldAnimate
        onTriggered: {
            const dt = waveAnim.frameTime > 0 && waveAnim.frameTime < 0.1 ? waveAnim.frameTime : 0.016;
            root.phase = (root.phase + 2.6 * dt) % (Math.PI * 2);
            canvas.requestPaint();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // Wavy progress bar area (wave + unplayed track + playhead)
        Item {
            id: waveformArea
            Layout.fillWidth: true
            Layout.preferredHeight: 20

            MouseArea {
                id: waveMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: root.isDragging

                onPressed: mouse => {
                    root.isDragging = true;
                    root.dragProgress = Math.max(0.0, Math.min(1.0, mouse.x / width));
                }

                onPositionChanged: mouse => {
                    if (root.isDragging) {
                        root.dragProgress = Math.max(0.0, Math.min(1.0, mouse.x / width));
                    }
                }

                onReleased: mouse => {
                    if (root.isDragging) {
                        const finalProgress = Math.max(0.0, Math.min(1.0, mouse.x / width));
                        root.seekTo(finalProgress);
                        root.isDragging = false;
                    }
                }

                onCanceled: {
                    root.isDragging = false;
                }
            }

            Canvas {
                id: canvas
                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();

                    const w = width;
                    const h = height;
                    if (w <= 0 || h <= 0)
                        return;

                    const centerY = h / 2;
                    const strokeW = 3.5;
                    const halfStroke = strokeW / 2;
                    const playedX = Math.max(halfStroke, Math.min(w - halfStroke, w * root.displayProgress));

                    // 1. Unplayed straight track line
                    const unplayedStartX = playedX + 3.0;
                    const unplayedEndX = w - halfStroke;
                    if (unplayedStartX < unplayedEndX) {
                        ctx.beginPath();
                        ctx.strokeStyle = root.surfaceBrightColor;
                        ctx.lineWidth = 3.0;
                        ctx.lineCap = "round";
                        ctx.moveTo(unplayedStartX, centerY);
                        ctx.lineTo(unplayedEndX, centerY);
                        ctx.stroke();
                    }

                    // 2. Played wavy sine progress line
                    const playedStartX = halfStroke;
                    const playedLen = playedX - playedStartX;
                    if (playedLen > 0) {
                        ctx.beginPath();
                        ctx.strokeStyle = root.primaryColor;
                        ctx.lineWidth = strokeW;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";

                        const wavelength = 16.0;
                        const k = (2 * Math.PI) / wavelength;
                        const amp = root.currentAmplitude;
                        const taperLen = Math.min(14.0, playedLen * 0.5);

                        for (let x = playedStartX; x < playedX; x += 1.0) {
                            let envelope = 1.0;
                            if (taperLen > 0.001) {
                                const distStart = x - playedStartX;
                                const distEnd = playedX - x;
                                if (distStart < taperLen) {
                                    envelope = Math.min(envelope, 0.5 * (1.0 - Math.cos(Math.PI * distStart / taperLen)));
                                }
                                if (distEnd < taperLen) {
                                    envelope = Math.min(envelope, 0.5 * (1.0 - Math.cos(Math.PI * distEnd / taperLen)));
                                }
                            }

                            const waveY = centerY + amp * envelope * Math.sin((x - playedStartX) * k - root.phase);
                            if (x === playedStartX) {
                                ctx.moveTo(x, waveY);
                            } else {
                                ctx.lineTo(x, waveY);
                            }
                        }
                        ctx.lineTo(playedX, centerY);
                        ctx.stroke();
                    }
                }
            }

            // Playhead handle: vertical rounded capsule matching reference
            Rectangle {
                id: playheadHandle
                property real handleW: waveMouseArea.containsMouse || root.isDragging ? 5 : 4
                property real handleH: waveMouseArea.containsMouse || root.isDragging ? 18 : 16

                x: Math.max(0, Math.min(waveformArea.width - width, waveformArea.width * root.displayProgress - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: handleW
                height: handleH
                radius: width / 2
                color: Colors.overBackground

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            }
        }

        // Time labels
        RowLayout {
            Layout.fillWidth: true

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: root.formatTime(root.isDragging ? root.dragProgress * root.length : root.position)
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
