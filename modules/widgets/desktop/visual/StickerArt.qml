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
    property real progress: 0
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
        const weeks = GithubService.weeks ?? []
        const days = []
        for (let week = Math.max(0, weeks.length - 4); week < weeks.length; week++) {
            const entries = weeks[week] ?? []
            for (let day = 0; day < entries.length; day++)
                days.push(entries[day])
        }
        return days
    }
    readonly property bool special: ["battery", "clock", "media", "stats", "weather", "github", "calendar", "tasks", "timer", "volume", "brightness", "network"].includes(root.moduleId)

    Text {
        anchors.centerIn: parent
        visible: !root.special
        text: root.glyph
        color: root.foreground
        font.family: Config.theme.monoFont
        font.pixelSize: root.side * 0.43
    }

    StyledRect {
        anchors.centerIn: parent
        visible: root.moduleId === "battery"
        width: root.side * 0.38
        height: root.side * 0.68
        variant: "common"
        radius: width * 0.28
        backgroundOpacity: 0.28
        enableBorder: true
        border.color: root.foreground

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: parent.width * 0.14
            height: Math.max(0, (parent.height - parent.width * 0.28) * Math.max(0, Math.min(1, root.progress)))
            radius: width / 2
            color: root.accent
        }

        Text {
            anchors.centerIn: parent
            text: Battery.available ? `${Math.round(Battery.percentage)}%` : "—"
            color: root.foreground
            font.family: Config.theme.monoFont
            font.pixelSize: root.side * 0.14
            font.weight: Font.Bold
        }
    }

    Item {
        anchors.centerIn: parent
        visible: root.moduleId === "clock"
        width: root.side * 0.84
        height: width

        Repeater {
            model: 12
            delegate: Rectangle {
                required property int index
                readonly property real angle: index * Math.PI / 6
                width: root.side * 0.025
                height: root.side * 0.075
                x: parent.width / 2 + Math.sin(angle) * parent.width * 0.39 - width / 2
                y: parent.height / 2 - Math.cos(angle) * parent.height * 0.39 - height / 2
                radius: width / 2
                rotation: index * 30
                color: root.foreground
            }
        }

        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - height
            width: root.side * 0.045
            height: root.side * 0.28
            radius: width / 2
            color: root.accent
            transformOrigin: Item.Bottom
            rotation: root.now.getMinutes() * 6
        }

        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - height
            width: root.side * 0.06
            height: root.side * 0.2
            radius: width / 2
            color: root.foreground
            transformOrigin: Item.Bottom
            rotation: (root.now.getHours() % 12) * 30 + root.now.getMinutes() / 2
        }
    }

    Item {
        anchors.centerIn: parent
        visible: root.moduleId === "media"
        width: root.side * 0.82
        height: width

        StyledRect {
            anchors.fill: parent
            variant: "common"
            radius: width / 2
            color: Colors.overBackground
            enableBorder: false

            Image {
                anchors.centerIn: parent
                width: parent.width * 0.62
                height: width
                visible: !!MprisController.activePlayer?.trackArtUrl
                source: MprisController.activePlayer?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: parent.width * 2
                sourceSize.height: parent.height * 2
            }

            StyledRect {
                anchors.centerIn: parent
                width: parent.width * 0.16
                height: width
                variant: "primary"
                radius: width / 2
                enableBorder: false
            }
        }

        StyledRect {
            anchors.centerIn: parent
            width: parent.width * 0.22
            height: width
            variant: "pane"
            radius: width / 2
            enableBorder: false
        }
    }

    Row {
        anchors.centerIn: parent
        visible: root.moduleId === "stats"
        spacing: root.side * 0.08

        Repeater {
            model: [SystemResources.cpuUsage, SystemResources.ramUsage, SystemResources.gpuUsage]
            delegate: Rectangle {
                required property int index
                required property real modelData
                width: root.side * 0.12
                height: Math.max(root.side * 0.16, root.side * 0.56 * Math.max(0.04, Math.min(1, modelData / 100)))
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: root.accent
                opacity: index === 2 && !SystemResources.gpuDetected ? 0.3 : 1
            }
        }
    }

    Column {
        anchors.centerIn: parent
        visible: root.moduleId === "weather"
        spacing: root.side * 0.01

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: WeatherService.dataAvailable ? WeatherService.effectiveWeatherSymbol : "󰅤"
            color: root.foreground
            font.family: Config.theme.monoFont
            font.pixelSize: root.side * 0.32
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: WeatherService.dataAvailable ? `${Math.round(WeatherService.currentTemp)}°` : "—"
            color: root.foreground
            font.family: Config.theme.font
            font.pixelSize: root.side * 0.17
            font.weight: Font.Bold
        }
    }

    Grid {
        anchors.centerIn: parent
        visible: root.moduleId === "github"
        columns: 5
        rowSpacing: root.side * 0.025
        columnSpacing: rowSpacing

        Repeater {
            model: root.contributionDays.slice(-25)
            delegate: StyledRect {
                required property var modelData
                readonly property int level: typeof modelData === "number" ? modelData : modelData?.level ?? 0
                width: root.side * 0.105
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
        font.pixelSize: root.side * 0.35
    }

    Row {
        anchors.centerIn: parent
        visible: root.moduleId === "calendar"
        spacing: root.side * 0.08
        Text {
            text: Qt.formatDate(root.now, "ddd")
            color: root.muted
            font.family: Config.theme.monoFont
            font.pixelSize: root.side * 0.18
        }
        Text {
            text: Qt.formatDate(root.now, "d")
            color: root.foreground
            font.family: Config.theme.monoFont
            font.pixelSize: root.side * 0.42
            font.weight: Font.Bold
        }
    }

    Column {
        anchors.centerIn: parent
        visible: root.moduleId === "tasks"
        spacing: root.side * 0.08

        Repeater {
            model: TasksService.queue.slice(0, 2)
            delegate: Row {
                required property var modelData
                spacing: root.side * 0.06
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
                    width: root.side * 0.48
                    text: modelData.text
                    color: root.foreground
                    font.family: Config.theme.font
                    font.pixelSize: root.side * 0.12
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
        text: "Nothing due"
        color: root.foreground
        font.family: Config.theme.font
        font.pixelSize: root.side * 0.12
    }

    Item {
        anchors.centerIn: parent
        visible: root.moduleId === "timer"
        width: root.side * 0.66
        height: width

        Gauge {
            anchors.fill: parent
            thickness: root.side * 0.055
            value: TimerService.progress
            trackColor: root.muted
            fillColor: root.accent
        }
        Text {
            anchors.centerIn: parent
            text: TimerService.display || "⌛"
            color: root.foreground
            font.family: Config.theme.monoFont
            font.pixelSize: root.side * 0.13
            font.weight: Font.DemiBold
        }
    }

    Item {
        anchors.centerIn: parent
        visible: root.moduleId === "volume" || root.moduleId === "brightness" || root.moduleId === "network"
        width: root.side * 0.76
        height: width

        Gauge {
            anchors.fill: parent
            visible: root.moduleId !== "network"
            thickness: root.side * 0.05
            value: root.progress
            trackColor: root.muted
            fillColor: root.accent
        }
        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: root.foreground
            font.family: Config.theme.monoFont
            font.pixelSize: root.side * 0.31
        }
    }
}
