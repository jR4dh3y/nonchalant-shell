import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
import qs.modules.theme
import "WallpaperFiles.js" as Files

Scope {
    id: root

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/nonchalant"
    readonly property string fallbackDir: Quickshell.env("HOME") + "/.local/share/wallpapers"
    readonly property string presetDir: Quickshell.env("HOME") + "/.config/nonchalant/colors"
    readonly property string officialPresetDir: decodeURIComponent(Qt.resolvedUrl("../../../../assets/colors").toString().replace(/^file:\/\//, ""))
    readonly property string wallpaperDir: state.wallPath || fallbackDir
    readonly property string scannedDir: wallpaperPaths.length && !wallpaperPaths[0].startsWith(wallpaperDir.replace(/\/+$/, "") + "/")
        ? fallbackDir : wallpaperDir
    readonly property string currentWallpaper: displayedWallpaper
    readonly property string globalCandidate: requestedGlobalWallpaper
        || (wallpaperPaths.includes(state.currentWall) ? state.currentWall : wallpaperPaths[0] ?? "")
    readonly property string currentMatugenScheme: state.matugenScheme || "scheme-wallpaper"
    readonly property string activeColorPreset: state.activeColorPreset
    readonly property string wallpaperMode: ["crop", "fit", "stretch", "center"].includes(state.wallpaperMode) ? state.wallpaperMode : "crop"
    readonly property bool tintEnabled: state.tintEnabled
    readonly property var perScreenWallpapers: state.perScreenWallpapers || {}
    readonly property string colorMode: Config.theme.lightMode ? "light" : "dark"
    readonly property string presetPaletteKey: activeColorPreset && globalColors.ready ? globalColors.request : ""
    readonly property string globalPalettePath: globalColors.destination
    property string displayedWallpaper: ""
    property string requestedGlobalWallpaper: ""
    property var requestedOverrides: ({})
    property list<Wallpaper> wallpaperOutputs: []
    readonly property list<Wallpaper> globalOutputs: wallpaperOutputs.filter(output => !output.hasLocalWallpaper)
    readonly property bool globalImageReady: globalOutputs.length
        ? globalOutputs.every(output => output.candidateWallpaper === globalCandidate && output.candidateImageReady)
        : validationImage.status === Image.Ready
    readonly property bool globalImageFailed: globalOutputs.length
        ? globalOutputs.some(output => output.candidateWallpaper === globalCandidate && output.candidateImageFailed)
        : validationImage.status === Image.Error || failedFrames.includes(globalCandidate)

    property list<string> wallpaperPaths: []
    property list<string> subfolders: []
    property list<string> colorPresets: []
    property int thumbnailsVersion: 0
    property bool configReady: false
    property list<string> pendingFrames: []
    property list<string> failedFrames: []

    onWallpaperDirChanged: scanSubfolders()
    onGlobalCandidateChanged: {
        queueFrame(globalCandidate);
        Qt.callLater(syncGlobalWallpaper);
    }
    onGlobalImageReadyChanged: Qt.callLater(syncGlobalWallpaper)
    onGlobalImageFailedChanged: Qt.callLater(syncGlobalWallpaper)
    Connections {
        target: Colors
        function onLoaded() {
            Qt.callLater(root.syncGlobalWallpaper);
        }
    }

    function syncGlobalWallpaper(): void {
        const path = globalCandidate;
        if (!path)
            return;
        if (globalImageFailed) {
            if (requestedGlobalWallpaper === path)
                requestedGlobalWallpaper = "";
            return;
        }
        if (!globalImageReady)
            return;
        if (globalColors.failed) {
            if (activeColorPreset)
                return;
            commitGlobalWallpaper(path);
            return;
        }
        if (!globalColors.ready)
            return;
        const result = JSON.parse(globalColors.resultText);
        // Compare the loaded colors before the OLED overrides.
        if (Object.keys(result).every(role => Colors.adapter[role]?.toString() === result[role].toLowerCase()))
            commitGlobalWallpaper(path);
    }

    // The global selection still serves app exports when every output has an
    // override. In that case there is no wallpaper window to validate it.
    Image {
        id: validationImage
        visible: false
        asynchronous: true
        sourceSize: Qt.size(1, 1)
        source: {
            if (root.globalOutputs.length || !root.globalCandidate)
                return "";
            const path = root.globalCandidate;
            if (!Files.needsFrame(path))
                return Files.frameUrl(path, root.cacheDir, GlobalStates.wallpaperFrameRevisions);
            const frame = Files.framePath(path, root.cacheDir);
            return GlobalStates.wallpaperFrameRevisions[frame] ? root.getLockscreenFrameUrl(path) : "";
        }
    }

    function commitGlobalWallpaper(path: string): void {
        displayedWallpaper = path;
        state.currentWall = path;
        if (requestedGlobalWallpaper === path)
            requestedGlobalWallpaper = "";
    }

    function finishOverride(output: string, path: string, applied: bool): void {
        const pending = Object.prototype.hasOwnProperty.call(requestedOverrides, output);
        if (pending && requestedOverrides[output] !== path)
            return;
        // A saved override can become unreadable while the shell is stopped.
        const brokenSavedOverride = !pending && !applied && perScreenWallpapers[output] === path;
        if (brokenSavedOverride || (pending && applied)) {
            const saved = Object.assign({}, perScreenWallpapers);
            if (applied && path)
                saved[output] = path;
            else
                delete saved[output];
            state.perScreenWallpapers = saved;
        }
        if (pending) {
            const remaining = Object.assign({}, requestedOverrides);
            delete remaining[output];
            requestedOverrides = remaining;
        }
    }

    function getThumbnailPath(path: string): string {
        const base = scannedDir.endsWith("/") ? scannedDir : scannedDir + "/";
        const relative = path.startsWith(base) ? path.slice(base.length) : path.split("/").pop();
        return cacheDir + "/thumbnails/" + relative + ".jpg";
    }

    function getLockscreenFrameUrl(path: string): string {
        return Files.frameUrl(path, cacheDir, GlobalStates.wallpaperFrameRevisions);
    }

    function setWallpaper(path: string, targetScreen: string): void {
        if (!wallpaperPaths.includes(path))
            return;
        queueFrame(path);
        if (targetScreen) {
            requestedOverrides = Object.assign({}, requestedOverrides, { [targetScreen]: path });
        } else {
            requestedGlobalWallpaper = path;
        }
    }

    function clearPerScreenWallpaper(targetScreen: string): void {
        requestedOverrides = Object.assign({}, requestedOverrides, { [targetScreen]: "" });
    }

    function setWallpaperMode(mode: string): void {
        if (["crop", "fit", "stretch", "center"].includes(mode))
            state.wallpaperMode = mode;
    }

    function setWallpaperDir(path: string): void {
        state.wallPath = path;
    }

    function stepWallpaper(direction: int): void {
        const count = wallpaperPaths.length;
        if (count)
            setWallpaper(wallpaperPaths[(wallpaperPaths.indexOf(globalCandidate) + direction + count) % count], "");
    }

    function setColorPreset(name: string): void {
        state.activeColorPreset = name;
    }

    function setMatugenScheme(scheme: string): void {
        state.matugenScheme = scheme;
        state.activeColorPreset = "";
        globalColors.refresh();
    }

    function scanSubfolders(): void {
        if (configReady)
            rescan.restart();
    }

    function queueFrame(path: string): void {
        if (Files.needsFrame(path) && !pendingFrames.includes(path)
            && !(frameGenerator.running && frameGenerator.command[2] === path)) {
            failedFrames = failedFrames.filter(failedPath => failedPath !== path);
            pendingFrames = [...pendingFrames, path];
            Qt.callLater(startNextFrame);
        }
    }

    function startNextFrame(): void {
        if (frameGenerator.running || !pendingFrames.length)
            return;
        const path = pendingFrames[0];
        pendingFrames = pendingFrames.slice(1);
        frameGenerator.command = ["python3", Files.localPath(Qt.resolvedUrl("../../../../scripts/lockwall.py")), path, cacheDir];
        frameGenerator.running = true;
    }

    Component.onCompleted: GlobalStates.wallpaperManager = root

    FileView {
        id: wallpaperConfig
        path: root.cacheDir + "/wallpapers.json"
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.configReady = true;
            root.scanSubfolders();
            presetScanner.running = true;
        }
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                return;
            root.configReady = true;
            state.wallPath = root.fallbackDir;
            root.scanSubfolders();
            presetScanner.running = true;
        }
        onAdapterUpdated: if (root.configReady) writeAdapter()

        adapter: JsonAdapter {
            id: state
            property string currentWall: ""
            property string wallPath: ""
            property string matugenScheme: "scheme-wallpaper"
            property string activeColorPreset: ""
            property bool tintEnabled: false
            property string wallpaperMode: "crop"
            property var perScreenWallpapers: ({})
        }
    }

    WallpaperColorJob {
        id: globalColors
        destination: root.cacheDir + "/colors.json"
        image: root.activeColorPreset ? "" : root.globalCandidate
        canPublish: root.activeColorPreset !== "" || root.globalImageReady
        scheme: root.currentMatugenScheme
        mode: root.colorMode
        presetFile: root.activeColorPreset ? root.officialPresetDir + "/" + root.activeColorPreset + "/" + mode + ".json" : ""
        fallbackPresetFile: root.activeColorPreset ? root.presetDir + "/" + root.activeColorPreset + "/" + mode + ".json" : ""
        onResultTextChanged: if (resultText) Qt.callLater(root.syncGlobalWallpaper)
        onFailedChanged: if (failed) Qt.callLater(root.syncGlobalWallpaper)
    }

    Timer {
        id: rescan
        interval: 90
        onTriggered: {
            if (scanner.running) {
                restart();
            } else if (root.configReady) {
                scanner.startedDir = root.wallpaperDir;
                scanner.command = ["bash", Files.localPath(Qt.resolvedUrl("../../../../scripts/list_wallpapers.sh")),
                    root.wallpaperDir, root.fallbackDir];
                scanner.running = true;
            }
        }
    }

    Process {
        id: scanner
        property string startedDir: ""
        stdout: StdioCollector { id: found }
        onExited: code => {
            if (startedDir !== root.wallpaperDir) {
                rescan.restart();
                return;
            }
            if (code !== 0)
                return;
            const entries = found.text.split("\0").filter(path => path !== "");
            root.wallpaperPaths = entries.filter(path => Files.type(path) !== "").sort();
            root.subfolders = entries.filter(path => path.endsWith("/"));
            thumbnailDelay.restart();
        }
    }

    Instantiator {
        model: [...new Set([root.wallpaperDir, root.fallbackDir, ...root.subfolders])]
        delegate: FileView {
            required property string modelData
            path: modelData
            watchChanges: true
            printErrors: false
            onFileChanged: root.scanSubfolders()
        }
    }

    Instantiator {
        model: [root.officialPresetDir, root.presetDir]
        delegate: FileView {
            required property string modelData
            path: modelData
            watchChanges: true
            printErrors: false
            onFileChanged: presetScanner.running = true
        }
    }

    Process {
        id: presetScanner
        command: ["find", root.officialPresetDir, root.presetDir, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-printf", "%f\\0"]
        stdout: StdioCollector {
            onStreamFinished: root.colorPresets = [...new Set(text.split("\0").filter(name => name !== ""))].sort()
        }
    }

    Timer {
        id: thumbnailDelay
        interval: 2000
        onTriggered: thumbnailGenerator.running = true
    }

    Process {
        id: thumbnailGenerator
        command: ["python3", Files.localPath(Qt.resolvedUrl("../../../../scripts/thumbgen.py")), wallpaperConfig.path, root.cacheDir, root.fallbackDir]
        onExited: code => { if (code === 0) root.thumbnailsVersion++; }
    }

    Process {
        id: frameGenerator
        onExited: code => {
            if (code === 0)
                GlobalStates.bumpWallpaperFrameRevision(Files.framePath(command[2], root.cacheDir));
            else
                root.failedFrames = [...root.failedFrames, command[2]];
            Qt.callLater(root.startNextFrame);
        }
    }
}
