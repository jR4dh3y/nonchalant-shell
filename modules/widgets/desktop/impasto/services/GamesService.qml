pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services.desktop as Nonchalant
import qs.modules.widgets.desktop.impasto.theme as Impasto

Singleton {
    id: root
    readonly property list<var> catalogue: Nonchalant.GamesService.catalogue
    readonly property list<var> ranked: Nonchalant.GamesService.ranked
    readonly property string lastPlayed: Nonchalant.GamesService.lastPlayed
    readonly property int totalPlays: Nonchalant.GamesService.totalPlays
    readonly property var tints: ({
        accent: Impasto.Theme.accent,
        green: Impasto.Theme.green,
        yellow: Impasto.Theme.yellow,
        red: Impasto.Theme.red,
        blue: Impasto.Theme.blue
    })

    function entry(id: string): var { return Nonchalant.GamesService.entry(id) }
    function bestOf(id: string): int { return Nonchalant.GamesService.bestOf(id) }
    function tintOf(id: string): color {
        const item = root.entry(id)
        return item ? (root.tints[item.tint] ?? Impasto.Theme.accent) : Impasto.Theme.accent
    }
}
