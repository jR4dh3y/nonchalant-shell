pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals

// Session locking is handled entirely by Quickshell's native ext_session_lock
// implementation (niri). Lock/unlock fades run on LockCurtain, an overlay layer
// composited over the live desktop; no screenshots are taken.
Singleton {
    id: root

    readonly property int curtainFadeMs: Config.animDuration > 0 ? Math.round(Config.animDuration * 1.2) : 0

    function toggle() {
        // A lock action must never become an unauthenticated unlock action.
        if (!GlobalStates.lockscreenVisible)
            lock();
    }

    // Fade the curtain in over the desktop, then engage the real lock. Its
    // first frame matches the opaque curtain, so the handoff is invisible.
    function lock() {
        if (GlobalStates.lockscreenVisible || GlobalStates.lockCurtainShown)
            return;
        GlobalStates.lockscreenUnlocking = false;
        GlobalStates.lockCurtainShown = true;
        if (root.curtainFadeMs > 0)
            engageTimer.restart();
        else
            engage();
    }

    function engage() {
        GlobalStates.lockscreenVisible = true;
        secureWatchdog.restart();
    }

    Timer {
        id: engageTimer
        interval: root.curtainFadeMs + 50
        onTriggered: root.engage()
    }

    // If niri never confirms the lock, drop the curtain instead of leaving an
    // opaque, input-eating surface that looks locked but has no way to unlock.
    Timer {
        id: secureWatchdog
        interval: 3000
        onTriggered: {
            if (!GlobalStates.lockscreenVisible || GlobalStates.lockscreenSecure)
                return;
            console.warn("LockscreenService: session lock was not confirmed; dropping the lock curtain");
            GlobalStates.lockscreenVisible = false;
            GlobalStates.lockCurtainShown = false;
        }
    }

    // Called only by LockScreen after PAM succeeds. Keeping this separate from
    // the IPC commands prevents `nonchalant lock` from bypassing authentication.
    // Releasing the lock reveals the still-opaque curtain over the live
    // desktop; lowering it fades the desktop in.
    function finishUnlock() {
        if (!GlobalStates.lockscreenVisible || !GlobalStates.lockscreenUnlocking)
            return;
        secureWatchdog.stop();
        GlobalStates.lockscreenVisible = false;
        GlobalStates.lockscreenUnlocking = false;
        GlobalStates.lockCurtainShown = false;
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
