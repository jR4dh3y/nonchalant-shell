pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme

// Read-only text gives us Qt's actual cursor geometry, including proportional
// glyphs, UTF-16 word offsets and wrapping. The fill follows that geometry.
TextEdit {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)

    property real characterProgress: 0
    property real phase: 0
    property bool fluidEnabled: false
    property bool playing: false
    property int progressDuration: 0
    property list<rect> characterRects: []
    property list<bool> characterRtl: []
    property string geometryKey: ""
    property int geometryGeneration: 0
    readonly property bool truncated: contentWidth > width + 1
    readonly property vector4d fillCursor: {
        if (!root.ready || !root.fluidEnabled)
            return Qt.vector4d(0, 0, 0, 1);
        if (root.characterRects.length === 0)
            return Qt.vector4d(0, 0, 0, 1);
        const value = Math.max(0, Math.min(root.characterRects.length - 1, root.characterProgress));
        const start = Math.floor(value);
        const a = root.characterRects[start];
        const next = Math.min(root.characterRects.length - 1, start + 1);
        const b = root.characterRects[next];
        // At a wrap boundary, finish the current row before starting the next.
        const sameRow = Math.abs(a.y - b.y) < 1;
        const rtl = root.characterRtl[start] ?? false;
        const endX = sameRow ? b.x : (rtl ? 0 : root.width);
        return Qt.vector4d(a.x + (endX - a.x) * (value - start), a.y, a.height,
            rtl ? -1 : 1);
    }

    Behavior on characterProgress {
        // Interpolate normal playback samples. Seeks and line changes snap to
        // their new timestamp instead of sliding through unrelated words.
        enabled: root.fluidEnabled && root.playing && root.progressDuration > 0
            && targetValue >= root.characterProgress && targetValue - root.characterProgress < 3
        NumberAnimation { duration: root.progressDuration; easing.type: Easing.Linear }
    }

    // Native document geometry is immutable between text/font/size changes.
    // Never call into QTextDocument from a progress or phase binding.
    function cacheGeometry(): void {
        if (!root.ready || !root.fluidEnabled)
            return;
        const key = [root.text, root.width, root.height, root.contentHeight,
            root.font.family, root.font.styleName, root.font.pixelSize, root.font.pointSize,
            root.font.weight, root.font.italic, root.font.letterSpacing, root.font.wordSpacing,
            root.font.capitalization, root.font.hintingPreference, root.wrapMode, root.horizontalAlignment,
            root.verticalAlignment].join("\n");
        if (key === root.geometryKey)
            return;
        const rectangles = [];
        const directions = [];
        for (let i = 0; i <= root.length; ++i) {
            rectangles.push(root.positionToRectangle(i));
            directions.push(root.isRightToLeft(i, Math.min(root.length, i + 1)));
        }
        root.geometryKey = key;
        root.characterRects = rectangles;
        root.characterRtl = directions;
        root.geometryGeneration += 1;
    }

    onTextChanged: Qt.callLater(root.cacheGeometry)
    onWidthChanged: Qt.callLater(root.cacheGeometry)
    onHeightChanged: Qt.callLater(root.cacheGeometry)
    onContentHeightChanged: Qt.callLater(root.cacheGeometry)
    onFontChanged: Qt.callLater(root.cacheGeometry)
    onWrapModeChanged: Qt.callLater(root.cacheGeometry)
    onHorizontalAlignmentChanged: Qt.callLater(root.cacheGeometry)
    onVerticalAlignmentChanged: Qt.callLater(root.cacheGeometry)
    onFluidEnabledChanged: Qt.callLater(root.cacheGeometry)

    readOnly: true
    activeFocusOnPress: false
    selectByMouse: false
    selectByKeyboard: false
    cursorVisible: false
    textFormat: TextEdit.PlainText
    color: root.shellPalette.overBackground
    font.family: Config.theme.font
    font.pixelSize: Styling.fontSize(1)
    font.weight: Font.DemiBold
    font.hintingPreference: Font.PreferFullHinting
    renderType: TextEdit.NativeRendering
    horizontalAlignment: TextEdit.AlignHCenter
    verticalAlignment: TextEdit.AlignVCenter
    wrapMode: TextEdit.Wrap

    // A layer created during TextEdit::componentComplete can read text before
    // Qt has populated its document, clearing the initially cached string.
    property bool ready: false
    Component.onCompleted: {
        root.ready = true;
        Qt.callLater(root.cacheGeometry);
    }

    layer.enabled: root.ready && root.fluidEnabled
    layer.smooth: true
    layer.effect: ShaderEffect {
        objectName: "lyricsFluidEffect"
        property real progress: root.text.length > 0 ? root.characterProgress / root.text.length : 0
        property real phase: root.phase
        // Pausing freezes the clock, not the already-filled text.
        property real isPlaying: 1
        property real canvasWidth: root.width
        property real canvasHeight: root.height
        property vector2d _pad: Qt.vector2d(0, 0)
        property vector4d baseColor: Qt.vector4d(root.shellPalette.overSurfaceVariant.r, root.shellPalette.overSurfaceVariant.g, root.shellPalette.overSurfaceVariant.b, root.shellPalette.overSurfaceVariant.a)
        property vector4d fillColor: Qt.vector4d(root.shellPalette.primary.r, root.shellPalette.primary.g, root.shellPalette.primary.b, root.shellPalette.primary.a)
        property vector4d highlightColor: {
            const c = root.shellPalette.primaryFixed ?? root.shellPalette.primary;
            return Qt.vector4d(c.r, c.g, c.b, c.a);
        }
        property vector4d textCursor: root.fillCursor

        vertexShader: "fluid_lyrics.vert.qsb"
        fragmentShader: "fluid_lyrics.frag.qsb"
    }
}
