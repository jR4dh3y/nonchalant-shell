pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services.desktop as Nonchalant

Singleton {
    id: root

    readonly property bool ready: Nonchalant.PetService.ready
    readonly property list<var> species: Nonchalant.PetService.species
    readonly property list<var> styles: Nonchalant.PetService.styles
    readonly property list<var> family: Nonchalant.PetService.family
    readonly property int active: Nonchalant.PetService.active
    readonly property int activeIndex: Nonchalant.PetService.activeIndex
    readonly property var pet: Nonchalant.PetService.pet
    readonly property string name: Nonchalant.PetService.name
    readonly property int level: Nonchalant.PetService.level
    readonly property int xp: Nonchalant.PetService.xp
    readonly property var speciesInfo: Nonchalant.PetService.speciesInfo
    readonly property bool hatched: Nonchalant.PetService.hatched
    readonly property real progress: Nonchalant.PetService.progress
    readonly property string mood: Nonchalant.PetService.mood
    readonly property string moodLine: Nonchalant.PetService.moodLine
    readonly property int totalLevel: Nonchalant.PetService.totalLevel
    readonly property bool complete: Nonchalant.PetService.complete
    readonly property int nextEggAt: Nonchalant.PetService.nextEggAt
    readonly property int levelsToNextEgg: Nonchalant.PetService.levelsToNextEgg
    readonly property real eggProgress: Nonchalant.PetService.eggProgress
    readonly property SystemClock clock: Nonchalant.PetService.clock

    signal celebrated(int level)
    signal played()
    signal laid()
    signal brought(int index)

    Connections {
        target: Nonchalant.PetService
        function onCelebrated(level: int): void { root.celebrated(level) }
        function onPlayed(): void { root.played() }
        function onLaid(): void { root.laid() }
        function onBrought(index: int): void { root.brought(index) }
    }

    function speciesOf(record: var): var { return Nonchalant.PetService.speciesOf(record) }
    function recordAt(index: int): var { return Nonchalant.PetService.recordAt(index) }
    function titleOf(record: var): string { return Nonchalant.PetService.titleOf(record) }
    function moodAt(index: int): string { return Nonchalant.PetService.moodAt(index) }
    function feed(): void { Nonchalant.PetService.feed() }
    function play(): void { Nonchalant.PetService.play() }
    function rename(text: string): void { Nonchalant.PetService.rename(text) }
    function renameAt(index: int, text: string): void {
        Nonchalant.PetService.renameAt(index, text)
    }
    function bringOut(index: int): void { Nonchalant.PetService.bringOut(index) }
    function subscribe(): void { Nonchalant.PetService.subscribe() }
    function release(): void { Nonchalant.PetService.release() }
}
