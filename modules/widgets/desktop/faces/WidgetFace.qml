pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme

import "../visual"

Item {
    id: root

    property string moduleId: ""
    property string family: "2x2"
    property var ink: DesktopWidgetService.inkFor(null)
    property var row: null
    property bool active: false
    readonly property bool statsDemand: root.active && root.moduleId === "stats"
    property bool statsSubscribed: false
    readonly property string demandService: ["claude", "codex", "github", "updates", "pet"].includes(root.moduleId)
        ? root.moduleId : ""
    property string subscribedService: ""

    function syncStatsDemand(): void {
        if (root.statsDemand === root.statsSubscribed)
            return
        root.statsSubscribed = root.statsDemand
        if (root.statsDemand)
            SystemResources.subscribe()
        else
            SystemResources.release()
    }
    function subscribeService(service: string): void {
        switch (service) {
        case "claude": ClaudeService.subscribe(); break
        case "codex": CodexService.subscribe(); break
        case "github": GithubService.subscribe(); break
        case "updates": UpdatesService.subscribe(); break
        case "pet": PetService.subscribe(); break
        }
    }

    function releaseService(service: string): void {
        switch (service) {
        case "claude": ClaudeService.release(); break
        case "codex": CodexService.release(); break
        case "github": GithubService.release(); break
        case "updates": UpdatesService.release(); break
        case "pet": PetService.release(); break
        }
    }

    function syncServiceDemand(): void {
        const wanted = root.active ? root.demandService : ""
        if (wanted === root.subscribedService)
            return
        root.releaseService(root.subscribedService)
        root.subscribedService = wanted
        root.subscribeService(wanted)
    }

    onStatsDemandChanged: root.syncStatsDemand()
    onDemandServiceChanged: root.syncServiceDemand()
    onActiveChanged: root.syncServiceDemand()
    Component.onCompleted: {
        root.syncStatsDemand()
        root.syncServiceDemand()
    }
    Component.onDestruction: {
        if (root.statsSubscribed)
            SystemResources.release()
        root.releaseService(root.subscribedService)
    }

    readonly property bool large: root.family === "4x4"
    readonly property bool band: root.family === "8x2"
    readonly property real padding: root.width > 300 ? 22 : 16
    readonly property real progress: {
        switch (root.moduleId) {
        case "battery": return Battery.available ? Battery.percentage / 100 : 0
        case "volume": return Math.max(0, Math.min(1, Audio.value))
        case "brightness": return Brightness.monitors.length > 0 ? Brightness.monitors[0].brightness : 0
        case "network": return NetworkService.wifiConnected ? NetworkService.networkStrength / 100 : NetworkService.ethernet ? 1 : 0
        case "updates": return Math.min(1, UpdatesService.count / 20)
        case "weather": return WeatherService.dataAvailable ? 0.65 : 0
        case "github": return Math.min(1, GithubService.total / 500)
        case "stats": return SystemResources.cpuUsage / 100
        case "claude": return ClaudeService.available ? ClaudeService.gauge : 0
        case "codex": return CodexService.available ? CodexService.gauge : 0
        case "timer": return TimerService.progress
        case "pet": return PetService.progress
        case "games": return Math.min(1, GamesService.totalPlays / 50)
        case "media": return MprisController.progress
        case "calendar": return clock.date.getDate() / 31

        case "tasks": return Math.min(1, TasksService.pending / 10)
        default: return 0
        }
    }
    readonly property string label: {
        switch (root.moduleId) {
        case "battery": return "Battery"
        case "volume": return "Volume"
        case "brightness": return "Brightness"
        case "network": return "Network"
        case "bluetooth": return "Bluetooth"
        case "updates": return "Updates"
        case "weather": return "Weather"
        case "github": return "GitHub"
        case "stats": return "System"
        case "claude": return "Claude"
        case "codex": return "Codex"
        case "timer": return "Timer"
        case "pet": return PetService.name || "Pet"
        case "games": return "Games"
        case "media": return "Now playing"
        case "clock": return "Clock"
        case "calendar": return "Calendar"
        case "tasks": return "Tasks"
        default: return "Widget"
        }
    }
    readonly property string reading: {
        switch (root.moduleId) {
        case "battery": return Battery.available ? `${Math.round(Battery.percentage)}%` : "—"
        case "volume": return Audio.ready ? ((Audio.sink?.audio?.muted ?? true) ? "Muted" : `${Math.round(Audio.value * 100)}%`) : "—"
        case "brightness": return Brightness.monitors.length > 0 ? `${Math.round(Brightness.monitors[0].brightness * 100)}%` : "—"
        case "network": return NetworkService.wifiConnected ? NetworkService.activeSsid : NetworkService.ethernet ? "Ethernet" : "Offline"
        case "bluetooth": return BluetoothService.enabled ? `${BluetoothService.connectedDevices} connected` : "Off"
        case "updates": return UpdatesService.available ? `${UpdatesService.count} pending` : UpdatesService.checking ? "Checking" : "—"
        case "weather": return WeatherService.dataAvailable ? `${Math.round(WeatherService.currentTemp)}°` : "—°"
        case "github": return GithubService.available ? GithubService.totalLabel : "—"
        case "stats": return `${Math.round(SystemResources.cpuUsage)}% CPU`
        case "claude": return ClaudeService.available ? ClaudeService.compact(ClaudeService.blockTokens) : "—"
        case "codex": return CodexService.available ? CodexService.figure : "—"
        case "timer": return TimerService.running ? TimerService.display : "Set a timer"
        case "pet": return PetService.hatched ? `Lv ${PetService.level}` : "A new egg"
        case "games": return GamesService.totalPlays > 0 ? `${GamesService.totalPlays} plays` : "Ready to play"
        case "media": return MprisController.activePlayer ? MprisController.trackTitle || "Playing" : "Nothing playing"
        case "clock": return Qt.formatDateTime(clock.date, root.clockFormat)
        case "calendar": return Qt.formatDate(clock.date, "d MMM")
        case "tasks": return `${TasksService.pending} to do`
        default: return ""
        }
    }
    readonly property string note: {
        switch (root.moduleId) {
        case "battery": return Battery.available ? (Battery.isCharging ? "charging" : Battery.timeToEmpty) : "no battery"
        case "volume": return (Audio.sink?.audio?.muted ?? true) ? "output silenced" : "output"
        case "brightness": return Brightness.monitors.length > 0 ? "backlight" : "no backlight"
        case "network": return NetworkService.vpnConnected ? `VPN · ${NetworkService.vpnName}` : NetworkService.wifiConnected ? `${NetworkService.networkStrength}% signal` : NetworkService.ethernet ? "Ethernet connection" : "not connected"
        case "bluetooth": return BluetoothService.enabled ? `${BluetoothService.connectedDevices} devices nearby` : "Bluetooth off"
        case "updates": return UpdatesService.checking ? "checking repositories" : UpdatesService.available ? (UpdatesService.count === 0 ? "up to date" : "packages to update") : "cannot check"
        case "weather": return WeatherService.dataAvailable ? WeatherService.weatherDescription : "no forecast"
        case "github": return GithubService.available ? `${GithubService.streak} day streak` : Config.desktop.githubUser.trim() === "" ? "No GitHub user set" : "GitHub is out of reach"
        case "stats": return `RAM ${Math.round(SystemResources.ramUsage)}%`
        case "claude": return ClaudeService.available ? `resets ${ClaudeService.resetsIn}` : "no usage found"
        case "codex": return CodexService.available ? CodexService.plan : "no usage found"
        case "timer": return TimerService.label || (TimerService.paused ? "paused" : "countdown")
        case "pet": return PetService.moodLine || "name your pet"
        case "games": return GamesService.lastPlayed ? `last · ${GamesService.catalogue.find(game => game.id === GamesService.lastPlayed)?.name ?? GamesService.lastPlayed}` : "choose a game"
        case "media": return MprisController.activePlayer ? MprisController.trackArtists : "Pick something to play"
        case "clock": return Qt.formatDate(clock.date, "dddd, d MMMM")
        case "calendar": return Qt.formatDate(clock.date, "dddd")
        case "tasks": return TasksService.summary
        default: return ""
        }
    }
    readonly property string glyph: {
        switch (root.moduleId) {
        case "battery": return Battery.getBatteryIcon()
        case "volume": return Audio.volumeIcon(Audio.value, Audio.sink?.audio?.muted ?? false)
        case "brightness": return "󰃠"
        case "network": return NetworkService.wifiConnected ? "󰤨" : NetworkService.ethernet ? "󰈀" : "󰤭"
        case "bluetooth": return "󰂯"
        case "updates": return "󰏖"
        case "weather": return WeatherService.dataAvailable ? WeatherService.weatherSymbol : "󰅤"
        case "github": return "󰊤"
        case "stats": return "󰻠"
        case "claude": return "◒"
        case "codex": return "◌"
        case "timer": return "󰔛"
        case "pet": return "◕"
        case "games": return "󰊗"
        case "media": return "♫"
        case "clock": return "󰥔"
        case "calendar": return "󰃭"
        case "tasks": return "󰄲"
        default: return "•"
        }
    }
    readonly property string clockFormat: {
        const time = Config.bar.use12hFormat ? "h:mm" : "HH:mm"
        return Config.desktop.clockShowsSeconds ? `${time}:ss` : time
    }
    readonly property color textColor: root.ink?.text ?? Colors.overBackground
    readonly property color mutedColor: root.ink?.muted ?? Colors.overSurfaceVariant
    readonly property color trackColor: root.ink?.dim ?? Colors.surfaceVariant
    readonly property color accentColor: root.ink?.accent ?? Colors.primary
    readonly property date now: clock.date
    readonly property bool inlineCalendar: root.moduleId === "calendar" && root.family === "4x2"

    SystemClock {
        id: clock
        precision: Config.desktop.clockShowsSeconds ? SystemClock.Seconds : SystemClock.Minutes
        enabled: root.active && (root.moduleId === "clock" || root.moduleId === "calendar")
    }

    Item {
        id: mark
        x: root.padding
        y: root.padding
        width: root.large ? 48 : 40
        height: width
        visible: !root.inlineCalendar

        StyledRect {
            anchors.fill: parent
            visible: root.visible && root.moduleId === "media" && !!MprisController.activePlayer?.trackArtUrl
            variant: "common"
            radius: Styling.radius(-4)
            enableBorder: false

            Image {
                anchors.fill: parent
                source: root.visible && root.moduleId === "media"
                    ? (MprisController.activePlayer?.trackArtUrl ?? "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: mark.width * 2
                sourceSize.height: mark.height * 2
            }
        }

        Gauge {
            anchors.fill: parent
            visible: ["battery", "volume", "brightness", "timer", "claude", "codex"].includes(root.moduleId)
            value: root.progress
            thickness: root.large ? 3.5 : 3
            trackColor: root.trackColor
            fillColor: root.moduleId === "battery" && Battery.available && Battery.percentage <= 20
                ? Colors.red : root.accentColor
        }

        Text {
            anchors.centerIn: parent
            visible: !(root.visible && root.moduleId === "media" && !!MprisController.activePlayer?.trackArtUrl)
            text: root.glyph
            color: root.moduleId === "battery" && Battery.available && Battery.percentage <= 20
                ? Colors.red : root.textColor
            font.family: Config.theme.monoFont
            font.pixelSize: root.large ? Styling.monoFontSize(8) : Styling.monoFontSize(5)
        }
    }

    Text {
        id: name
        visible: !root.inlineCalendar
        anchors.left: mark.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.padding + 4
        anchors.rightMargin: root.padding
        text: root.label
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        font.weight: Font.DemiBold
        color: root.mutedColor
    }

    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: mark.bottom
        anchors.bottom: readings.top
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: root.large ? 12 : 0
        anchors.bottomMargin: root.large ? 10 : 0
        visible: root.large
        clip: true
        Loader {
            anchors.fill: parent
            active: root.visible && root.large
            sourceComponent: detail
        }
    }



    Column {
        id: readings
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.padding
        anchors.bottomMargin: root.padding
        visible: !root.inlineCalendar
        width: root.band || root.family === "4x2" ? parent.width * (root.band ? 0.58 : 0.56) : parent.width - root.padding * 2
        spacing: 2

        Text {
            width: parent.width
            text: root.reading
            elide: Text.ElideRight
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Styling.fontSize(1)
            font.family: Config.theme.font
            font.pixelSize: root.band ? Styling.fontSize(14) : root.large ? Styling.fontSize(10) : Styling.fontSize(7)
            font.weight: Font.DemiBold
            color: root.textColor
        }

        Text {
            width: parent.width
            visible: root.note !== ""
            text: root.note
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: root.mutedColor
        }
    }

    Item {
        id: wideMark
        visible: root.band || root.family === "4x2"
        x: root.inlineCalendar ? root.padding : parent.width - root.padding - width
        y: root.inlineCalendar ? root.padding : name.y + name.height + 10
        width: root.inlineCalendar ? parent.width - root.padding * 2
            : root.band ? parent.width * 0.32 : parent.width * 0.38
        height: parent.height - y - root.padding

        Loader {
            anchors.fill: parent
            active: root.visible && (root.band || root.family === "4x2")
            sourceComponent: detail
        }
    }

    Component {
        id: detail
        FaceDetail {
            anchors.fill: parent
            moduleId: root.moduleId
            family: root.family
            ink: root.ink
            now: root.now
            theme: "modern"
            row: root.row
            interactive: root.active
        }
    }

}
