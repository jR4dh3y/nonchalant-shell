pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services as Nonchalant

Singleton {
    readonly property bool ready: Nonchalant.Audio.ready
    readonly property real volume: ready ? Math.round(Nonchalant.Audio.value * 100) : 0
    readonly property bool muted: ready && (Nonchalant.Audio.sink?.audio?.muted ?? false)
    readonly property string icon: !ready || muted ? "󰝟"
        : volume <= 0 ? "󰕿"
        : volume < 50 ? "󰖀" : "󰕾"

    function toggleMute(): void {
        Nonchalant.Audio.toggleMute()
    }

    function setVolume(percent: real): void {
        Nonchalant.Audio.setVolume(Math.max(0, Math.min(100, percent)) / 100)
    }

    function toggleMicMute(): void {
        Nonchalant.Audio.toggleMicMute()
    }

    function setMicVolume(percent: real): void {
        Nonchalant.Audio.setMicVolume(Math.max(0, Math.min(100, percent)) / 100)
    }
}
