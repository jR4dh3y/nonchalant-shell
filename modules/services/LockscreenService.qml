pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

// Session locking is handled entirely by Quickshell's native ext_session_lock
// implementation (niri). The UI uses a one-frame in-memory ScreencopyView for
// the desktop reveal; do not invoke external screenshot or compositor tools.
Singleton {
    id: root

    function toggle() {
        // A lock action must never become an unauthenticated unlock action.
        if (!GlobalStates.lockscreenVisible)
            lock();
    }

    function lock() {
        if (GlobalStates.lockscreenVisible || root.prepActive)
            return;
        GlobalStates.lockscreenUnlocking = false;
        GlobalStates.lockscreenHandoff = false;
        // Pre-capture each screen's desktop BEFORE requesting the lock so the
        // lock surface's first frame matches the on-screen content (windows
        // included) instead of flashing the clean wallpaper. Falls back to
        // engaging immediately if no screen can capture.
        const pending = GlobalStates.beginLockshotPrep();
        if (pending > 0) {
            root.prepActive = true;
            prepTimeoutTimer.restart();
        } else {
            engage();
        }
    }

    function engage() {
        GlobalStates.lockscreenVisible = true;
    }

    // Engages the lock once every screen has a lockshot (or gave up).
    property bool prepActive: false

    Connections {
        target: GlobalStates

        function onLockshotPendingChanged() {
            if (!root.prepActive)
                return;
            if (GlobalStates.lockshotPending > 0)
                return;
            root.prepActive = false;
            prepTimeoutTimer.stop();
            root.engage();
        }
    }

    Timer {
        id: prepTimeoutTimer
        interval: 400
        onTriggered: {
            if (!root.prepActive)
                return;
            root.prepActive = false;
            root.engage();
        }
    }

    // Called only by LockScreen after PAM succeeds. Keeping this separate from
    // the IPC commands prevents `nonchalant lock` from bypassing authentication.
    function finishUnlock() {
        if (!GlobalStates.lockscreenVisible || !GlobalStates.lockscreenUnlocking)
            return;
        GlobalStates.lockscreenVisible = false;
        GlobalStates.lockscreenUnlocking = false;
        GlobalStates.lockscreenHandoff = false;
        cleanupLockshotsProcess.running = true;
    }

    Process {
        id: cleanupLockshotsProcess
        command: ["sh", "-c", 'rm -f "${XDG_RUNTIME_DIR:-/tmp}"/nonchalant-lockshot-*.png']
    }


    IpcHandler {
        target: "lockscreen"

        function toggle() {
            root.toggle();
        }

        function lock() {
            root.lock();
        }

    }
}


