pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool ready: false
    readonly property list<var> states: [
        { id: "todo", label: "To do", icon: "󰄰" },
        { id: "doing", label: "Doing", icon: "󰪡" },
        { id: "done", label: "Done", icon: "󰄲" }
    ]
    readonly property SystemClock clock: SystemClock { precision: SystemClock.Minutes }
    readonly property string todayKey: root.dayKey(root.clock.date)
    property list<var> tasks: []

    readonly property int count: root.tasks.length
    readonly property int pending: root.tasks.filter(task => task.state !== "done").length
    readonly property list<var> dated: root.tasks.filter(task => task.due !== "")
        .sort((left, right) => left.due < right.due ? -1
            : left.due > right.due ? 1 : root.byRank(left, right))
    readonly property list<var> overdue: root.dated.filter(task => root.isOverdue(task))
    readonly property list<var> upcoming: root.dated
        .filter(task => task.state !== "done" && task.due >= root.todayKey)
    readonly property var next: root.upcoming[0] ?? null
    readonly property list<var> queue: root.tasks.filter(task => task.state !== "done")
        .sort((left, right) => {
            if (left.due !== "" && right.due !== "")
                return left.due < right.due ? -1 : left.due > right.due ? 1 : root.byRank(left, right)
            if (left.due !== "") return -1
            if (right.due !== "") return 1
            return root.byRank(left, right)
        })
    readonly property string summary: {
        if (root.overdue.length > 0)
            return `${root.overdue.length} overdue`
        const dueToday = root.pendingOn(root.todayKey)
        if (dueToday > 0)
            return `${dueToday} due today`
        if (root.next)
            return `${root.next.text} · ${root.dueLabel(root.next.due)}`
        return root.pending > 0 ? "nothing dated" : "nothing to do"
    }
    readonly property var dayNames: [
        ["mon", "monday", "lun", "lunes"],
        ["tue", "tuesday", "mar", "martes"],
        ["wed", "wednesday", "mie", "mié", "miercoles", "miércoles"],
        ["thu", "thursday", "jue", "jueves"],
        ["fri", "friday", "vie", "viernes"],
        ["sat", "saturday", "sab", "sáb", "sabado", "sábado"],
        ["sun", "sunday", "dom", "domingo"]
    ]
    readonly property var monthNames: [
        ["jan", "january", "ene", "enero"], ["feb", "february", "febrero"],
        ["mar", "march", "marzo"], ["apr", "april", "abr", "abril"],
        ["may", "mayo"], ["jun", "june", "junio"], ["jul", "july", "julio"],
        ["aug", "august", "ago", "agosto"], ["sep", "september", "septiembre"],
        ["oct", "october", "octubre"], ["nov", "november", "noviembre"],
        ["dec", "diciembre", "december", "dic"]
    ]
    readonly property int panelWidth: 760
    readonly property int panelHeight: 520
    property string opened: ""
    property bool direct: false

    signal added(string key)

    function stateEntry(id: string): var {
        return root.states.find(item => item.id === id) ?? root.states[0]
    }

    function stateAfter(id: string): string {
        const at = root.states.findIndex(item => item.id === id)
        return root.states[Math.min(root.states.length - 1, Math.max(0, at + 1))].id
    }

    function dayKey(date: var): string {
        return Qt.formatDate(date, "yyyy-MM-dd")
    }

    function dateOf(key: string): var {
        const match = (key ?? "").match(/^(\d{4})-(\d{2})-(\d{2})$/)
        if (!match)
            return null
        const year = Number(match[1])
        const month = Number(match[2]) - 1
        const day = Number(match[3])
        const date = new Date(year, month, day)
        return date.getFullYear() === year && date.getMonth() === month && date.getDate() === day
            ? date : null
    }

    function shifted(days: int): string {
        const date = new Date(root.clock.date)
        date.setDate(date.getDate() + days)
        return root.dayKey(date)
    }


    function normalise(list: list<var>): list<var> {
        const rows = []
        for (let index = 0; index < list.length; index++) {
            const item = list[index]
            if (!item || typeof item.key !== "string" || item.key === "")
                continue
            const row = Object.assign({
                text: "", body: "", state: "todo", due: "", rank: index, created: 0, finished: 0
            }, item)
            if (!root.states.some(state => state.id === row.state))
                row.state = "todo"
            if (!Number.isFinite(row.rank))
                row.rank = index
            rows.push(row)
        }
        return rows
    }

    function hydrate(saved: list<var>): void {
        if (root.ready)
            return
        const pending = root.tasks
        const loaded = root.normalise(saved)
        for (const task of pending) {
            if (!loaded.some(existing => existing.key === task.key))
                loaded.push(task)
        }
        root.tasks = loaded
        root.ready = true
        if (pending.length > 0)
            root.saver.restart()
    }

    function entry(key: string): var {
        return root.tasks.find(task => task.key === key) ?? null
    }

    function byRank(left: var, right: var): int {
        return left.rank !== right.rank ? left.rank - right.rank : left.created - right.created
    }

    function inState(state: string): var {
        return root.tasks.filter(task => task.state === state).sort(root.byRank)
    }

    function countIn(state: string): int {
        return root.tasks.filter(task => task.state === state).length
    }

    function on(day: string): var {
        return root.tasks.filter(task => task.due === day).sort((left, right) => {
            const doneLeft = left.state === "done" ? 1 : 0
            const doneRight = right.state === "done" ? 1 : 0
            return doneLeft !== doneRight ? doneLeft - doneRight : root.byRank(left, right)
        })
    }

    function countOn(day: string): int {
        return root.tasks.filter(task => task.due === day).length
    }

    function pendingOn(day: string): int {
        return root.tasks.filter(task => task.due === day && task.state !== "done").length
    }

    function isOverdue(task: var): bool {
        return !!task && task.due !== "" && task.state !== "done" && task.due < root.todayKey
    }

    function dueLabel(day: string): string {
        if (!day)
            return ""
        if (day === root.todayKey)
            return "today"
        if (day === root.shifted(1))
            return "tomorrow"
        if (day === root.shifted(-1))
            return "yesterday"
        const date = root.dateOf(day)
        if (!date)
            return day
        if (day > root.todayKey && day <= root.shifted(6))
            return Qt.formatDate(date, "dddd")
        return Qt.formatDate(date, date.getFullYear() === root.clock.date.getFullYear()
            ? "ddd d MMM" : "d MMM yyyy")
    }

    function monthIndex(word: string): int {
        return root.monthNames.findIndex(names => names.indexOf(word) >= 0)
    }

    function parseDue(text: string): string {
        const word = (text ?? "").trim().toLowerCase()
        if (word === "") return ""
        if (/^\d{4}-\d{2}-\d{2}$/.test(word))
            return root.dateOf(word) ? word : ""
        if (["today", "tod", "hoy"].indexOf(word) >= 0)
            return root.todayKey
        if (["tomorrow", "tom", "mañana", "manana"].indexOf(word) >= 0)
            return root.shifted(1)
        if (["next week", "nextweek"].indexOf(word) >= 0)
            return root.shifted(7)
        const plus = word.match(/^\+(\d{1,3})$/)
        if (plus)
            return root.shifted(Number(plus[1]))
        const weekday = root.dayNames.findIndex(names => names.indexOf(word) >= 0)
        if (weekday >= 0) {
            const today = (root.clock.date.getDay() + 6) % 7
            return root.shifted((weekday - today + 7) % 7)
        }
        const year = root.clock.date.getFullYear()
        const build = (day, month, yearGiven) => {
            const selectedYear = yearGiven ?? year
            let date = new Date(selectedYear, month, day)
            if (date.getMonth() !== month || date.getDate() !== day)
                return ""
            if (yearGiven === undefined && root.dayKey(date) < root.todayKey)
                date = new Date(selectedYear + 1, month, day)
            return root.dayKey(date)
        }
        const slash = word.match(/^(\d{1,2})[\/.](\d{1,2})(?:[\/.](\d{2,4}))?$/)
        if (slash) {
            const y = slash[3] === undefined ? undefined
                : slash[3].length === 2 ? 2000 + Number(slash[3]) : Number(slash[3])
            return build(Number(slash[1]), Number(slash[2]) - 1, y)
        }
        const parts = word.split(/\s+/)
        if (parts.length === 2 || parts.length === 3) {
            const y = parts.length === 3 ? Number(parts[2]) : undefined
            if (parts.length === 3 && !Number.isFinite(y)) return ""
            const first = Number(parts[0])
            const second = Number(parts[1])
            const monthAfter = root.monthIndex(parts[1])
            const monthBefore = root.monthIndex(parts[0])
            if (Number.isFinite(first) && monthAfter >= 0)
                return build(first, monthAfter, y)
            if (Number.isFinite(second) && monthBefore >= 0)
                return build(second, monthBefore, y)
        }
        return ""
    }

    function split(line: string): var {
        const text = (line ?? "").trim()
        const at = text.lastIndexOf("@")
        if (at > 0) {
            const due = root.parseDue(text.slice(at + 1))
            if (due !== "")
                return { text: text.slice(0, at).trim(), due: due }
        }
        return { text: text, due: "" }
    }

    function newKey(): string {
        const stamp = Date.now().toString(36)
        let key = `task-${stamp}`
        for (let number = 2; root.entry(key); number++)
            key = `task-${stamp}-${number}`
        return key
    }

    function write(next: var): void {
        root.tasks = next
        if (root.ready)
            root.saver.restart()
    }

    function lastRank(state: string): int {
        const column = root.inState(state)
        return column.length === 0 ? 0 : column[column.length - 1].rank + 1
    }

    function add(text: string, due = "", state = "todo", body = ""): string {
        const line = (text ?? "").trim()
        const validState = root.states.some(item => item.id === state) ? state : "todo"
        const key = root.newKey()
        root.write(root.tasks.concat([{
            key: key, text: line, body: body ?? "", state: validState,
            due: due ?? "", rank: root.lastRank(validState), created: Date.now(), finished: 0
        }]))
        root.added(key)
        return key
    }

    function create(fromBoard = false): string {
        const key = root.add("", "", "todo", "")
        root.opened = key
        root.direct = !fromBoard
        return key
    }

    function isEmpty(task: var): bool {
        return !task || (task.text ?? "").trim() === ""
    }

    function update(key: string, changes: var): void {
        if (!root.entry(key) || !changes || typeof changes !== "object")
            return
        root.write(root.tasks.map(task => task.key === key
            ? Object.assign({}, task, changes) : task))
    }

    function setState(key: string, state: string): void {
        const task = root.entry(key)
        if (!task || !root.states.some(item => item.id === state) || task.state === state)
            return
        root.update(key, { state: state, rank: root.lastRank(state),
            finished: state === "done" ? Date.now() : 0 })
    }

    function place(key: string, state: string, index: int): void {
        const task = root.entry(key)
        if (!task || !root.states.some(item => item.id === state))
            return
        const column = root.inState(state).filter(other => other.key !== key)
        column.splice(Math.max(0, Math.min(column.length, index)), 0, task)
        const ranks = ({})
        column.forEach((other, position) => { ranks[other.key] = position })
        root.write(root.tasks.map(other => {
            if (ranks[other.key] === undefined)
                return other
            const next = Object.assign({}, other, { rank: ranks[other.key] })
            if (other.key === key && other.state !== state) {
                next.state = state
                next.finished = state === "done" ? Date.now() : 0
            }
            return next
        }))
    }

    function setDue(key: string, due: string): void {
        if (root.entry(key))
            root.update(key, { due: due ?? "" })
    }

    function toggle(key: string): void {
        const task = root.entry(key)
        if (task)
            root.setState(key, task.state === "done" ? "todo" : "done")
    }

    function remove(key: string): void {
        if (!root.entry(key))
            return
        root.write(root.tasks.filter(task => task.key !== key))
        if (root.opened === key)
            root.opened = ""
    }

    function open(key: string, fromBoard = false): void {
        root.opened = root.entry(key) ? key : ""
        root.direct = !fromBoard
    }

    function leave(): void {
        const task = root.entry(root.opened)
        root.opened = ""
        root.direct = false
        if (task && root.isEmpty(task))
            root.remove(task.key)
    }

    readonly property Timer saver: Timer {
        interval: 120
        onTriggered: {
            if (!root.ready)
                return
            state.tasks = root.tasks
            root.file.writeAdapter()
        }
    }

    readonly property FileView file: FileView {
        path: Quickshell.statePath("desktop-tasks.json")
        atomicWrites: true
        onLoaded: root.hydrate(state.tasks)
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.hydrate([])
        }

        JsonAdapter {
            id: state
            property list<var> tasks: []
        }
    }
}
