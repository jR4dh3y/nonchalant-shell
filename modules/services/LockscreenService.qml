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
        if (GlobalStates.lockscreenVisible)
            return;
        GlobalStates.lockscreenUnlocking = false;
        GlobalStates.lockscreenHandoff = false;
        GlobalStates.lockscreenVisible = true;
    }

    // Called only by LockScreen after PAM succeeds. Keeping this separate from
    // the IPC commands prevents `nonchalant lock` from bypassing authentication.
    function finishUnlock() {
        if (!GlobalStates.lockscreenVisible || !GlobalStates.lockscreenUnlocking)
            return;
        GlobalStates.lockscreenVisible = false;
        GlobalStates.lockscreenUnlocking = false;
        GlobalStates.lockscreenHandoff = false;
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
