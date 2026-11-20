import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.globals
import qs.modules.theme
import qs.config
import "MpvShaderGenerator.js" as ShaderGenerator
import "WallpaperFiles.js" as Files

PanelWindow {
    id: wallpaper

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nonchalant:wallpaper"
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    readonly property WallpaperManager manager: GlobalStates.wallpaperManager
    property WallpaperManager registeredManager: null
    readonly property string storedOverride: manager?.perScreenWallpapers?.[currentScreenName] ?? ""
    readonly property string overrideWallpaper: manager?.requestedOverrides?.[currentScreenName] ?? storedOverride
    readonly property string candidateWallpaper: overrideWallpaper || (manager?.globalCandidate ?? "")
    readonly property bool candidateImageReady: candidateWallpaper !== "" && pictures.ready
    readonly property bool candidateImageFailed: candidateWallpaper !== "" && pictures.failed
    readonly property string effectiveWallpaper: pictures.activePicture?.path ?? ""
    property bool appliedLocal: false
    readonly property bool hasLocalWallpaper: appliedLocal || (!effectiveWallpaper && storedOverride !== "")
    readonly property ShellPalette shellPalette: DisplayPalettes.forScreen(currentScreenName)
    readonly property string presetPaletteKey: manager?.presetPaletteKey ?? ""
    readonly property string overridePaletteKey: {
        if (!currentScreenName || !overrideWallpaper)
            return "";
        if (manager?.activeColorPreset)
            return presetPaletteKey ? JSON.stringify([presetPaletteKey, overrideWallpaper]) : "";
        return outputColors.ready ? outputColors.request : "";
    }

    property string currentScreenName: wallpaper.screen ? wallpaper.screen.name : ""
    onCurrentScreenNameChanged: Qt.callLater(syncPresentation)
    onManagerChanged: Qt.callLater(registerWithManager)
    onOverridePaletteKeyChanged: Qt.callLater(syncPresentation)
    onOverrideWallpaperChanged: Qt.callLater(syncPresentation)
    onCandidateWallpaperChanged: {
        manager?.queueFrame(candidateWallpaper);
        pictures?.prepare(candidateWallpaper);
        Qt.callLater(syncPresentation);
    }
    onCandidateImageReadyChanged: Qt.callLater(syncPresentation)
    onCandidateImageFailedChanged: Qt.callLater(syncPresentation)
    readonly property bool tintEnabled: manager?.tintEnabled ?? false
    readonly property string wallpaperMode: manager?.wallpaperMode ?? "crop"

    WallpaperColorJob {
        id: outputColors
        destination: wallpaper.currentScreenName
            ? Quickshell.env("HOME") + "/.cache/nonchalant/colors-" + encodeURIComponent(wallpaper.currentScreenName) + ".json" : ""
        image: destination && !wallpaper.manager?.activeColorPreset ? wallpaper.overrideWallpaper : ""
        scheme: wallpaper.manager?.currentMatugenScheme ?? "scheme-wallpaper"
        mode: wallpaper.manager?.colorMode ?? "dark"
        canPublish: wallpaper.candidateImageReady && wallpaper.overrideWallpaper === wallpaper.candidateWallpaper
        onFailedChanged: if (failed) Qt.callLater(wallpaper.syncPresentation)
    }

    // Read each replacement off-screen so the registered palette cannot
    // change until both the file load and the request check have succeeded.
    property DisplayPaletteFile displayColors: null
    property DisplayPaletteFile pendingColors: null
    Component.onCompleted: {
        registerWithManager();
        pictures.prepare(candidateWallpaper);
    }
    Component.onDestruction: {
        if (registeredManager)
            registeredManager.wallpaperOutputs = registeredManager.wallpaperOutputs.filter(output => output !== wallpaper);
        if (displayColors)
            DisplayPalettes.unregister(displayColors.outputName, displayColors);
    }
    Connections {
        target: wallpaper.manager
        function onDisplayedWallpaperChanged(): void { wallpaper.syncPresentation(); }
    }

    function registerWithManager(): void {
        if (registeredManager === manager)
            return;
        if (registeredManager)
            registeredManager.wallpaperOutputs = registeredManager.wallpaperOutputs.filter(output => output !== wallpaper);
        registeredManager = manager;
        if (registeredManager)
            registeredManager.wallpaperOutputs = [...registeredManager.wallpaperOutputs, wallpaper];
    }

    function syncPresentation(): void {
        if (!currentScreenName || !manager)
            return;
        if (!overrideWallpaper) {
            pendingColors = null;
            if (!pictures.show(manager.displayedWallpaper))
                return;
            clearDisplayPalette();
            appliedLocal = false;
            manager.finishOverride(currentScreenName, "", true);
            return;
        }
        if (candidateImageFailed) {
            manager.finishOverride(currentScreenName, overrideWallpaper, false);
            return;
        }
        if (outputColors.failed && !manager.activeColorPreset) {
            if (!pictures.show(overrideWallpaper))
                return;
            pendingColors = null;
            clearDisplayPalette();
            appliedLocal = true;
            manager.finishOverride(currentScreenName, overrideWallpaper, true);
            return;
        }
        const key = overridePaletteKey;
        if (!key || displayColors?.requestKey === key)
            return;
        if (pendingColors?.requestKey === key) {
            if (pendingColors.loaded && pictures.show(overrideWallpaper)) {
                const previous = displayColors;
                displayColors = pendingColors;
                pendingColors = null;
                DisplayPalettes.register(displayColors.outputName, displayColors);
                if (previous && previous.outputName !== displayColors.outputName)
                    DisplayPalettes.unregister(previous.outputName, previous);
                appliedLocal = true;
                manager.finishOverride(currentScreenName, overrideWallpaper, true);
            }
            return;
        }
        const candidate = displayColors === firstPalette ? secondPalette : firstPalette;
        const path = presetPaletteKey ? manager.globalPalettePath : outputColors.destination;
        pendingColors = candidate;
        candidate.loaded = false;
        candidate.requestKey = key;
        candidate.outputName = currentScreenName;
        if (candidate.path === path)
            candidate.reload();
        else
            candidate.path = path;
    }

    function clearDisplayPalette(): void {
        if (displayColors) {
            DisplayPalettes.unregister(displayColors.outputName, displayColors);
            displayColors = null;
        }
    }

    function finishPaletteLoad(candidate: DisplayPaletteFile, key: string, loaded: bool): void {
        if (pendingColors !== candidate || candidate.requestKey !== key)
            return;
        if (loaded && key === overridePaletteKey && candidate.outputName === currentScreenName) {
            candidate.loaded = true;
            syncPresentation();
        } else {
            pendingColors = null;
        }
    }

    component DisplayPaletteFile: ShellPalette {
        id: candidate
        property string requestKey: ""
        property string outputName: ""
        property bool loaded: false
        watchChanges: false
        printErrors: false
        onLoaded: Qt.callLater(wallpaper.finishPaletteLoad, candidate, requestKey, true)
        onLoadFailed: Qt.callLater(wallpaper.finishPaletteLoad, candidate, requestKey, false)
    }

    DisplayPaletteFile { id: firstPalette }
    DisplayPaletteFile { id: secondPalette }

    function getLockscreenFramePath(path: string): string {
        return Files.framePath(path, Quickshell.env("HOME") + "/.cache/nonchalant");
    }

    function getLockscreenFrameUrl(path: string): string {
        return Files.frameUrl(path, Quickshell.env("HOME") + "/.cache/nonchalant", GlobalStates.wallpaperFrameRevisions);
    }

    // Keep the lockscreen frame warm in QML's pixmap cache. The lock surface's
    // TintedWallpaper loads the same URL with the same sourceSize, so on lock
    // its first frame is a cache hit instead of a fresh async decode (which
    // shows as a flash of solid color). Covers video/GIF lockscreen frames,
    // which are not displayed anywhere else.
    Image {
        id: lockscreenFramePreloader
        visible: false
        cache: true
        mipmap: true
        smooth: true
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: wallpaper.width
        sourceSize.height: wallpaper.height
        source: wallpaper.getLockscreenFrameUrl(wallpaper.effectiveWallpaper)
    }


    readonly property int wallpaperFillMode: {
        switch (wallpaperMode) {
        case "fit":
            return Image.PreserveAspectFit;
        case "stretch":
            return Image.Stretch;
        case "center":
            return Image.Pad;
        default:
            return Image.PreserveAspectCrop;
        }
    }

    // QUICKSHELL-GIT: property string mpvShaderDir: Quickshell.cacheDir + "/mpv_shaders_" + (currentScreenName ? currentScreenName : "ALL")
    property string mpvShaderDir: Quickshell.env("HOME") + "/.cache/nonchalant/mpv_shaders_" + (currentScreenName ? currentScreenName : "ALL")
    property string mpvShaderPath: ""
    property bool mpvShaderReady: false

    readonly property var optimizedPalette: ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || manager?.cacheDir || ""
    readonly property string mpvSocket: runtimeDir + "/nonchalant_mpv_socket_" + currentScreenName
    property bool videoPlaying: false

    function updateMpvRuntime(enable: bool): void {
        videoRenderer.item?.setShader(enable ? mpvShaderPath : "");
    }

    function updateMpvShader() {
        if (Files.type(effectiveWallpaper) !== "video") {
            return;
        }
        if (!wallpaper.tintEnabled) {
            updateMpvRuntime(false);
            return;
        }

        var colors = [];
        // Log the first color to see if it changed
        var firstColorRaw = wallpaper.shellPalette[optimizedPalette[0]];
        console.log("Generating MPV shader. First palette color (" + optimizedPalette[0] + "):", firstColorRaw);

        for (var i = 0; i < optimizedPalette.length; i++) {
            var rawColor = wallpaper.shellPalette[optimizedPalette[i]];
            if (rawColor) {
                var c = Qt.darker(rawColor, 1.0);
                if (c && !isNaN(c.r) && !isNaN(c.g) && !isNaN(c.b)) {
                    colors.push({
                        r: c.r,
                        g: c.g,
                        b: c.b
                    });
                }
            }
        }

        if (colors.length === 0) {
            console.warn("MpvShaderGenerator: No valid colors found for palette! Aborting.");
            return;
        }

        var shaderContent = ShaderGenerator.generate(colors);

        // Generate a unique filename in a dedicated directory
        var timestamp = Date.now();
        var currentShaderPath = mpvShaderDir + "/tint_" + timestamp + ".glsl";

        // Store the current active path so updateMpvRuntime knows which one to use
        wallpaper.mpvShaderPath = currentShaderPath;

        var cmd = ["python3", "-c", "import sys, os, pathlib; " + "d = pathlib.Path(sys.argv[1]); " + "d.mkdir(parents=True, exist_ok=True); " + "[f.unlink() for f in d.iterdir() if f.is_file()]; " + "pathlib.Path(sys.argv[2]).write_text(sys.argv[3]); " + "print('Wrote shader to ' + sys.argv[2]); " + "legacy_dir = os.path.dirname(sys.argv[1]); " + "[pathlib.Path(legacy_dir, f).unlink(missing_ok=True) for f in ['mpv_tint_0.glsl', 'mpv_tint_1.glsl', 'mpv_tint.glsl']]", mpvShaderDir, currentShaderPath, shaderContent];

        mpvShaderWriter.command = cmd;
        mpvShaderWriter.running = true;
    }

    Process {
        id: mpvShaderWriter
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("mpvShaderWriter stdout:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("mpvShaderWriter stderr:", text);
                }
            }
        }

        onExited: code => {
            if (code === 0) {
                console.log("MPV tint shader generated at:", mpvShaderPath);
                mpvShaderReady = true;
                // Apply immediately via IPC
                updateMpvRuntime(true);
            } else {
                console.warn("Failed to generate MPV shader");
            }
        }
    }

    // Trigger update when colors change
    Timer {
        id: shaderUpdateDebounce
        interval: 500
        onTriggered: {
            console.log("Shader debounce triggered, updating MPV...");
            updateMpvShader();
        }
    }

    Connections {
        target: wallpaper.shellPalette
        // Watch for file reload (theme change)
        function onFileChanged() {
            console.log("Colors file changed, scheduling update...");
            shaderUpdateDebounce.restart();
        }
        // Watch for background change (OLED mode often affects this first/only)
        function onBackgroundChanged() {
            console.log("Colors background changed, scheduling update...");
            shaderUpdateDebounce.restart();
        }
        // Fallback
        function onPrimaryChanged() {
            console.log("Colors primary changed, scheduling update...");
            shaderUpdateDebounce.restart();
        }
    }

    Connections {
        target: Config
        function onOledModeChanged() {
            console.log("Config OLED mode changed, scheduling update...");
            shaderUpdateDebounce.restart();
        }
    }

    onShellPaletteChanged: shaderUpdateDebounce.restart()

    onTintEnabledChanged: {
        console.log("Tint enabled changed to", tintEnabled);
        updateMpvShader();
    }

    onEffectiveWallpaperChanged: {
        if (Files.type(effectiveWallpaper) === "video") {
            mpvShaderReady = false;
            shaderUpdateDebounce.restart();
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: wallpaper.videoPlaying ? "transparent" : "black"
        focus: true

        Keys.onLeftPressed: {
            wallpaper.manager?.stepWallpaper(-1);
        }

        Keys.onRightPressed: {
            wallpaper.manager?.stepWallpaper(1);
        }

        Item {
            id: pictures
            anchors.fill: parent

            property PictureSlot activePicture: null
            readonly property PictureSlot stagedPicture: activePicture === firstPicture ? secondPicture : firstPicture
            readonly property bool ready: activePicture?.path === wallpaper.candidateWallpaper
                || (stagedPicture.path === wallpaper.candidateWallpaper && stagedPicture.ready)
            readonly property bool failed: stagedPicture.path === wallpaper.candidateWallpaper && stagedPicture.failed

            function prepare(path: string): void {
                stagedPicture.path = activePicture?.path === path ? "" : path;
            }

            function show(path: string): bool {
                if (!path)
                    return false;
                if (activePicture?.path === path)
                    return true;
                if (stagedPicture.path !== path || !stagedPicture.ready)
                    return false;
                const previous = activePicture;
                activePicture = stagedPicture;
                if (previous)
                    previous.path = "";
                return true;
            }

            PictureSlot {
                id: firstPicture
                visible: pictures.activePicture === firstPicture && !wallpaper.videoPlaying
            }

            PictureSlot {
                id: secondPicture
                visible: pictures.activePicture === secondPicture && !wallpaper.videoPlaying
            }

            layer.enabled: wallpaper.tintEnabled
            layer.effect: ShaderEffect {
                property var paletteTexture: paletteTextureSource
                property real paletteSize: wallpaper.optimizedPalette.length
                property real texWidth: pictures.width
                property real texHeight: pictures.height

                vertexShader: "palette.vert.qsb"
                fragmentShader: "palette.frag.qsb"
            }
        }

        // Palette generation for the shader
        Item {
            id: paletteSourceItem
            // Must be visible for ShaderEffectSource to capture it,
            // but we hide it visually by placing it behind or expecting ShaderEffectSource hideSource behavior.
            visible: true
            width: wallpaper.optimizedPalette.length
            height: 1
            opacity: 0 // Make invisible to eye but maintain presence for capture if needed (though hideSource usually handles this)

            Row {
                anchors.fill: parent
                Repeater {
                    model: wallpaper.optimizedPalette
                    Rectangle {
                        width: 1
                        height: 1
                        color: wallpaper.shellPalette[modelData]
                    }
                }
            }
        }

        ShaderEffectSource {
            id: paletteTextureSource
            sourceItem: paletteSourceItem
            hideSource: true
            visible: false // The source object itself doesn't need to be visible in the scene graph
            smooth: false
            recursive: false
        }


        Loader {
            id: videoRenderer
            anchors.fill: parent
            active: Files.type(wallpaper.effectiveWallpaper) === "video"
            sourceComponent: mpvpaperComponent
        }
    }

    component PictureSlot: Loader {
        id: slot
        anchors.fill: parent
        property string path: ""
        readonly property string kind: Files.type(path)
        property bool useFrame: false
        readonly property bool isFrame: kind === "video" || useFrame
        readonly property string framePath: wallpaper.getLockscreenFramePath(path)
        readonly property bool frameReady: (GlobalStates.wallpaperFrameRevisions[framePath] ?? 0) > 0
        readonly property bool ready: item?.status === Image.Ready
        readonly property bool failed: isFrame
            ? (item?.status === Image.Error || (wallpaper.manager?.failedFrames?.includes(path) ?? false))
            : kind === "image" && item?.status === Image.Error

        onPathChanged: useFrame = false
        active: path !== ""
        sourceComponent: isFrame || kind === "image" ? stillImage : animatedImage

        Component {
            id: stillImage
            Image {
                source: slot.isFrame ? (slot.frameReady ? wallpaper.getLockscreenFrameUrl(slot.path) : "") : "file://" + slot.path
                fillMode: wallpaper.wallpaperFillMode
                asynchronous: true
                retainWhileLoading: true
                mipmap: true
                smooth: true
                sourceSize.width: wallpaper.wallpaperMode === "center" ? 0 : wallpaper.width
                sourceSize.height: wallpaper.wallpaperMode === "center" ? 0 : wallpaper.height
            }
        }

        Component {
            id: animatedImage
            AnimatedImage {
                source: slot.path ? "file://" + slot.path : ""
                fillMode: wallpaper.wallpaperFillMode
                playing: slot.visible && frameCount > 1
                mipmap: true
                smooth: true
                onStatusChanged: {
                    if (status === Image.Error) {
                        const failedPath = slot.path;
                        Qt.callLater(() => {
                            if (slot.path === failedPath)
                                slot.useFrame = true;
                        });
                    }
                }
            }
        }
    }

    Component {
        id: mpvpaperComponent
        Item {
            id: player
            property string sourceFile: wallpaper.effectiveWallpaper
            property string scriptPath: decodeURIComponent(Qt.resolvedUrl("mpvpaper.sh").toString().replace("file://", ""))

            Timer {
                id: mpvpaperRestartTimer
                interval: 100
                onTriggered: {
                    if (sourceFile && (!wallpaper.tintEnabled || wallpaper.mpvShaderReady)) {
                        mpvpaperProcess.running = true;
                        probe.remaining = 30;
                        probe.restart();
                    }
                }
            }

            function restartPlayer(): void {
                wallpaper.videoPlaying = false;
                videoSocket.connected = false;
                probe.stop();
                mpvpaperProcess.running = false;
                mpvpaperRestartTimer.restart();
            }

            function setShader(path: string): void {
                if (videoSocket.connected) {
                    videoSocket.write(JSON.stringify({command: ["set_property", "glsl-shaders", path]}) + "\n");
                    videoSocket.flush();
                }
            }

            Timer {
                id: probe
                interval: 100
                repeat: true
                property int remaining: 0
                onTriggered: {
                    if (videoSocket.connected) {
                        videoSocket.write('{"command":["get_property","time-pos"],"request_id":1}\n');
                        videoSocket.flush();
                    } else {
                        videoSocket.connected = true;
                    }
                    if (--remaining === 0)
                        stop();
                }
            }

            Socket {
                id: videoSocket
                path: wallpaper.mpvSocket
                onConnectionStateChanged: if (!connected) wallpaper.videoPlaying = false
                parser: SplitParser {
                    onRead: line => {
                        try {
                            const reply = JSON.parse(line);
                            if (reply.request_id === 1 && reply.error === "success" && typeof reply.data === "number") {
                                wallpaper.videoPlaying = true;
                                probe.stop();
                                if (wallpaper.tintEnabled && wallpaper.mpvShaderReady)
                                    player.setShader(wallpaper.mpvShaderPath);
                            }
                        } catch (_) {
                            // Ignore lines that are not mpv replies.
                        }
                    }
                }
            }

            onSourceFileChanged: restartPlayer()
            Component.onCompleted: restartPlayer()

            Component.onDestruction: {
                wallpaper.videoPlaying = false;
                mpvpaperProcess.running = false;
            }

            Process {
                id: mpvpaperProcess
                running: false
                command: sourceFile && wallpaper.currentScreenName ? ["bash", scriptPath, sourceFile, (wallpaper.tintEnabled ? wallpaper.mpvShaderPath : ""), wallpaper.currentScreenName, wallpaper.wallpaperMode] : []

                stdout: StdioCollector {
                    onStreamFinished: {
                        if (text.length > 0) {
                            console.log("mpvpaper output:", text);
                        }
                    }
                }

                stderr: StdioCollector {
                    onStreamFinished: {
                        if (text.length > 0) {
                            console.warn("mpvpaper error:", text);
                        }
                    }
                }

                onExited: function (exitCode) {
                    wallpaper.videoPlaying = false;
                    probe.stop();
                    console.log("mpvpaper process exited with code:", exitCode);
                }
            }

            Connections {
                target: wallpaper
                function onWallpaperModeChanged(): void { player.restartPlayer(); }
                function onMpvShaderReadyChanged(): void {
                    if (wallpaper.mpvShaderReady && !mpvpaperProcess.running)
                        mpvpaperRestartTimer.restart();
                }
                function onTintEnabledChanged(): void {
                    if (!wallpaper.tintEnabled && !mpvpaperProcess.running)
                        mpvpaperRestartTimer.restart();
                }
            }
        }
    }
}
