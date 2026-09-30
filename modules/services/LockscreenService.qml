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

    // Lock-path timing. Each step logs its offset from the lock request, and
    // UI-thread stalls are reported while the lock settles, so a slow lock
    // shows where the time went. Nothing sensitive is logged.
    property double traceStart: 0

    function trace(step: string) {
        if (root.traceStart > 0)
            console.info(`Lock: ${step} +${Date.now() - root.traceStart}ms`);
    }

    Timer {
        id: stallProbe
        interval: 50
        repeat: true
        property double last: 0
        property int ticks: 0
        onTriggered: {
            const now = Date.now();
            if (last > 0 && now - last > 150)
                root.trace(`UI thread stalled ${now - last}ms`);
            last = now;
            // Watch the first ~6s; the lock has settled by then.
            if (++ticks > 120)
                stop();
        }
    }

    Connections {
        target: GlobalStates

        function onLockscreenSecureChanged() {
            root.trace(GlobalStates.lockscreenSecure ? "niri confirmed lock" : "lock released");
        }
    }

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
        root.traceStart = Date.now();
        stallProbe.last = 0;
        stallProbe.ticks = 0;
        stallProbe.restart();
        root.trace("requested");
        GlobalStates.lockCurtainShown = true;
        if (root.curtainFadeMs > 0)
            engageTimer.restart();
        else
            engage();
    }

    function engage() {
        root.trace("engaging session lock");
        GlobalStates.lockscreenVisible = true;
        secureWatchdog.restart();
    }

    Timer {
        id: engageTimer
        interval: root.curtainFadeMs + 50
        onTriggered: root.engage()
    }

    // If niri has not confirmed the lock after a while, lower the curtain so it
    // cannot become an opaque, input-eating surface with no way out. Never
    // release the lock request here: a slow confirmation is still a lock, and
    // releasing it would unlock the session without authentication.
    Timer {
        id: secureWatchdog
        interval: 5000
        onTriggered: {
            if (!GlobalStates.lockscreenVisible || GlobalStates.lockscreenSecure)
                return;
            console.warn("LockscreenService: niri has not confirmed the lock; lowering the curtain");
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
        root.trace("unlocking");
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
