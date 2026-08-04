pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.modules.services
import qs.modules.theme

/**
 * Headphone audio format monitor.
 *
 * Watches the default PipeWire sink and classifies it as a bluetooth, usb or
 * wired headphone from node properties. The negotiated sample rate, bit depth
 * and channel count come from the sink's current sample specification, read
 * via `pactl list sinks` (pipewire-pulse).
 *
 * `connected` is only true while a headphone-class output is the default sink,
 * so the bar pill can disappear completely when nothing is attached.
 */
Singleton {
    id: root

    // The default output node, kept bound so `properties` stay live.
    property PwNode sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: [root.sink]
    }

    // --- Classification (reactive to pipewire node properties) ---

    readonly property string sinkApi: root.sink?.properties?.["device.api"] ?? ""
    readonly property string sinkBus: root.sink?.properties?.["device.bus"] ?? ""
    readonly property string sinkName: root.sink?.properties?.["node.name"] ?? ""
    readonly property string sinkDescription: root.sink?.properties?.["node.description"] ?? ""
    readonly property string sinkNick: root.sink?.properties?.["node.nick"] ?? ""

    readonly property bool sinkIsBluetooth: root.sinkApi === "bluez5"
    readonly property bool sinkIsUsb: root.sinkApi === "alsa" && root.sinkBus === "usb"

    function looksLikeHeadphone(): bool {
        const haystack = (root.sinkName + " " + root.sinkDescription + " " + root.sinkNick).toLowerCase();
        return haystack.indexOf("headphone") !== -1
            || haystack.indexOf("headset") !== -1
            || haystack.indexOf("earbud") !== -1
            || haystack.indexOf("earphone") !== -1;
    }

    // Wired = analog output on a non-usb card that names itself a headphone.
    readonly property bool sinkIsWired: root.sinkApi === "alsa" && root.sinkBus !== "usb" && root.looksLikeHeadphone()

    readonly property string kind: root.sinkIsBluetooth ? "bluetooth" : (root.sinkIsUsb ? "usb" : (root.sinkIsWired ? "wired" : ""))
    readonly property bool connected: root.kind !== ""

    // Bluetooth codec (empty for non-bluetooth sinks).
    readonly property string codec: root.sink?.properties?.["api.bluez5.codec"] ?? ""

    // Human readable captions.
    readonly property string kindLabel: root.kind === "bluetooth" ? "Bluetooth" : (root.kind === "usb" ? "USB" : (root.kind === "wired" ? "Wired" : ""))
    readonly property string kindIcon: root.kind === "bluetooth" ? Icons.bluetoothConnected : (root.kind === "usb" ? Icons.usb : Icons.headphones)
    readonly property string deviceName: root.sinkDescription || root.sinkNick || root.sinkName

    // --- Negotiated format (from pactl sample specification) ---

    property string sampleSpec: ""
    property int sampleRateHz: 0
    property int bitDepth: 0
    property int channels: 0

    function depthFromSpec(spec: string): int {
        const integerMatch = spec.match(/^[su](\d+)(?:-\d+)?(?:le|be)$/);
        if (integerMatch)
            return parseInt(integerMatch[1], 10);

        const floatMatch = spec.match(/^float(\d+)(?:le|be)$/);
        return floatMatch ? parseInt(floatMatch[1], 10) : 0;
    }

    function parseSinks(output: string) {
        const sinkName = root.sinkName;
        const blocks = (output || "").split(/\n\s*\n/);

        for (let i = 0; i < blocks.length; i++) {
            const block = blocks[i];
            if (block.indexOf("Sink #") === -1) continue;

            const nameMatch = block.match(/Name:\s*(\S+)/);
            if (!nameMatch || nameMatch[1] !== sinkName) continue;

            const specMatch = block.match(/Sample Specification:\s*(\S+)\s+(\d+)ch\s+(\d+)Hz/);
            if (specMatch) {
                root.sampleSpec = specMatch[1];
                root.channels = parseInt(specMatch[2], 10);
                root.sampleRateHz = parseInt(specMatch[3], 10);
                root.bitDepth = root.depthFromSpec(specMatch[1]);
            } else {
                root.clearRates();
            }
            return;
        }

        // Sink not present (disconnected) or unparsable.
        root.clearRates();
    }

    function clearRates() {
        root.sampleSpec = "";
        root.sampleRateHz = 0;
        root.channels = 0;
        root.bitDepth = 0;
    }

    function codecDisplayName(codec: string): string {
        switch (codec) {
        case "sbc": return "SBC";
        case "aac": return "AAC";
        case "mp3": return "MP3";
        case "aptx": return "aptX";
        case "aptx_hd": return "aptX HD";
        case "aptx_ll": return "aptX LL";
        case "aptx_ll_duplex": return "aptX LL Duplex";
        case "ldac": return "LDAC";
        default: return codec ? codec.toUpperCase() : "";
        }
    }


    // --- Display helpers ---

    function formatRate(): string {
        if (root.sampleRateHz <= 0) return "";
        const khz = root.sampleRateHz / 1000;
        return (khz % 1 === 0 ? khz.toString() : khz.toFixed(1)) + "kHz";
    }

    function formatDepth(): string {
        return root.bitDepth > 0 ? root.bitDepth + "bit" : "";
    }

    readonly property string formatSummary: [root.formatRate(), root.formatDepth()].filter(x => x !== "").join(" · ")
    readonly property string tooltipTitle: root.connected ? root.kindLabel + ": " + root.deviceName : ""
    readonly property string tooltipDetail: {
        if (!root.connected) return "";
        const parts = [];
        if (root.codec) parts.push("Codec: " + root.codecDisplayName(root.codec));
        if (root.formatSummary) parts.push("Format: " + root.formatSummary);
        return parts.join("\n");
    }

    // --- Refresh ---

    function refresh() {
        if (!root.connected) {
            root.clearRates();
            return;
        }
        if (!pactlProcess.running) {
            pactlProcess.running = true;
        }
    }

    // Full restart so a sink switch re-reads immediately.
    function restartMonitor() {
        pactlProcess.running = false;
        Qt.callLater(() => {
            root.refresh();
        });
    }

    property Process pactlProcess: Process {
        id: pactlProcess
        running: false

        command: ["pactl", "list", "sinks"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseSinks(text);
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("AudioFormat: pactl exited with code", exitCode);
                root.clearRates();
            }
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.connected
        onTriggered: root.refresh()
    }

    Connections {
        target: Pipewire
        ignoreUnknownSignals: true
        function onDefaultAudioSinkChanged() { root.restartMonitor(); }
        function onReadyChanged() { if (Pipewire.ready) root.refresh(); }
    }

    Connections {
        target: root.sink
        ignoreUnknownSignals: true
        function onPropertiesChanged() { root.restartMonitor(); }
    }

    Connections {
        target: root
        function onConnectedChanged() { root.refresh(); }
    }

    Component.onCompleted: Qt.callLater(() => root.refresh())
}