pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme

Item {
    id: root

    property string moduleId: ""
    property string glyph: "•"
    property date now: new Date(0)
    property color foreground: Colors.overBackground
    property color accent: Colors.primary
    property color muted: Colors.overSurfaceVariant
    property var row: null
    property bool interactive: false

    function openTask(key: string): void {
        if (!root.interactive || !root.row || !TasksService.entry(key))
            return
        const taskRow = Object.assign({}, root.row, { task: key })
        if (DesktopWidgetService.openDetail("tasks", taskRow))
            TasksService.open(key)
    }

    readonly property real side: Math.min(root.width, root.height)
    readonly property var contributionDays: {
        if (root.moduleId !== "github")
            return []
        const weeks = GithubService.weeks ?? []
        const days = []
        for (let week = Math.max(0, weeks.length - 5); week < weeks.length; week++) {
            const entries = weeks[week] ?? []
            for (let day = 0; day < entries.length; day++)
                days.push(entries[day])
        }
        return days
    }
    readonly property bool special: ["clock", "media", "battery", "stats", "github", "calendar", "tasks", "network", "timer"].includes(root.moduleId)

    Text {
        anchors.centerIn: parent
        visible: !root.special
        text: root.glyph
        color: root.foreground
        font.family: Config.theme.monoFont
        font.pixelSize: root.side * 0.3
    }

    Grid {
        anchors.centerIn: parent
        visible: root.moduleId === "github"
        columns: 5
        rowSpacing: root.side * 0.025
        columnSpacing: rowSpacing

        Repeater {
            model: root.moduleId === "github" ? root.contributionDays.slice(-25) : []
            delegate: StyledRect {
                required property var modelData
                readonly property int level: typeof modelData === "number" ? modelData : modelData?.level ?? 0
                width: root.side * 0.09
                height: width
                variant: "common"
                radius: Styling.radius(-7)
                enableBorder: false
                color: level <= 0 ? root.muted : level === 1 ? root.accent : Colors.green
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.moduleId === "github" && root.contributionDays.length === 0
        text: root.glyph
        color: root.foreground
        font.family: Config.theme.monoFont
        font.pixelSize: root.side * 0.34
    }

    StyledRect {
        anchors.centerIn: parent
        visible: root.moduleId === "calendar"
        width: root.side * 0.56
        height: root.side * 0.68
        variant: "common"
        radius: Styling.radius(-5)
        backgroundOpacity: 0.5
        enableBorder: false

        StyledRect {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height * 0.22
            variant: "primary"
            radius: Styling.radius(-5)
            enableBorder: false
        }

        Column {
            anchors.centerIn: parent
            spacing: root.side * 0.01
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.now, "ddd")
                color: root.muted
                font.family: Config.theme.monoFont
                font.pixelSize: root.side * 0.11
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.now, "d")
                color: root.foreground
                font.family: Config.theme.monoFont
                font.pixelSize: root.side * 0.28
                font.weight: Font.Bold
            }
        }
    }

    Column {
        anchors.centerIn: parent
        visible: root.moduleId === "tasks"
        width: root.side * 0.68
        spacing: root.side * 0.05

        Repeater {
            model: root.moduleId === "tasks" ? TasksService.queue.slice(0, 3) : []
            delegate: Row {
                required property var modelData
                width: parent.width
                spacing: root.side * 0.04
                Text {
                    text: modelData.state === "done" ? "✓" : "○"
                    color: root.accent
                    font.pixelSize: root.side * 0.14

                    HoverHandler {
                        enabled: root.interactive
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: root.interactive
                        acceptedButtons: Qt.LeftButton
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: TasksService.toggle(modelData.key)
                    }
                }
                Text {
                    width: parent.width - root.side * 0.19
                    text: modelData.text
                    color: root.foreground
                    font.family: Config.theme.font
                    font.pixelSize: root.side * 0.1
                    elide: Text.ElideRight

                    HoverHandler {
                        enabled: root.interactive
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: root.interactive
                        acceptedButtons: Qt.LeftButton
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.openTask(modelData.key)
                    }
                }
            }
        }
    }
    Text {
        anchors.centerIn: parent
        visible: root.moduleId === "tasks" && TasksService.queue.length === 0
        text: root.glyph
        color: root.muted
        font.family: Config.theme.monoFont
        font.pixelSize: root.side * 0.32
    }

    Row {
        anchors.centerIn: parent
        visible: root.moduleId === "network"
        spacing: root.side * 0.04

        Repeater {
            model: 4
            delegate: StyledRect {
                required property int index
                width: root.side * 0.1
                height: root.side * (0.24 + index * 0.12)
                anchors.verticalCenter: parent.verticalCenter
                variant: "common"
                radius: Styling.radius(-7)
                backgroundOpacity: root.moduleId === "network"
                    && (NetworkService.wifiConnected || NetworkService.ethernet) ? 1 : 0.28
                enableBorder: false
                color: root.accent
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.moduleId === "timer"
        text: root.moduleId === "timer"
            ? (TimerService.running ? TimerService.display : root.glyph) : root.glyph
        color: root.foreground
        font.family: Config.theme.monoFont
        font.pixelSize: root.side * 0.15
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
}
