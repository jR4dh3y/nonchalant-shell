pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services.desktop as Nonchalant
import qs.modules.widgets.desktop.impasto.theme as Impasto

Singleton {
    id: root
    readonly property bool available: Nonchalant.ClaudeService.available
    readonly property int blockTokens: Nonchalant.ClaudeService.blockTokens
    readonly property int blockMessages: Nonchalant.ClaudeService.blockMessages
    readonly property int weekTokens: Nonchalant.ClaudeService.weekTokens
    readonly property int weekMessages: Nonchalant.ClaudeService.weekMessages
    readonly property int peakBlockTokens: Nonchalant.ClaudeService.peakBlockTokens
    readonly property int peakWeekTokens: Nonchalant.ClaudeService.peakWeekTokens
    readonly property real gauge: Nonchalant.ClaudeService.gauge
    readonly property real sessionFraction: 0
    readonly property real weeklyFraction: 0
    readonly property bool sessionMeasured: false
    readonly property bool weeklyMeasured: false
    readonly property bool measured: false
    readonly property string resetsIn: Nonchalant.ClaudeService.resetsIn
    readonly property color tint: available ? Impasto.Theme.indicator : Impasto.Theme.indicatorDim
    readonly property SystemClock clock: Nonchalant.ClaudeService.clock

    function compact(tokens: int): string { return Nonchalant.ClaudeService.compact(tokens) }
    function messages(count: int): string {
        return `${root.compact(count)} message${count === 1 ? "" : "s"}`
    }
    function percent(fraction: real): string { return `${Math.round(fraction * 100)}%` }
    function subscribe(): void { Nonchalant.ClaudeService.subscribe() }
    function release(): void { Nonchalant.ClaudeService.release() }
}
