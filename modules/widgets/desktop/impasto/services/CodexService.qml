pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services.desktop as Nonchalant
import qs.modules.widgets.desktop.impasto.theme as Impasto

Singleton {
    readonly property bool available: Nonchalant.CodexService.available
    readonly property string plan: Nonchalant.CodexService.plan
    readonly property real gauge: Nonchalant.CodexService.gauge
    readonly property bool measured: Nonchalant.CodexService.measured
    readonly property var fullest: Nonchalant.CodexService.fullest
    readonly property string fullestName: Nonchalant.CodexService.fullestName
    readonly property string figure: Nonchalant.CodexService.figure
    readonly property list<var> limits: Nonchalant.CodexService.limits
    readonly property string age: Nonchalant.CodexService.age
    readonly property SystemClock clock: Nonchalant.CodexService.clock
    readonly property color tint: !measured ? Impasto.Theme.indicator
        : gauge >= 0.85 ? Impasto.Theme.indicatorBad
        : gauge >= 0.6 ? Impasto.Theme.indicatorWarn : Impasto.Theme.indicator

    function current(limit: var): bool { return Nonchalant.CodexService.current(limit) }
    function windowLine(limit: var): string { return Nonchalant.CodexService.windowLine(limit) }
    function subscribe(): void { Nonchalant.CodexService.subscribe() }
    function release(): void { Nonchalant.CodexService.release() }
}
