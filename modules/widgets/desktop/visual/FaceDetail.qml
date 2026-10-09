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
    property string family: "4x2"
    property var ink
    property date now: new Date(0)
    property bool showMediaArt: true
    property var row: null
    property string theme: "modern"
    property bool interactive: false

    readonly property bool large: root.family === "4x4"
    readonly property color textColor: root.ink?.text ?? Colors.overBackground
    readonly property color mutedColor: root.ink?.muted ?? Colors.overSurfaceVariant
    readonly property color accentColor: root.ink?.accent ?? Colors.primary
    readonly property var forecast: WeatherService.dataAvailable
        ? WeatherService.forecast.slice(0, root.large ? 4 : 3) : []
    readonly property var contributionDays: {
        const all = []
        const weeks = GithubService.weeks ?? []
        for (let week = Math.max(0, weeks.length - 6); week < weeks.length; week++) {
            const days = weeks[week] ?? []
            for (let day = 0; day < days.length; day++)
                all.push(days[day])
        }
        return all
    }
    readonly property string petGlyph: {
        switch (Config.desktop.petStyle) {
        case "plush": return "◉‿◉"
        case "paper": return "◕"
        case "pixel": return "▦"
        default: return "◕"
        }
    }
    readonly property string lastGameName: {
        const game = GamesService.catalogue.find(item => item.id === GamesService.lastPlayed)
        return game?.name ?? ""
    }


    function openTask(key: string): void {
        if (!root.interactive || !root.row || !TasksService.entry(key))
            return
        const taskRow = Object.assign({}, root.row, { task: key })
        if (DesktopWidgetService.openDetail("tasks", taskRow))
            TasksService.open(key)
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "weather"

        Row {
            anchors.fill: parent
            spacing: Styling.fontSize(-3)

            Repeater {
                model: root.forecast

                delegate: Column {
                    required property var modelData
                    width: (parent.width - (root.forecast.length - 1) * parent.spacing) / Math.max(1, root.forecast.length)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Styling.fontSize(-4)

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.dayName
                        color: root.mutedColor
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-3)
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.emoji
                        color: root.textColor
                        font.family: Config.theme.monoFont
                        font.pixelSize: root.large ? Styling.monoFontSize(6) : Styling.monoFontSize(2)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${Math.round(modelData.maxTemp)}°`
                        color: root.textColor
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-2)
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.forecast.length === 0
            text: "Forecast unavailable"
            color: root.mutedColor
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "stats"

        Column {
            anchors.fill: parent
            spacing: Styling.fontSize(-1)

            Repeater {
                model: [
                    { label: "CPU", value: SystemResources.cpuUsage / 100, reading: `${Math.round(SystemResources.cpuUsage)}%` },
                    { label: "Memory", value: SystemResources.ramUsage / 100, reading: `${Math.round(SystemResources.ramUsage)}%` },
                    { label: "GPU", value: SystemResources.gpuUsage / 100, reading: SystemResources.gpuDetected ? `${Math.round(SystemResources.gpuUsage)}%` : "—" }
                ]

                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: Styling.fontSize(-4)

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width * 0.5
                            text: modelData.label
                            color: root.mutedColor
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                        }
                        Text {
                            width: parent.width * 0.5
                            text: modelData.reading
                            horizontalAlignment: Text.AlignRight
                            color: root.textColor
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(-2)
                        }
                    }
                    UsageBar { width: parent.width; progress: modelData.value; fillColor: root.accentColor }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "github"

        Grid {
            anchors.centerIn: parent
            width: parent.width
            height: root.contributionDays.length === 0 ? 0
                : Math.min(parent.height, Math.ceil(root.contributionDays.length / 7) * (cellSide + cellGap) - cellGap)
            columns: 7
            rowSpacing: cellGap
            columnSpacing: cellGap

            readonly property real cellGap: Styling.fontSize(-5)
            readonly property real cellSide: Math.min(Styling.fontSize(-1), (width - 6 * cellGap) / 7)

            Repeater {
                model: root.contributionDays

                delegate: StyledRect {
                    required property var modelData
                    readonly property int level: typeof modelData === "number" ? modelData : modelData?.level ?? 0
                    width: parent.cellSide
                    height: width
                    variant: "common"
                    radius: Styling.radius(-7)
                    enableBorder: false
                    color: level <= 0 ? (root.ink?.dim ?? Colors.surfaceVariant)
                        : level === 1 ? (root.ink?.green ?? Colors.greenContainer)
                        : level === 2 ? Colors.green : root.accentColor
                }
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            text: GithubService.available ? `${GithubService.totalLabel} · ${GithubService.streak} day streak` : "No contribution data"
            color: root.mutedColor
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "media"

        Row {
            id: mediaInfo
            anchors.fill: parent
            anchors.bottomMargin: mediaControls.visible
                ? mediaControls.height + Styling.fontSize(-4) : 0
            spacing: Styling.fontSize(0)

            StyledRect {
                width: root.showMediaArt && MprisController.activePlayer?.trackArtUrl
                    ? Math.min(parent.height, parent.width * 0.36) : 0
                height: parent.height
                visible: root.showMediaArt && !!MprisController.activePlayer?.trackArtUrl
                variant: "pane"
                radius: Styling.radius(-3)
                enableBorder: false

                Image {
                    anchors.fill: parent
                    source: MprisController.activePlayer?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: parent.width * 2
                    sourceSize.height: parent.height * 2
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (root.showMediaArt && MprisController.activePlayer?.trackArtUrl ? parent.height * 0.36 : 0) - Styling.fontSize(0)
                spacing: Styling.fontSize(-2)

                Text {
                    width: parent.width
                    text: MprisController.trackTitle || "Nothing playing"
                    color: root.textColor
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
                Text {
                    width: parent.width
                    text: MprisController.trackArtists
                    visible: text !== ""
                    color: root.mutedColor
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    elide: Text.ElideRight
                }
                UsageBar { width: parent.width; progress: MprisController.progress; fillColor: root.accentColor }
            }
        }
        MediaTransport {
            id: mediaControls
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            visible: root.family === "4x2" || root.large
            buttonSize: Math.min(Styling.fontSize(4), parent.height * 0.24)
            foregroundColor: root.textColor
            accentColor: root.accentColor
            accentTextColor: root.ink?.accentText ?? Colors.overPrimary
            surfaceColor: root.ink?.raised ?? Colors.surfaceContainerHigh
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "timer"

        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: timerControls.visible ? -timerControls.height * 0.5 : 0
            spacing: Styling.fontSize(0)

            Gauge {
                width: Math.min(parent.height, parent.width * 0.42)
                height: width
                value: TimerService.progress
                trackColor: root.ink?.dim ?? Colors.surfaceVariant
                fillColor: root.accentColor
                Text {
                    anchors.centerIn: parent
                    text: TimerService.display
                    color: root.textColor
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-1)
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - parent.height * 0.42 - Styling.fontSize(0)
                Text {
                    width: parent.width
                    text: TimerService.label || "Countdown"
                    color: root.textColor
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: TimerService.running ? (TimerService.paused ? "Paused" : "Running") : "Ready"
                    color: root.mutedColor
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                }
            }
        }
        TimerControls {
            id: timerControls
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            visible: root.family === "4x2"
            buttonSize: Math.min(Styling.fontSize(4), parent.height * 0.28)
            foregroundColor: root.textColor
            accentColor: root.accentColor
            accentTextColor: root.ink?.accentText ?? Colors.overPrimary
            surfaceColor: root.ink?.raised ?? Colors.surfaceContainerHigh
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "claude" || root.moduleId === "codex"

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: Styling.fontSize(0)

            Text {
                width: parent.width
                text: root.moduleId === "claude" ? (ClaudeService.available ? `Session · ${ClaudeService.percent(ClaudeService.sessionFraction)}` : "No usage found") : (CodexService.available ? `${CodexService.fullestName} · ${CodexService.figure}` : "No usage found")
                color: root.textColor
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                elide: Text.ElideRight
            }
            UsageBar {
                width: parent.width
                progress: root.moduleId === "claude" ? ClaudeService.gauge : CodexService.gauge
                fillColor: root.moduleId === "claude" ? Colors.tertiary : Colors.blue
            }
            Text {
                width: parent.width
                text: root.moduleId === "claude" ? ClaudeService.resetsIn : CodexService.windowLine(CodexService.fullest)
                color: root.mutedColor
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                elide: Text.ElideRight
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "tasks"

        Column {
            anchors.fill: parent
            spacing: Styling.fontSize(-2)

            Repeater {
                model: TasksService.queue.slice(0, root.large ? 4 : 3)

                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: Styling.fontSize(-2)

                    Text {
                        id: stateGlyph
                        width: Styling.fontSize(3)
                        text: modelData.state === "done" ? "󰄲" : modelData.state === "doing" ? "󰪡" : "󰄱"
                        color: modelData.state === "done" ? root.mutedColor : root.accentColor
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(0)

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
                        width: parent.width - parent.spacing - stateGlyph.width
                        text: modelData.text
                        color: root.textColor
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
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

            Text {
                visible: TasksService.queue.length === 0
                text: "Nothing due"
                color: root.mutedColor
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "clock"

        Row {
            anchors.centerIn: parent
            spacing: Styling.fontSize(0)

            Text {
                text: Qt.formatDate(root.now, "ddd")
                color: root.mutedColor
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.fontSize(0)
            }
            Text {
                text: Qt.formatDate(root.now, "d")
                color: root.textColor
                font.family: Config.theme.monoFont
                font.pixelSize: root.large ? Styling.fontSize(12) : Styling.fontSize(6)
                font.weight: Font.DemiBold
            }
            Text {
                text: Qt.formatDate(root.now, "MMMM")
                color: root.accentColor
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
            }
        }
    }

    CalendarTasksView {
        anchors.fill: parent
        visible: root.moduleId === "calendar"
        family: root.family
        theme: root.theme
        ink: root.ink
        row: root.row
        interactive: root.interactive
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "pet"

        Row {
            anchors.centerIn: parent
            spacing: Styling.fontSize(0)

            Text {
                text: root.petGlyph
                color: root.accentColor
                font.family: Config.theme.monoFont
                font.pixelSize: root.large ? Styling.monoFontSize(16) : Styling.monoFontSize(8)
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: root.width * 0.68
                Text {
                    width: parent.width
                    text: PetService.name || "New egg"
                    color: root.textColor
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: PetService.hatched ? `Level ${PetService.level}` : "Not hatched yet"
                    color: root.mutedColor
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                }
                UsageBar { width: parent.width; progress: PetService.progress; fillColor: root.accentColor }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "updates"

        Column {
            anchors.fill: parent
            spacing: Styling.fontSize(-2)
            Repeater {
                model: UpdatesService.packages.slice(0, root.large ? 5 : 3)
                delegate: Text {
                    required property string modelData
                    width: parent.width
                    text: `↻  ${modelData}`
                    color: root.textColor
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-2)
                    elide: Text.ElideRight
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "network" || root.moduleId === "bluetooth" || root.moduleId === "brightness" || root.moduleId === "volume" || root.moduleId === "battery"

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: Styling.fontSize(-1)

            UsageBar {
                width: parent.width
                progress: root.moduleId === "network" ? (NetworkService.wifiConnected ? NetworkService.networkStrength / 100 : NetworkService.ethernet ? 1 : 0)
                    : root.moduleId === "bluetooth" ? (BluetoothService.enabled ? 1 : 0)
                    : root.moduleId === "brightness" ? (Brightness.monitors[0]?.brightness ?? 0)
                    : root.moduleId === "volume" ? Audio.value
                    : Battery.available ? Battery.percentage / 100 : 0
                fillColor: root.moduleId === "battery" && Battery.available && Battery.percentage <= 20 ? Colors.red : root.accentColor
            }

            Text {
                width: parent.width
                text: root.moduleId === "network" ? (NetworkService.wifiConnected ? `${NetworkService.networkStrength}% signal` : NetworkService.ethernet ? "Ethernet connection" : "No connection")
                    : root.moduleId === "bluetooth" ? `${BluetoothService.connectedDevices} devices`
                    : root.moduleId === "brightness" ? (Brightness.monitors[0] ? `${Math.round(Brightness.monitors[0].brightness * 100)}% backlight` : "No backlight")
                    : root.moduleId === "volume" ? ((Audio.sink?.audio?.muted ?? true) ? "Muted" : `${Math.round(Audio.value * 100)}% volume`)
                    : Battery.available ? (Battery.isCharging ? "Charging" : Battery.timeToEmpty) : "No battery"
                color: root.mutedColor
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                elide: Text.ElideRight
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.moduleId === "games"

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: Styling.fontSize(-2)
            Text {
                width: parent.width
                text: root.lastGameName !== "" ? `Last · ${root.lastGameName}` : "The arcade is ready"
                color: root.textColor
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: `${GamesService.totalPlays} rounds played`
                color: root.mutedColor
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
            }
        }
    }

}