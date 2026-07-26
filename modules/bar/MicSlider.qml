pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.theme

CircularBarMeter {
    id: root

    readonly property var audioDevice: Audio.source?.audio ?? null

    value: audioDevice?.volume ?? 0
    icon: audioDevice?.muted ? Icons.micSlash : Icons.mic
    progressColor: audioDevice?.muted ? Colors.outline : Styling.srItem("overprimary")
    tooltipText: (audioDevice?.muted ? "Muted " : "Microphone ") + Math.round(value * 100) + "%"

    onAdjusted: newValue => {
        if (audioDevice)
            audioDevice.volume = newValue;
    }

    onActivated: {
        if (audioDevice)
            audioDevice.muted = !audioDevice.muted;
    }
}
