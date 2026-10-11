pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services.desktop as Nonchalant

Singleton {
    readonly property bool available: Nonchalant.UpdatesService.available
    readonly property bool checking: Nonchalant.UpdatesService.checking
    readonly property int count: Nonchalant.UpdatesService.count
    readonly property list<string> packages: Nonchalant.UpdatesService.packages
    readonly property list<var> updates: Nonchalant.UpdatesService.updates
    readonly property bool aur: Nonchalant.UpdatesService.aur
    readonly property string tool: Nonchalant.UpdatesService.tool
    readonly property string age: Nonchalant.UpdatesService.age

    function subscribe(): void { Nonchalant.UpdatesService.subscribe() }
    function release(): void { Nonchalant.UpdatesService.release() }
    function refresh(): void { Nonchalant.UpdatesService.refresh() }
}
