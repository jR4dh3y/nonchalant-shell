pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool enabled: false
    readonly property string track: MprisController.activePlayer
        ? MprisController.activePlayer.dbusName + ":" + MprisController.activePlayer.uniqueId : ""
    readonly property bool playing: MprisController.isPlaying
    readonly property real rate: MprisController.activePlayer?.rate ?? 1
    property int epoch: 0
    property real sampleAt: 0
    property real samplePosition: 0
    property real sampleRawPosition: 0
    property int requestEpoch: 0
    property string requestTrack: ""
    property real requestAt: 0
    property bool queryActive: false
    property bool queryExited: false
    property bool outputFinished: false
    property string output: ""
    property int exitCode: 0

    onTrackChanged: root.invalidate()
    onPlayingChanged: root.invalidate()
    onRateChanged: root.invalidate()
    onEnabledChanged: {
        root.invalidate();
        if (!root.enabled)
            query.running = false;
    }

    function invalidate(): void {
        root.epoch += 1;
        root.sampleAt = 0;
        Qt.callLater(root.refresh);
    }

    function positionFor(rawPosition: real): real {
        if (!root.enabled || root.sampleAt <= 0)
            return rawPosition;
        const elapsed = (Date.now() - root.sampleAt) / 1000;
        const advance = root.playing ? elapsed * root.rate : 0;
        // A new Quickshell anchor means a seek/state transition has arrived.
        // Discard our older sample rather than overriding that transition.
        if (elapsed < 0 || elapsed > 2
                || Math.abs(rawPosition - root.sampleRawPosition - advance) > 0.1) {
            root.invalidate();
            return rawPosition;
        }
        return Math.max(0, root.samplePosition + advance);
    }

    function refresh(): void {
        const player = MprisController.activePlayer;
        if (!root.enabled || root.queryActive || query.running || !player)
            return;
        root.requestEpoch = root.epoch;
        root.requestTrack = root.track;
        root.requestAt = Date.now();
        root.queryActive = true;
        root.queryExited = false;
        root.outputFinished = false;
        root.output = "";
        root.exitCode = 0;
        // Cider silently reanchors Position for corrections below 1.5 s.
        // positionChanged() only redraws Quickshell's independent anchor.
        query.command = ["gdbus", "call", "--session", "--timeout", "1", "--dest", player.dbusName,
            "--object-path", "/org/mpris/MediaPlayer2", "--method", "org.freedesktop.DBus.Properties.Get",
            "org.mpris.MediaPlayer2.Player", "Position"];
        query.running = true;
    }

    function finishQuery(): void {
        if (!root.queryActive || !root.queryExited || !root.outputFinished)
            return;
        if (root.exitCode === 0)
            root.receive(root.output);
        root.queryActive = false;
    }

    function receive(text: string): void {
        const now = Date.now();
        if (!root.enabled || root.requestEpoch !== root.epoch || root.requestTrack !== root.track
                || now < root.requestAt || now - root.requestAt > 250)
            return;
        const match = text.match(/^\(\s*<int64\s+(-?\d+)>\s*,?\s*\)\s*$/);
        if (!match)
            return;
        const position = Number(match[1]) / 1000000;
        if (!Number.isFinite(position) || position < 0)
            return;
        // The value was read between request and response; use their midpoint.
        root.samplePosition = position + (root.playing ? (now - root.requestAt) / 2000 * root.rate : 0);
        root.sampleRawPosition = MprisController.activePlayer?.position ?? 0;
        root.sampleAt = now;
    }

    Timer {
        interval: 500
        running: root.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: query
        stdout: StdioCollector {
            onStreamFinished: {
                root.output = text;
                root.outputFinished = true;
                root.finishQuery();
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.exitCode = exitCode;
            root.queryExited = true;
            root.finishQuery();
        }
        onRunningChanged: {
            if (query.running || !root.queryActive || root.queryExited)
                return;
            // FailedToStart emits neither exited nor stdout completion.
            root.exitCode = -1;
            root.queryExited = true;
            root.outputFinished = true;
            root.finishQuery();
        }
    }
}
