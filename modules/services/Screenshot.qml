pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

QtObject {
    id: root

    signal screenshotCaptured(string path) // Generic signal (maybe unused now for per-monitor)
    signal monitorScreenshotReady(string monitorName, string path) // NEW: Signal for per-monitor readiness
    signal errorOccurred(string message)
    signal windowListReady(var windows)
    signal monitorsListReady(var monitors)
    signal lensImageReady(string path)
    signal imageSaved(string path) // New signal for Overlay

    property string tempPathBase: "/tmp/nonchalant_freeze"
    property string cropPath: "/tmp/nonchalant_crop.png"
    property string lensPath: "/tmp/image.png"
    
    property string captureMode: "normal"
    
    property string screenshotsDir: ""
    property string finalPath: ""
    
    property var _activeWorkspaceIds: []
    property var monitors: [] // List of monitor objects
    
    // Selection state to synchronize UI across monitors
    property int selectionX: 0
    property int selectionY: 0
    property int selectionW: 0
    property int selectionH: 0
    
    // Store monitor scale factor for coordinate scaling
    property real monitorScale: 1.0

    property bool _initialized: false

    function initialize() {
        if (_initialized) return;
        _initialized = true;
        xdgProcess.running = true;
    }

    // Process to resolve XDG_PICTURES_DIR
    property Process xdgProcess: Process {
        id: xdgProcess
        command: ["bash", "-c", "xdg-user-dir PICTURES"]
        stdout: StdioCollector {
             onTextChanged: {
                // Not running immediately, handled in onExited
             }
        }
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                var dir = xdgProcess.stdout.text.trim()
                if (dir === "") {
                    dir = Quickshell.env("HOME") + "/Pictures"
                }
                root.screenshotsDir = dir + "/Screenshots"
                ensureDirProcess.running = true
            }
        }
    }

    property Process ensureDirProcess: Process {
        id: ensureDirProcess
        command: ["mkdir", "-p", root.screenshotsDir]
    }

    // Freeze captures via niri's built-in screenshot-screen (per focused output).
    property Process freezeProcess: Process {
        id: freezeProcess
        // Command built dynamically
        command: [] 
        onExited: exitCode => {
            root._freezing = false; // Reset lock flag
            if (exitCode === 0) {
                // Notify all monitors that their screenshot is ready
                // We assume if the batch command finished, all are done.
                for (var i = 0; i < root.monitors.length; i++) {
                    var m = root.monitors[i];
                    var path = root.tempPathBase + "_" + m.name + ".png";
                    root.monitorScreenshotReady(m.name, path);
                }
                // Also emit generic for compatibility?
                root.screenshotCaptured(root.tempPathBase + "_ALL.png") // Dummy path?
            } else {
                root.errorOccurred("Failed to capture screen (niri)")
                root._freezing = false;
            }
        }
    }
    
    // Process for cropping/saving
    property Process cropProcess: Process {
        id: cropProcess
        // command set dynamically
        onExited: exitCode => {
            if (exitCode === 0) {
                if (root.captureMode === "lens") {
                    root.runLensScript()
                    root.captureMode = "normal" 
                } else {
                    copyProcess.running = true
                    root.imageSaved(root.finalPath)
                }
            } else {
                root.errorOccurred("Failed to save image")
            }
        }
    }

    property Process copyProcess: Process {
        id: copyProcess
        command: ["bash", "-c", `cat "${root.finalPath}" | wl-copy --type image/png`]
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) console.warn("Screenshot Copy Error: " + text)
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("Failed to copy to clipboard (Exit code: " + exitCode + ")")
            }
        }
    }

    property Process lensProcess: Process {
        id: lensProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Screenshot: Google Lens script executed successfully")
            } else {
                root.errorOccurred("Failed to open Google Lens: " + lensProcess.stderr.text)
            }
        }
    }

    // Prevent double execution
    property bool _freezing: false

    function freezeScreen() {
        if (_freezing) return;
        _freezing = true;

        // FAST PATH: Use Quickshell.screens to start freeze immediately
        // Map Quickshell screens to the format expected (physical dimensions)
        var qsScreens = Quickshell.screens;
        var mappedMonitors = [];
        for (var i = 0; i < qsScreens.length; i++) {
             var s = qsScreens[i];
             mappedMonitors.push({
                 id: i, // Dummy ID
                 name: s.name,
                 x: s.x,
                 y: s.y,
                 width: s.width * s.scale, // approx physical width
                 height: s.height * s.scale, // approx physical height
                 scale: s.scale
             });
        }
        root.monitors = mappedMonitors;
        
        // Trigger freeze immediately
        root.executeFreezeBatch();

        root.fetchWindows();
    }
    
    function fetchWindows() {
        const niriMonitors = NiriService.monitors.values || [];
        root.monitors = niriMonitors.map(monitor => ({
            id: monitor.id,
            name: monitor.name,
            width: monitor.width,
            height: monitor.height,
            scale: monitor.scale,
            refresh_rate: monitor.refreshRate,
            focused: monitor.focused,
            x: monitor.x,
            y: monitor.y,
            activeWorkspace: monitor.activeWorkspace
        }));

        root._activeWorkspaceIds = root.monitors
            .filter(monitor => monitor.activeWorkspace)
            .map(monitor => monitor.activeWorkspace.id);

        const clients = (NiriService.clients.values || []).filter(client =>
            root._activeWorkspaceIds.includes(client.workspace.id)
        ).map(client => ({
            id: client.id,
            app_id: client.appId,
            title: client.title,
            is_floating: client.floating,
            is_focused: client.is_focused,
            is_fullscreen: client.fullscreen,
            is_hidden: client.hidden,
            workspace_id: client.workspace.id,
            pinned: false,
            workspace: client.workspace,
            at: client.at,
            size: client.size
        }));

        root.monitorsListReady(root.monitors);
        root.windowListReady(clients);
    }
    
    function executeFreezeBatch() {
        if (root.monitors.length === 0) {
            console.warn("Screenshot: No monitors found to freeze");
            _freezing = false;
            return;
        }

        // niri can only screenshot the focused output. Walk outputs, request
        // screenshot-screen with an absolute --path, then wait for async writes.
        var cmd = "set -e; ";
        cmd += 'FOCUSED=$(niri msg --json focused-output 2>/dev/null | jq -r ".name // empty" 2>/dev/null || true); ';
        var paths = [];
        for (var i = 0; i < root.monitors.length; i++) {
            var m = root.monitors[i];
            var path = root.tempPathBase + "_" + m.name + ".png";
            paths.push(path);
            cmd += `rm -f "${path}"; `;
            cmd += `niri msg action focus-monitor "${m.name}"; `;
            cmd += `niri msg action screenshot-screen --path "${path}" --show-pointer false; `;
        }
        for (var j = 0; j < paths.length; j++) {
            var waitPath = paths[j];
            cmd += `ready=0; for _ in $(seq 1 100); do if [ -s "${waitPath}" ]; then ready=1; break; fi; sleep 0.02; done; `;
            cmd += `[ "$ready" = 1 ] || { echo "Screenshot: freeze missing ${waitPath}" >&2; exit 1; }; `;
        }
        cmd += 'if [ -n "$FOCUSED" ]; then niri msg action focus-monitor "$FOCUSED" || true; fi';

        console.log("Screenshot: Executing freeze batch via niri");
        freezeProcess.command = ["bash", "-c", cmd];
        freezeProcess.running = true;
    }

    function getTimestamp() {
        var d = new Date()
        var pad = (n) => n < 10 ? '0' + n : n;
        return d.getFullYear() + '-' + 
               pad(d.getMonth() + 1) + '-' + 
               pad(d.getDate()) + '-' + 
               pad(d.getHours()) + '-' + 
               pad(d.getMinutes()) + '-' + 
               pad(d.getSeconds());
    }

    // Modified processRegion to handle per-monitor cropping
    // It finds the monitor for the given coords, loads THAT monitor's freeze file, and crops.
    function processRegion(x, y, w, h) {
        if (root.captureMode === "lens") {
            root.finalPath = root.lensPath;
        } else {
            if (root.screenshotsDir === "") {
                root.screenshotsDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
            }
            var filename = "Screenshot_" + getTimestamp() + ".png"
            root.finalPath = root.screenshotsDir + "/" + filename
        }
        
        // Find monitor for these global logical coordinates
        var m = null;
        if (root.monitors.length > 0) {
            // Check which monitor contains the center of the region?
            // Or the top-left? Top-left is safer.
            // Note: monitor.x and monitor.y are logical position
            // monitor.width is PHYSICAL width. logical width = width / scale
            m = root.monitors.find(mon => {
                var logicalW = mon.width / mon.scale;
                var logicalH = mon.height / mon.scale;

				// When monitors are rotated, we use the height for width and vice versa
				// 1 = 90 deg, 3 = 270 deg, 5 = 90 deg mirrored, 7 = 270 deg mirrored
				// source: https://wiki.hypr.land/Configuring/Monitors/#rotating
				// this way we select the correct monitor
				if(mon.transform === 1 || mon.transform === 3 || mon.transform === 5 || mon.transform === 7) {
					var logicalW  = mon.height / mon.scale;
					var logicalH  = mon.width / mon.scale;
				}

                return x >= mon.x && x < (mon.x + logicalW) &&
                       y >= mon.y && y < (mon.y + logicalH);
            });
        }
        
        if (!m) {
            console.warn("Screenshot: Could not find monitor for region " + x + "," + y);
            // Fallback? Try to use first monitor?
            if (root.monitors.length > 0) m = root.monitors[0];
            else return; 
        }
        
        // Calculate coordinates relative to that monitor
        var localX = x - m.x;
        var localY = y - m.y;
        
        // Convert to physical coordinates for cropping the PHYSICAL freeze for THIS monitor.
        // niri screenshot-screen output for a single monitor is size WxH (physical).
        var physX = Math.round(localX * m.scale);
        var physY = Math.round(localY * m.scale);
        var physW = Math.round(w * m.scale);
        var physH = Math.round(h * m.scale);
        
        console.log(`Screenshot: Cropping on monitor ${m.name} (Scale ${m.scale})`);
        console.log(`Screenshot: Logical Local: ${localX},${localY} ${w}x${h} -> Physical: ${physX},${physY} ${physW}x${physH}`);
        
        var srcPath = root.tempPathBase + "_" + m.name + ".png";
        
        // convert input.png -crop WxH+X+Y output.png
        var geom = `${physW}x${physH}+${physX}+${physY}`;
        cropProcess.command = ["convert", srcPath, "-crop", geom, root.finalPath];
        cropProcess.running = true;
    }

    function processFullscreen() {
        if (root.captureMode === "lens") {
            root.finalPath = root.lensPath;
        } else {
            if (root.screenshotsDir === "") {
                root.screenshotsDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
            }
            var filename = "Screenshot_" + getTimestamp() + ".png"
            root.finalPath = root.screenshotsDir + "/" + filename
        }

        // Fullscreen capture usually means "All Screens" or "Current Screen"?
        // The previous implementation was "All Screens".
        // But users usually want "Current Screen" if they click on a screen.
        // However, if we want ALL screens stitched, we'd need to stitch them ourselves now.
        // Let's assume the user clicked on a specific screen, so we capture THAT screen.
        // We need to know WHICH screen was clicked. 
        // But processFullscreen() takes no arguments currently.
        // We should modify it to take a monitor name or coords.
        
        // For now, let's implement "Capture Monitor under Mouse" if possible?
        // Or if we can't easily, maybe we just stitch them all?
        // Stitching is complex. 
        
        // Let's try to infer from mouse position? We don't have it here.
        // Let's assume the focused monitor?
        // Let's default to primary or first monitor for safety if no context provided.
        // Ideally, we update ScreenshotTool to pass the screen name.
        
        // Capture the currently focused output via niri into the final path.
        var path = root.finalPath;
        var cmd = `rm -f "${path}"; niri msg action screenshot-screen --path "${path}" --show-pointer false; ` +
                  `ready=0; for _ in $(seq 1 100); do if [ -s "${path}" ]; then ready=1; break; fi; sleep 0.02; done; ` +
                  `[ "$ready" = 1 ]`;
        cropProcess.command = ["bash", "-c", cmd];
        cropProcess.running = true;
    }
    
    // Overloaded processFullscreen to take a screen name (for "Screen" mode on specific monitor)
    function processMonitorScreen(monitorName) {
         if (root.captureMode === "lens") {
            root.finalPath = root.lensPath;
        } else {
            if (root.screenshotsDir === "") {
                root.screenshotsDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
            }
            var filename = "Screenshot_" + getTimestamp() + ".png"
            root.finalPath = root.screenshotsDir + "/" + filename
        }
        
        var srcPath = root.tempPathBase + "_" + monitorName + ".png";
        cropProcess.command = ["cp", srcPath, root.finalPath];
        cropProcess.running = true;
    }

    property Process openScreenshotsProcess: Process {
        id: openScreenshotsProcess
        command: ["xdg-open", root.screenshotsDir]
    }

    function openScreenshotsFolder() {
        if (root.screenshotsDir === "") {
             openScreenshotsProcess.command = ["xdg-open", Quickshell.env("HOME") + "/Pictures/Screenshots"];
        } else {
             openScreenshotsProcess.command = ["xdg-open", root.screenshotsDir];
        }
        openScreenshotsProcess.running = true;
    }

    function runLensScript() {
        var scriptPath = Qt.resolvedUrl("../../scripts/google_lens.sh").toString().replace("file://", "");
        verifyImageProcess.command = ["test", "-f", root.lensPath];
        verifyImageProcess.running = true;
    }
    
    property Process verifyImageProcess: Process {
        id: verifyImageProcess
        onExited: exitCode => {
            if (exitCode === 0) {
                var scriptPath = Qt.resolvedUrl("../../scripts/google_lens.sh").toString().replace("file://", "");
                lensProcess.command = ["bash", scriptPath];
                lensProcess.running = true;
            } else {
                root.errorOccurred("Image file not ready for Google Lens")
            }
        }
    }
}
