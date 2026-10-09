pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

Singleton {
    id: root

    readonly property bool ready: true
    property int watchers: 0

    readonly property list<var> species: [
        { id: "dot", label: "Dot", tint: "accent", ears: "round" },
        { id: "sprout", label: "Sprout", tint: "green", ears: "leaf" },
        { id: "ember", label: "Ember", tint: "red", ears: "tuft" },
        { id: "sol", label: "Sol", tint: "yellow", ears: "none" },
        { id: "drift", label: "Drift", tint: "blue", ears: "droop" }
    ]
    readonly property list<var> styles: [
        { id: "creature", label: "Creature", note: "A different animal for each species." },
        { id: "plush", label: "Plush", note: "One round body, shaded." },
        { id: "paper", label: "Paper", note: "Flat, cut from two tones." },
        { id: "pixel", label: "Pixel", note: "A sprite, sixteen cells across." }
    ]

    property list<var> family: []
    property int active: 0
    readonly property int activeIndex: Math.max(0, Math.min(root.active, root.family.length - 1))
    readonly property var pet: root.family[root.activeIndex] ?? null
    readonly property string name: root.pet ? root.pet.name : ""
    readonly property int level: root.pet ? root.pet.level : 1
    readonly property int xp: root.pet ? root.pet.xp : 0
    readonly property var speciesInfo: root.speciesOf(root.pet)
    readonly property bool hatched: root.pet ? root.pet.hatchedAt > 0 : false
    readonly property var milestones: [6, 16, 30, 50]
    readonly property int totalLevel: root.family.reduce((sum, entry) => sum + entry.level, 0)
    readonly property bool complete: root.family.length >= root.species.length
    readonly property int nextEggAt: root.complete ? 0 : root.milestones[Math.max(0, root.family.length - 1)]
    readonly property int levelsToNextEgg: root.complete ? 0 : Math.max(0, root.nextEggAt - root.totalLevel)
    readonly property real eggProgress: {
        if (root.complete)
            return 1
        const from = root.family.length < 2 ? 0 : root.milestones[root.family.length - 2]
        return Math.max(0, Math.min(1, (root.totalLevel - from) / Math.max(1, root.nextEggAt - from)))
    }
    readonly property int threshold: root.thresholdFor(root.level)
    readonly property real progress: Math.max(0, Math.min(1, root.xp / root.threshold))

    signal celebrated(int level)
    signal played()
    signal laid()
    signal brought(int index)

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function speciesOf(record: var): var {
        const wanted = record ? record.species : ""
        return root.species.find(kind => kind.id === wanted) ?? root.species[0]
    }

    function recordAt(index: int): var {
        return root.family[index] ?? null
    }

    function replace(index: int, record: var): var {
        return root.family.map((entry, at) => at === index ? record : entry)
    }

    function newborn(list: var): var {
        const taken = list.map(entry => entry.species)
        const left = root.species.filter(kind => taken.indexOf(kind.id) < 0)
        const kind = left.length > 0 ? left[Math.floor(Math.random() * left.length)] : root.species[0]
        return {
            species: kind.id, name: "", level: 1, xp: 0, fedAt: 0,
            playedAt: 0, hatchedAt: 0, restedAt: 0, fedRest: 0, playedRest: 0
        }
    }

    function earned(list: var): var {
        let grown = list
        while (grown.length < root.species.length) {
            const total = grown.reduce((sum, entry) => sum + entry.level, 0)
            if (total < root.milestones[grown.length - 1])
                break
            grown = grown.concat([root.newborn(grown)])
        }
        return grown
    }

    function thresholdFor(at: int): int {
        return 40 + 20 * at
    }

    function reward(amount: int, changes: var): void {
        if (!root.pet || amount <= 0)
            return
        const grown = Object.assign({}, root.pet, changes ?? {})
        if (grown.hatchedAt <= 0)
            grown.hatchedAt = Date.now()
        grown.xp += amount
        let reached = 0
        while (grown.xp >= root.thresholdFor(grown.level)) {
            grown.xp -= root.thresholdFor(grown.level)
            grown.level += 1
            reached = grown.level
        }
        const before = root.replace(root.activeIndex, grown)
        const after = root.earned(before)
        root.family = after
        root.saver.restart()
        if (reached > 0)
            root.celebrated(reached)
        if (after.length > before.length)
            root.laid()
    }

    readonly property real feedCooldown: 90 * 60000
    readonly property real playCooldown: 5 * 60000
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }

    function agoOf(stamp: real): real {
        return stamp > 0 ? Math.max(0, root.clock.date.getTime() - stamp) : 0
    }

    readonly property real fedAgo: root.agoOf(root.pet ? root.pet.fedAt : 0)
    readonly property real playedAgo: root.agoOf(root.pet ? root.pet.playedAt : 0)
    readonly property real fedAwake: Math.max(0, root.fedAgo - (root.pet?.fedRest ?? 0))
    readonly property real playedAwake: Math.max(0, root.playedAgo - (root.pet?.playedRest ?? 0))
    readonly property bool canFeed: !!root.pet && (root.pet.fedAt <= 0 || root.fedAgo >= root.feedCooldown)
    readonly property bool canPlay: !!root.pet && (root.pet.playedAt <= 0 || root.playedAgo >= root.playCooldown)

    function feed(): void {
        if (root.canFeed)
            root.reward(25, { fedAt: Date.now(), fedRest: 0 })
    }

    function play(): void {
        if (!root.canPlay)
            return
        const bonus = Math.min(18, Math.floor(root.playedAwake / 3600000) * 3)
        root.reward(12 + bonus, { playedAt: Date.now(), playedRest: 0 })
        root.played()
    }

    function renameAt(index: int, text: string): void {
        if (index < 0 || index >= root.family.length)
            return
        root.family = root.replace(index, Object.assign({}, root.family[index], {
            name: (text ?? "").trim().slice(0, 24)
        }))
        root.saver.restart()
    }

    function rename(text: string): void {
        root.renameAt(root.activeIndex, text)
    }

    function bringOut(index: int): void {
        if (index < 0 || index >= root.family.length || index === root.activeIndex)
            return
        const now = Date.now()
        const list = root.family.slice()
        list[root.activeIndex] = Object.assign({}, list[root.activeIndex], { restedAt: now })
        const waking = Object.assign({}, list[index])
        const slept = waking.restedAt > 0 ? Math.max(0, now - waking.restedAt) : 0
        if (waking.fedAt > 0)
            waking.fedRest = (waking.fedRest ?? 0) + slept
        if (waking.playedAt > 0)
            waking.playedRest = (waking.playedRest ?? 0) + slept
        waking.restedAt = 0
        list[index] = waking
        root.family = list
        root.active = index
        root.saver.restart()
        root.brought(index)
    }

    readonly property string mood: {
        if (root.fedAwake > 16 * 3600000 && root.playedAwake > 16 * 3600000)
            return "asleep"
        if (root.fedAwake > 6 * 3600000)
            return "peckish"
        if (root.playedAwake > 8 * 3600000)
            return "lonely"
        if (root.fedAwake < 3 * 3600000 && root.playedAwake < 2 * 3600000)
            return "beaming"
        return "content"
    }

    function moodAt(index: int): string {
        return index === root.activeIndex ? root.mood : "asleep"
    }

    readonly property string moodLine: {
        if (!root.hatched)
            return "An egg. Feed it and it will hatch"
        switch (root.mood) {
        case "beaming": return "Beaming"
        case "peckish": return "Peckish. A snack is owed"
        case "lonely": return "Lonely. Nobody has played today"
        case "asleep": return "Fast asleep"
        }
        return "Content"
    }

    function titleOf(record: var): string {
        if (!record || record.hatchedAt <= 0)
            return "Egg"
        return record.name !== "" ? record.name : root.speciesOf(record).label
    }

    readonly property int companyEvery: 5 * 60000
    readonly property int companyXp: 1
    readonly property Timer company: Timer {
        interval: root.companyEvery
        repeat: true
        running: root.watchers > 0 && root.hatched && !GlobalStates.lockscreenVisible
            && root.mood !== "asleep"
        onTriggered: root.reward(root.companyXp, null)
    }

    readonly property Timer saver: Timer {
        interval: 120
        onTriggered: {
            state.family = root.family
            state.active = root.active
            root.file.writeAdapter()
        }
    }

    readonly property FileView file: FileView {
        path: Quickshell.statePath("desktop-pet.json")
        atomicWrites: true
        onLoaded: root.adopt()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.adopt()
        }

        JsonAdapter {
            id: state
            property list<var> family: []
            property int active: 0
        }
    }

    function adopt(): void {
        if (root.family.length > 0)
            return
        if (state.family.length > 0) {
            root.family = state.family
            root.active = state.active
            return
        }
        let previous = null
        try {
            previous = JSON.parse(root.file.text())
        } catch (error) {
            previous = null
        }
        if (previous && Array.isArray(previous.family) && previous.family.length > 0) {
            root.family = previous.family
            root.active = previous.active ?? 0
            return
        }
        if (previous && previous.species) {
            root.family = [{
                species: previous.species,
                name: previous.name ?? "",
                level: Math.max(1, previous.level ?? 1),
                xp: Math.max(0, previous.xp ?? 0),
                fedAt: previous.fedAt ?? 0,
                playedAt: previous.playedAt ?? 0,
                hatchedAt: previous.hatchedAt ?? 0,
                restedAt: 0,
                fedRest: 0,
                playedRest: 0
            }]
        } else {
            root.family = [root.newborn([])]
        }
        root.active = 0
        root.saver.restart()
    }
}
