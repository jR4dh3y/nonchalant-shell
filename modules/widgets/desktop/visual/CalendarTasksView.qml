pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme

Item {
    id: root

    property string family: "4x2"
    property string theme: "modern"
    property var ink
    property var row: null
    property bool interactive: false
    property bool fullMonth: false

    readonly property bool monthView: root.fullMonth || root.family === "4x4"
    readonly property color textColor: root.ink?.text ?? Colors.overSurface
    readonly property color mutedColor: root.ink?.muted ?? Colors.overSurfaceVariant
    readonly property color accentColor: root.ink?.accent ?? Colors.primary
    readonly property color accentTextColor: root.ink?.accentText ?? Colors.overPrimary
    readonly property real taskRowHeight: Math.max(Styling.fontSize(0) * 2.2, Styling.fontSize(5))
    readonly property date today: TasksService.clock.date
    readonly property date selectedDate: TasksService.dateOf(root.selectedDay) ?? root.today
    readonly property string selectedLabel: root.selectedDay === TasksService.todayKey
        ? "Today" : Qt.formatDate(root.selectedDate, "dddd d MMM")
    readonly property var dayTasks: TasksService.on(root.selectedDay)
    readonly property int pendingOnDay: TasksService.pendingOn(root.selectedDay)

    property date monthStart: new Date(root.today.getFullYear(), root.today.getMonth(), 1)
    property string selectedDay: TasksService.todayKey

    readonly property list<string> monthCells: {
        const year = root.monthStart.getFullYear()
        const month = root.monthStart.getMonth()
        const firstOffset = (new Date(year, month, 1).getDay() + 6) % 7
        const days = new Date(year, month + 1, 0).getDate()
        const count = Math.ceil((firstOffset + days) / 7) * 7
        const cells = []
        for (let index = 0; index < count; index++) {
            const day = index - firstOffset + 1
            cells.push(day > 0 && day <= days
                ? TasksService.dayKey(new Date(year, month, day)) : "")
        }
        return cells
    }
    readonly property list<string> weekDays: {
        const monday = new Date(root.selectedDate)
        monday.setDate(monday.getDate() - (monday.getDay() + 6) % 7)
        const days = []
        for (let index = 0; index < 7; index++) {
            const day = new Date(monday)
            day.setDate(day.getDate() + index)
            days.push(TasksService.dayKey(day))
        }
        return days
    }

    function shiftMonth(amount: int): void {
        const next = new Date(root.monthStart.getFullYear(), root.monthStart.getMonth() + amount, 1)
        const selected = TasksService.dateOf(root.selectedDay) ?? root.today
        const lastDay = new Date(next.getFullYear(), next.getMonth() + 1, 0).getDate()
        const day = Math.min(selected.getDate(), lastDay)
        root.monthStart = next
        root.selectedDay = TasksService.dayKey(new Date(next.getFullYear(), next.getMonth(), day))
    }

    function shiftWeek(amount: int): void {
        const next = new Date(root.selectedDate)
        next.setDate(next.getDate() + amount * 7)
        root.selectedDay = TasksService.dayKey(next)
    }

    function selectDay(key: string): void {
        if (!root.interactive || !TasksService.dateOf(key))
            return
        root.selectedDay = key
        const day = TasksService.dateOf(key)
        if (day.getFullYear() !== root.monthStart.getFullYear()
                || day.getMonth() !== root.monthStart.getMonth())
            root.monthStart = new Date(day.getFullYear(), day.getMonth(), 1)
    }

    function openTask(key: string): bool {
        if (!root.interactive || !root.row || !TasksService.entry(key))
            return false
        const taskRow = Object.assign({}, root.row, { task: key })
        if (!DesktopWidgetService.openDetail("tasks", taskRow))
            return false
        TasksService.open(key)
        return true
    }

    function addTask(): void {
        if (!root.interactive)
            return
        if (!root.fullMonth) {
            const key = TasksService.create()
            TasksService.setDue(key, root.selectedDay)
            if (!root.openTask(key))
                TasksService.leave()
            return
        }
        const text = newTask.text.trim()
        if (text === "")
            return
        TasksService.add(text, root.selectedDay)
        newTask.clear()
    }

    StyledRect {
        anchors.fill: parent
        visible: root.theme !== "modern"
        variant: root.theme === "sticker" ? "pane" : "common"
        backgroundOpacity: root.theme === "sticker" ? 0.78 : 0.42
        radius: root.theme === "sticker" ? Styling.radius(-1) : Styling.radius(-4)
        border.color: root.ink?.dim ?? Colors.outlineVariant
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.theme === "sticker" ? Styling.fontSize(0) : Styling.fontSize(-1)
        spacing: Styling.fontSize(-4)

        RowLayout {
            Layout.fillWidth: true
            spacing: Styling.fontSize(-4)

            FaceActionButton {
                readonly property string actionName: root.monthView ? "month" : "week"
                controlWidth: Styling.fontSize(3)
                controlHeight: controlWidth
                text: "‹"
                accessibleName: `Previous ${actionName}`
                foregroundColor: root.textColor
                backgroundColor: root.theme === "sticker"
                    ? (root.ink?.paper ?? Colors.surfaceContainerHigh)
                    : (root.ink?.raised ?? Colors.surfaceContainerHigh)
                enabled: root.interactive
                onClicked: root.monthView ? root.shiftMonth(-1) : root.shiftWeek(-1)
            }

            Text {
                Layout.fillWidth: true
                text: root.monthView
                    ? Qt.formatDate(root.monthStart, "MMMM yyyy")
                    : Qt.formatDate(root.selectedDate, "MMMM yyyy")
                color: root.textColor
                font.family: root.theme === "analogue" ? Config.theme.monoFont : Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            FaceActionButton {
                readonly property string actionName: root.monthView ? "month" : "week"
                controlWidth: Styling.fontSize(3)
                controlHeight: controlWidth
                text: "›"
                accessibleName: `Next ${actionName}`
                foregroundColor: root.textColor
                backgroundColor: root.theme === "sticker"
                    ? (root.ink?.paper ?? Colors.surfaceContainerHigh)
                    : (root.ink?.raised ?? Colors.surfaceContainerHigh)
                enabled: root.interactive
                onClicked: root.monthView ? root.shiftMonth(1) : root.shiftWeek(1)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: root.monthView
            Layout.preferredHeight: root.monthView ? root.height * 0.46 : 0
            visible: root.monthView

            Grid {
                id: monthGrid
                anchors.fill: parent

                columns: 7
                rowSpacing: Styling.fontSize(-5)
                columnSpacing: Styling.fontSize(-5)
                readonly property int rowCount: 1 + root.monthCells.length / 7

                readonly property real cellWidth: Math.max(0, (width - columnSpacing * 6) / 7)
                readonly property real cellHeight: Math.max(0, (height - rowSpacing * (rowCount - 1)) / rowCount)

                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]

                    delegate: Item {
                        required property string modelData
                        width: monthGrid.cellWidth
                        height: monthGrid.cellHeight

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: root.mutedColor
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(-3)
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Repeater {
                    model: root.monthCells

                    delegate: Item {
                        id: monthCell
                        required property string modelData

                        readonly property int taskCount: modelData === "" ? 0 : TasksService.countOn(modelData)
                        readonly property int pendingCount: modelData === "" ? 0 : TasksService.pendingOn(modelData)
                        readonly property bool isToday: modelData !== "" && modelData === TasksService.todayKey
                        readonly property bool isSelected: modelData !== "" && modelData === root.selectedDay

                        width: monthGrid.cellWidth
                        height: monthGrid.cellHeight

                        StyledRect {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) * 0.88
                            height: width
                            visible: monthCell.isToday || monthCell.isSelected
                            variant: monthCell.isToday ? "primary" : "focus"
                            backgroundOpacity: monthCell.isToday ? 1 : 0.32
                            radius: root.theme === "sticker" ? Styling.radius(-3) : width / 2
                            border.color: monthCell.isSelected && !monthCell.isToday
                                ? root.accentColor : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: monthCell.taskCount > 0 ? -1 : 0
                            visible: monthCell.modelData !== ""
                            text: monthCell.modelData === "" ? "" : `${TasksService.dateOf(monthCell.modelData).getDate()}`
                            color: monthCell.isToday ? root.accentTextColor : root.textColor
                            font.family: root.theme === "analogue" ? Config.theme.monoFont : Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: monthCell.isToday ? Font.DemiBold : Font.Normal
                        }

                        StyledRect {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Styling.fontSize(-5)
                            visible: monthCell.taskCount > 0
                            width: Styling.fontSize(-4)
                            height: width
                            variant: "common"
                            radius: width / 2
                            color: monthCell.pendingCount > 0 ? root.accentColor : root.mutedColor
                            backgroundOpacity: 1
                            enableBorder: false
                        }

                        HoverHandler {
                            enabled: root.interactive && monthCell.modelData !== ""
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            enabled: root.interactive && monthCell.modelData !== ""
                            acceptedButtons: Qt.LeftButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.selectDay(monthCell.modelData)
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: root.monthView ? 0 : Styling.fontSize(6)
            visible: !root.monthView

            Row {
                id: weekRow
                anchors.fill: parent
                spacing: Styling.fontSize(-5)

                readonly property real cellWidth: Math.max(0, (width - spacing * 6) / 7)

                Repeater {
                    model: root.weekDays

                    delegate: Item {
                        id: weekCell
                        required property string modelData

                        readonly property var date: TasksService.dateOf(modelData)
                        readonly property int taskCount: TasksService.countOn(modelData)
                        readonly property int pendingCount: TasksService.pendingOn(modelData)
                        readonly property bool isToday: modelData === TasksService.todayKey
                        readonly property bool isSelected: modelData === root.selectedDay

                        width: weekRow.cellWidth
                        height: Math.max(0, weekRow.height)

                        StyledRect {
                            anchors.fill: parent
                            anchors.margins: Styling.fontSize(-5)
                            variant: weekCell.isToday ? "primary" : weekCell.isSelected ? "focus" : "transparent"
                            backgroundOpacity: weekCell.isToday ? 1 : weekCell.isSelected ? 0.3 : 0
                            radius: root.theme === "sticker" ? Styling.radius(-4) : Styling.radius(-6)
                            border.color: weekCell.isSelected && !weekCell.isToday ? root.accentColor : "transparent"
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDate(weekCell.date, "ddd").charAt(0)
                                color: weekCell.isToday ? root.accentTextColor : root.mutedColor
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-3)
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDate(weekCell.date, "d")
                                color: weekCell.isToday ? root.accentTextColor : root.textColor
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: weekCell.isToday ? Font.DemiBold : Font.Normal
                            }
                        }

                        StyledRect {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Styling.fontSize(-5)
                            visible: weekCell.taskCount > 0
                            width: Styling.fontSize(-4)
                            height: width
                            variant: "common"
                            radius: width / 2
                            color: weekCell.pendingCount > 0 ? root.accentColor : root.mutedColor
                            backgroundOpacity: 1
                            enableBorder: false
                        }

                        HoverHandler {
                            enabled: root.interactive
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            enabled: root.interactive
                            acceptedButtons: Qt.LeftButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.selectDay(weekCell.modelData)
                        }
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            variant: "transparent"
            enableBorder: false
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Styling.fontSize(-4)

            Text {
                Layout.fillWidth: true
                text: `${root.selectedLabel} · ${root.pendingOnDay} of ${root.dayTasks.length} to do`
                color: root.mutedColor
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        ListView {
            id: dayTaskList

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: root.taskRowHeight
            Layout.preferredHeight: Math.max(root.taskRowHeight,
                Math.min(contentHeight, root.taskRowHeight * (root.monthView ? 3 : 1)))
            clip: true
            spacing: Styling.fontSize(-5)
            boundsBehavior: Flickable.StopAtBounds
            model: root.dayTasks

            delegate: RowLayout {
                id: taskRow
                required property var modelData

                width: dayTaskList.width
                height: root.taskRowHeight
                spacing: Styling.fontSize(-4)

                FaceActionButton {
                    controlWidth: Styling.fontSize(3)
                    controlHeight: controlWidth
                    text: taskRow.modelData.state === "done" ? "✓" : "○"
                    accessibleName: taskRow.modelData.state === "done"
                        ? `Reopen ${taskRow.modelData.text || "untitled task"}`
                        : `Complete ${taskRow.modelData.text || "untitled task"}`
                    foregroundColor: root.theme === "sticker" ? root.accentTextColor : root.textColor
                    backgroundColor: taskRow.modelData.state === "done"
                        ? (root.ink?.raised ?? Colors.surfaceContainerHigh)
                        : (root.ink?.paper ?? root.ink?.raised ?? Colors.surfaceContainerHigh)
                    enabled: root.interactive
                    onClicked: TasksService.toggle(taskRow.modelData.key)
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Accessible.role: Accessible.Button
                    Accessible.name: `Open ${taskRow.modelData.text || "untitled task"}`

                    Text {
                        anchors.fill: parent
                        text: taskRow.modelData.text || "Untitled task"
                        color: taskRow.modelData.state === "done" ? root.mutedColor : root.textColor
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.strikeout: taskRow.modelData.state === "done"
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    HoverHandler {
                        enabled: root.interactive
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: root.interactive
                        acceptedButtons: Qt.LeftButton
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.openTask(taskRow.modelData.key)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.dayTasks.length === 0
                text: "Nothing planned"
                color: root.mutedColor
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Styling.fontSize(-4)

            TextField {
                id: newTask
                visible: root.fullMonth
                Layout.fillWidth: true
                placeholderText: "Add a task to this day"
                color: root.textColor
                selectionColor: root.accentColor
                selectedTextColor: root.accentTextColor
                placeholderTextColor: root.mutedColor
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                activeFocusOnTab: true
                enabled: root.interactive
                Accessible.name: `New task for ${root.selectedLabel}`
                background: StyledRect {
                    variant: "common"
                    backgroundOpacity: root.theme === "sticker" ? 0.6 : 0.38
                    radius: Styling.radius(-5)
                    border.color: newTask.activeFocus ? root.accentColor : (root.ink?.dim ?? Colors.outlineVariant)
                }
                onAccepted: root.addTask()
            }

            FaceActionButton {
                controlWidth: Styling.fontSize(4)
                controlHeight: controlWidth
                text: "+"
                accessibleName: `Add task for ${root.selectedLabel}`
                foregroundColor: root.accentTextColor
                backgroundColor: root.accentColor
                enabled: root.interactive && newTask.text.trim() !== ""
                onClicked: root.addTask()
            }
            FaceActionButton {
                visible: !root.fullMonth
                Layout.alignment: Qt.AlignRight
                controlWidth: Styling.fontSize(4)
                controlHeight: controlWidth
                text: "+"
                accessibleName: `Add task for ${root.selectedLabel}`
                foregroundColor: root.accentTextColor
                backgroundColor: root.accentColor
                enabled: root.interactive
                onClicked: root.addTask()
            }
        }

    }
}
