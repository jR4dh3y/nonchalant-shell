pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme

Item {
    id: root

    property string text: ""
    property string fontFamily: Config.theme.font
    property int pixelSize: Styling.fontSize(-1)
    property bool bold: true
    property int elide: Text.ElideRight
    property int verticalAlignment: Text.AlignVCenter
    property real progress: 0.0
    property bool isPlaying: false
    property color baseColor: Colors.overBackground
    property color fillColor: Colors.primary
    property color highlightColor: Colors.primaryFixed ?? Colors.primary

    readonly property bool showFluidBar: root.isPlaying && root.progress > 0.0

    implicitWidth: Math.min(baseText.implicitWidth, 200)
    implicitHeight: Math.max(baseText.implicitHeight + (root.showFluidBar ? 6 : 0), 20)

    property real phase: 0.0

    FrameAnimation {
        running: root.isPlaying && root.visible && root.width > 0
        onTriggered: {
            const dt = (frameTime > 0 && frameTime < 0.1) ? frameTime : 0.016;
            root.phase = (root.phase + 2.5 * dt) % (Math.PI * 2);
            if (root.showFluidBar) {
                wavyCanvas.requestPaint();
            }
        }
    }

    Text {
        id: baseText
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: root.showFluidBar ? wavyCanvas.top : parent.bottom
        anchors.bottomMargin: root.showFluidBar ? 1 : 0
        text: root.text
        font.family: root.fontFamily
        font.pixelSize: root.pixelSize
        font.bold: root.bold
        color: (root.isPlaying && root.progress <= 0.0) ? root.fillColor : root.baseColor
        elide: root.elide
        verticalAlignment: root.verticalAlignment
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting

        layer.enabled: root.showFluidBar
        layer.smooth: true
        layer.effect: ShaderEffect {
            property real progress: Math.max(0.0, Math.min(1.0, root.progress))
            property real phase: root.phase
            property real isPlaying: root.isPlaying ? 1.0 : 0.0
            property real canvasWidth: baseText.width
            property real canvasHeight: baseText.height
            property vector2d _pad: Qt.vector2d(0, 0)
            property vector4d baseColor: Qt.vector4d(root.baseColor.r, root.baseColor.g, root.baseColor.b, root.baseColor.a)
            property vector4d fillColor: Qt.vector4d(root.fillColor.r, root.fillColor.g, root.fillColor.b, root.fillColor.a)
            property vector4d highlightColor: Qt.vector4d(root.highlightColor.r, root.highlightColor.g, root.highlightColor.b, root.highlightColor.a)

            vertexShader: "fluid_progress.vert.qsb"
            fragmentShader: "fluid_progress.frag.qsb"
        }
    }

    Canvas {
        id: wavyCanvas
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 5
        visible: root.showFluidBar
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width;
            const h = height;
            if (w <= 0 || h <= 0) return;

            const centerY = h / 2;
            const playedX = Math.max(0.0, Math.min(w, w * root.progress));

            // Unplayed track line (subtle background line)
            if (playedX < w) {
                ctx.beginPath();
                ctx.strokeStyle = Qt.rgba(root.baseColor.r, root.baseColor.g, root.baseColor.b, 0.25);
                ctx.lineWidth = 1.5;
                ctx.lineCap = "round";
                ctx.moveTo(playedX + 2, centerY);
                ctx.lineTo(w, centerY);
                ctx.stroke();
            }

            // Played fluid wavy sine line
            if (playedX > 0) {
                ctx.beginPath();
                ctx.strokeStyle = root.fillColor;
                ctx.lineWidth = 2.0;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                const wavelength = 12.0;
                const k = (2 * Math.PI) / wavelength;
                const amp = 1.6;
                const taperLen = Math.min(10.0, playedX * 0.4);

                for (let x = 0; x <= playedX; x += 1.0) {
                    let envelope = 1.0;
                    if (taperLen > 0.001) {
                        const distStart = x;
                        const distEnd = playedX - x;
                        if (distStart < taperLen) {
                            envelope = Math.min(envelope, 0.5 * (1.0 - Math.cos(Math.PI * distStart / taperLen)));
                        }
                        if (distEnd < taperLen) {
                            envelope = Math.min(envelope, 0.5 * (1.0 - Math.cos(Math.PI * distEnd / taperLen)));
                        }
                    }

                    const waveY = centerY + amp * envelope * Math.sin(x * k - root.phase * 2.0);
                    if (x === 0) ctx.moveTo(x, waveY);
                    else ctx.lineTo(x, waveY);
                }
                ctx.lineTo(playedX, centerY);
                ctx.stroke();

                // Live playhead bead stays stationary at centerY
                ctx.beginPath();
                ctx.fillStyle = root.baseColor;
                ctx.arc(playedX, centerY, 2.0, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }
}
