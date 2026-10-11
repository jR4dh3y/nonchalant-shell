pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services.desktop as Nonchalant
import qs.modules.services as LocalServices

Singleton {
    id: root

    readonly property bool ready: Nonchalant.TasksService.ready
    readonly property list<var> states: Nonchalant.TasksService.states
    readonly property var clock: Nonchalant.TasksService.clock
    readonly property string todayKey: Nonchalant.TasksService.todayKey
    readonly property list<var> tasks: Nonchalant.TasksService.tasks
    readonly property int count: Nonchalant.TasksService.count
    readonly property int pending: Nonchalant.TasksService.pending
    readonly property list<var> overdue: Nonchalant.TasksService.overdue
    readonly property var next: Nonchalant.TasksService.next
    readonly property list<var> queue: Nonchalant.TasksService.queue
    readonly property string summary: Nonchalant.TasksService.summary
    readonly property var dayNames: Nonchalant.TasksService.dayNames
    readonly property var monthNames: Nonchalant.TasksService.monthNames
    readonly property int panelWidth: Nonchalant.TasksService.panelWidth
    readonly property int panelHeight: Nonchalant.TasksService.panelHeight
    readonly property string opened: Nonchalant.TasksService.opened
    readonly property bool direct: Nonchalant.TasksService.direct

    signal added(string key)

    Connections {
        target: Nonchalant.TasksService
        function onAdded(key: string): void { root.added(key) }
    }

    function stateEntry(id: string): var { return Nonchalant.TasksService.stateEntry(id) }
    function stateAfter(id: string): string { return Nonchalant.TasksService.stateAfter(id) }
    function dayKey(date: var): string { return Nonchalant.TasksService.dayKey(date) }
    function dateOf(key: string): var { return Nonchalant.TasksService.dateOf(key) }
    function shifted(days: int): string { return Nonchalant.TasksService.shifted(days) }
    function parseDue(text: string): string { return Nonchalant.TasksService.parseDue(text) }
    function split(line: string): var { return Nonchalant.TasksService.split(line) }
    function entry(key: string): var { return Nonchalant.TasksService.entry(key) }
    function inState(state: string): var { return Nonchalant.TasksService.inState(state) }
    function countIn(state: string): int { return Nonchalant.TasksService.countIn(state) }
    function on(day: string): var { return Nonchalant.TasksService.on(day) }
    function countOn(day: string): int { return Nonchalant.TasksService.countOn(day) }
    function pendingOn(day: string): int { return Nonchalant.TasksService.pendingOn(day) }
    function isOverdue(task: var): bool { return Nonchalant.TasksService.isOverdue(task) }
    function dueLabel(day: string): string { return Nonchalant.TasksService.dueLabel(day) }
    function add(text: string, due = "", state = "todo", body = ""): string {
        return Nonchalant.TasksService.add(text, due, state, body)
    }
    function create(fromBoard = false): string {
        return Nonchalant.TasksService.create(fromBoard)
    }
    function update(key: string, changes: var): void {
        Nonchalant.TasksService.update(key, changes)
    }
    function setState(key: string, state: string): void {
        Nonchalant.TasksService.setState(key, state)
    }
    function place(key: string, state: string, index: int): void {
        Nonchalant.TasksService.place(key, state, index)
    }
    function setDue(key: string, due: string): void { Nonchalant.TasksService.setDue(key, due) }
    function toggle(key: string): void { Nonchalant.TasksService.toggle(key) }
    function remove(key: string): void { Nonchalant.TasksService.remove(key) }
    function open(key: string, row = null): void {
        Nonchalant.TasksService.open(key, false)
        if (row)
            LocalServices.DesktopWidgetService.openDetail("tasks", Object.assign({}, row, { task: key }))
    }
    function leave(): void { Nonchalant.TasksService.leave() }
}
