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

    implicitWidth: Math.min(baseText.implicitWidth, 200)
    implicitHeight: Math.max(baseText.implicitHeight, 20)

    property real phase: 0.0

    FrameAnimation {
        running: root.isPlaying && root.visible && root.width > 0
        onTriggered: {
            const dt = (frameTime > 0 && frameTime < 0.1) ? frameTime : 0.016;
            root.phase = (root.phase + 2.5 * dt) % (Math.PI * 2);
        }
    }

    Text {
        id: baseText
        anchors.fill: parent
        text: root.text
        font.family: root.fontFamily
        font.pixelSize: root.pixelSize
        font.bold: root.bold
        color: (root.isPlaying && root.progress <= 0.0) ? root.fillColor : root.baseColor
        elide: root.elide
        verticalAlignment: root.verticalAlignment
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting

        layer.enabled: root.isPlaying && root.progress > 0.0
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
}
