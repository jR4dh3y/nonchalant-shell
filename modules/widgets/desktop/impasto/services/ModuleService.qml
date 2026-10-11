pragma Singleton

import QtQuick
import Quickshell
import qs.modules.globals as Global
import qs.modules.services as LocalServices
import qs.modules.widgets.desktop.impasto.theme as Impasto
import "."

Singleton {
    id: root

    readonly property list<var> catalogue: [
        { id: "media", name: "Media", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(1, Impasto.Theme.cardRowGap + 34) },
        { id: "timer", name: "Timer", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(2, 0) },
        { id: "claude", name: "Claude", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(3, 0) },
        { id: "codex", name: "Codex", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(2, 0) },
        { id: "battery", name: "Battery", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(3, 0) },
        { id: "volume", name: "Volume", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(2, 0) },
        { id: "brightness", name: "Brightness", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(1, 0) },
        { id: "network", name: "Network", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(2, 0) },
        { id: "bluetooth", name: "Bluetooth", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(3, 0) },
        { id: "notifications", name: "Notifications", bar: true, desk: false,
          width: Impasto.Theme.cardWidth, height: Impasto.Theme.cardHeight(7, 0) },
        { id: "weather", name: "Weather", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(0, 50) },
        { id: "github", name: "GitHub", bar: false, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(0, GithubService.cardGrid) },
        { id: "stats", name: "System", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(2, Impasto.Theme.cardRowGap + 36) },
        { id: "updates", name: "Updates", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(4, 0) },
        { id: "pet", name: "Pet", bar: true, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(2, Impasto.Theme.cardRowGap + 32) },
        { id: "games", name: "Games", bar: false, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(4, 0) },
        { id: "calendar", name: "Calendar", bar: true, width: 340, height: 330 },
        { id: "notes", name: "Notes", bar: false, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(4, 0) },
        { id: "tasks", name: "Tasks", bar: false, width: Impasto.Theme.cardWidth,
          height: Impasto.Theme.cardHeight(4, 0) },
        { id: "photo", name: "Photo", bar: false, width: 356, height: 150 },
        { id: "spectrum", name: "Spectrum", bar: false, width: 0, height: 0 },
        { id: "lyrics", name: "Lyrics", bar: false, width: 0, height: 0 },
        { id: "clock", name: "Clock", bar: false,
          width: SettingsService.clockShowsDate ? 240 : 150, height: Impasto.Theme.capsuleHeight }
    ]

    function entry(id: string): var {
        return root.catalogue.find(item => item.id === id) ?? root.catalogue[0]
    }

    function watch(id: string, on: bool): void {
        switch (id) {
        case "claude":
            on ? ClaudeService.subscribe() : ClaudeService.release()
            break
        case "codex":
            on ? CodexService.subscribe() : CodexService.release()
            break
        case "weather":
            on ? WeatherService.subscribe() : WeatherService.release()
            break
        case "updates":
            on ? UpdatesService.subscribe() : UpdatesService.release()
            break
        case "github":
            on ? GithubService.subscribe() : GithubService.release()
            break
        case "pet":
            on ? PetService.subscribe() : PetService.release()
            break
        case "stats":
            on ? StatsService.subscribe() : StatsService.release()
            break
        }
    }

    function requestPanel(panelId: string, row = null): bool {
        if (panelId === "appearance") {
            Global.GlobalStates.openSettings("theme", "general")
            return true
        }
        if (panelId === "palette") {
            Global.GlobalStates.openSettings("theme", "colors")
            return true
        }
        if (panelId === "settings") {
            Global.GlobalStates.openSettings()
            return true
        }

        const moduleId = panelId === "board" ? "tasks" : panelId
        if (["notes", "tasks", "calendar", "timer", "pet", "games"].indexOf(moduleId) < 0)
            return false
        const desktop = LocalServices.DesktopWidgetService

        if (!row) {
            if (desktop.detailModuleId === moduleId)
                return true
            const selected = moduleId === "notes" ? NotesService.opened
                : moduleId === "tasks" ? TasksService.opened : ""
            if (selected !== "") {
                const current = desktop.widgets.find(widget => widget.id === moduleId
                    && (moduleId === "notes" ? widget.note === selected : widget.task === selected))
                if (current)
                    return desktop.openDetail(moduleId, current)
            }
            return false
        }

        const routed = Object.assign({}, row)
        if (moduleId === "notes" && NotesService.opened !== "")
            routed.note = NotesService.opened
        if (moduleId === "tasks" && TasksService.opened !== "")
            routed.task = TasksService.opened
        const screen = desktop.nameOf(routed)
        if (desktop.detailModuleId === moduleId
                && routed.key === desktop.detailKey
                && screen === desktop.detailScreen)
            return true
        return desktop.openDetail(moduleId, routed)
    }
}
