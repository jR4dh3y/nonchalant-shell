pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services.desktop as Nonchalant

Singleton {
    readonly property int bandCount: Nonchalant.CavaService.bandCount
    readonly property var bands: Nonchalant.CavaService.bands
    readonly property var peaks: Nonchalant.CavaService.peaks
    readonly property int barCount: Nonchalant.CavaService.barCount
    readonly property var values: Nonchalant.CavaService.values
    readonly property bool active: Nonchalant.CavaService.active
    readonly property real level: Nonchalant.CavaService.level

    function subscribe(): void { Nonchalant.CavaService.subscribe() }
    function release(): void { Nonchalant.CavaService.release() }
}
