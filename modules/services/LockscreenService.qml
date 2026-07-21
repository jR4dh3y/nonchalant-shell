pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

Singleton {
    id: root

    readonly property string freezePathBase: "/tmp/nonchalant_lock_freeze"
    // Bumped on every successful freeze so Image sources bust cache.
    property int freezeGeneration: 0
    property bool capturing: false
    property bool pendingLock: false

    function freezePathFor(screenName) {
        if (!screenName)
            return "";
        // Output names can contain spaces; keep a stable filesystem-safe key.
        const safe = String(screenName).replace(/[^A-Za-z0-9._-]/g, "_");
        return freezePathBase + "_" + safe + ".png";
    }

    function freezeSourceFor(screenName) {
        const path = freezePathFor(screenName);
        if (!path)
            return "";
        return "file://" + path + "?g=" + freezeGeneration;
    }

    function toggle() {
        if (GlobalStates.lockscreenVisible || capturing) {
            if (GlobalStates.lockscreenUnlocking || capturing)
                return;
            unlock();
        } else {
            lock();
        }
    }

    function lock() {
        if (GlobalStates.lockscreenVisible || capturing)
            return;

        GlobalStates.lockscreenUnlocking = false;
        GlobalStates.lockscreenHandoff = false;
        GlobalStates.lockscreenHandoffOpacity = 1;

        // Capture the live desktop BEFORE the session lock is raised.
        // Capturing after lock only sees lock surfaces (often black).
        capturing = true;
        pendingLock = true;
        captureFreeze();
    }

    function unlock() {
        GlobalStates.lockscreenVisible = false;
        GlobalStates.lockscreenUnlocking = false;
    }

    function captureFreeze() {
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0) {
            console.warn("LockscreenService: no screens to freeze, locking without freeze");
            finishCapture(false);
            return;
        }

        let cmd = "";
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            const path = freezePathFor(s.name);
            cmd += `grim -o "${s.name}" "${path}" & `;
        }
        cmd += "wait";

        freezeProcess.command = ["bash", "-c", cmd];
        freezeProcess.running = true;
    }

    function finishCapture(ok) {
        capturing = false;
        if (!pendingLock)
            return;
        pendingLock = false;

        if (ok)
            freezeGeneration += 1;
        else
            console.warn("LockscreenService: freeze capture failed; lock will fall back to wallpaper");

        GlobalStates.lockscreenVisible = true;
    }

    function beginUnlockHandoff() {
        // Arm the post-unlock overlay before tearing down the session lock so
        // the next frame after unlock still shows the freeze.
        GlobalStates.lockscreenHandoffOpacity = 1;
        GlobalStates.lockscreenHandoff = true;
        GlobalStates.lockscreenVisible = false;
        GlobalStates.lockscreenUnlocking = false;
        handoffFadeTimer.restart();
    }

    Process {
        id: freezeProcess
        command: []
        onExited: exitCode => {
            root.finishCapture(exitCode === 0);
        }
    }

    Timer {
        id: handoffFadeTimer
        // Hold the freeze for a couple of frames, then fade into the live session.
        interval: 80
        repeat: false
        onTriggered: {
            GlobalStates.lockscreenHandoffOpacity = 0;
            handoffClearTimer.restart();
        }
    }

    Timer {
        id: handoffClearTimer
        interval: 140
        repeat: false
        onTriggered: {
            GlobalStates.lockscreenHandoff = false;
            GlobalStates.lockscreenHandoffOpacity = 1;
        }
    }

    IpcHandler {
        target: "lockscreen"

        function toggle() {
            root.toggle();
        }

        function lock() {
            root.lock();
        }

        function unlock() {
            root.unlock();
        }
    }
}
