pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.theme

CircularBarMeter {
    id: root

    readonly property var audioDevice: Audio.sink?.audio ?? null

    value: audioDevice?.volume ?? 0
    icon: {
        if (audioDevice?.muted)
            return Icons.speakerSlash;
        if (value < 0.01)
            return Icons.speakerX;
        if (value < 0.19)
            return Icons.speakerNone;
        if (value < 0.49)
            return Icons.speakerLow;
        return Icons.speakerHigh;
    }
    progressColor: audioDevice?.muted ? Colors.outline : Styling.srItem("overprimary")
    tooltipText: (audioDevice?.muted ? "Muted " : "Volume ") + Math.round(value * 100) + "%"

    onAdjusted: newValue => {
        if (audioDevice)
            audioDevice.volume = newValue;
    }

    onActivated: {
        if (audioDevice)
            audioDevice.muted = !audioDevice.muted;
    }
}
