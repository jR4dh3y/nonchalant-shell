pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services.desktop as Nonchalant
import qs.modules.widgets.desktop.impasto.theme as Impasto

Singleton {
    id: root

    signal finished(string label)

    readonly property bool running: Nonchalant.TimerService.running
    readonly property bool paused: Nonchalant.TimerService.paused
    readonly property string label: Nonchalant.TimerService.label
    readonly property real endsAt: Nonchalant.TimerService.endsAt
    readonly property real duration: Nonchalant.TimerService.duration
    readonly property real remaining: Nonchalant.TimerService.remaining
    readonly property real progress: Nonchalant.TimerService.progress
    readonly property int seconds: Nonchalant.TimerService.seconds
    readonly property string display: Nonchalant.TimerService.display
    readonly property color tint: !running ? Impasto.Theme.indicatorDim
        : seconds <= 30 ? Impasto.Theme.indicatorBad
        : seconds <= 120 ? Impasto.Theme.indicatorWarn : Impasto.Theme.indicatorTimer

    Connections {
        target: Nonchalant.TimerService
        function onFinished(label: string): void { root.finished(label) }
    }

    function parse(text: string): real { return Nonchalant.TimerService.parse(text) }
    function start(milliseconds: real, label = ""): void {
        Nonchalant.TimerService.start(milliseconds, label)
    }
    function pause(): void { Nonchalant.TimerService.pause() }
    function resume(): void { Nonchalant.TimerService.resume() }
    function toggle(): void { Nonchalant.TimerService.toggle() }
    function restart(): void { Nonchalant.TimerService.restart() }
    function cancel(): void { Nonchalant.TimerService.cancel() }
}
