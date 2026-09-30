import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.globals

// Pre-lock desktop capture ("lockshot") for one screen. Captures the actual
// desktop (windows included) BEFORE the lock request reaches niri, so the lock
// surface's first frame is identical to what the user was seeing.
//
// Host this in a window niri keeps presenting (the overlay shell panel), never
// the background wallpaper: grabToImage() waits for the host window's next
// frame, and niri withholds frame callbacks from an occluded background layer.
// With a maximized browser on top, that wait blew past the prep timeout and
// the lock engaged on the plain scrim (a gray frame) instead of the desktop.
//
// A fresh ScreencopyView is created per lock and destroyed after the grab.
// ScreencopyView exposes no per-frame signal and hasContent only flips once,
// so a reused view cannot tell a new frame from the previous one: grabbing it
// showed a stale desktop (e.g. another workspace).
Item {
    id: root

    required property ShellScreen screen
    readonly property string screenName: screen ? screen.name : ""

    Component.onCompleted: GlobalStates.registerLockPrep(root.screenName, root.prepare)
    Component.onDestruction: GlobalStates.unregisterLockPrep(root.screenName)

    // Called by LockscreenService via the GlobalStates registry. Returns true
    // if a capture was started for this screen.
    function prepare(): bool {
        if (!root.screen)
            return false;
        loader.active = false;
        loader.active = true;
        return true;
    }

    function grab() {
        const view = loader.item;
        if (!view) {
            GlobalStates.notifyLockshotPrepared(root.screenName, null);
            return;
        }
        // The grab stays in memory; the lock surface shows it straight from its
        // itemgrabber URL (no PNG encode/decode on the UI thread).
        view.grabToImage(function (result) {
            if (!result)
                console.warn("Lockshot grab failed for screen", root.screenName);
            GlobalStates.notifyLockshotPrepared(root.screenName, result ?? null);
            // The grab result owns its own image; drop the capture view.
            loader.active = false;
        });
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: false

        sourceComponent: ScreencopyView {
            captureSource: root.screen
            live: false
            paintCursor: false

            Component.onCompleted: captureFrame()

            onHasContentChanged: {
                if (hasContent)
                    grabDelay.restart();
            }
        }
    }

    // Small delay so the freshly captured buffer is painted into the item
    // texture before the grab pass runs.
    Timer {
        id: grabDelay
        interval: 32
        onTriggered: root.grab()
    }
}
