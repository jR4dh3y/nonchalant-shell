pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.widgets.dashboard
import "../../widgets/dashboard/widgets"

Item {
    id: root

    property string currentTime: ""
    property string currentDayAbbrev: ""
    property string currentFullDate: ""

    required property Item bar
    property bool isHovered: false

    property bool layerEnabled: false
    
    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Popup visibility state
    property bool popupOpen: clockPopup.isOpen
    readonly property bool menuOpen: dashboardPopup.isOpen
    readonly property Item dashboardHitbox: dashboardPopup.hitbox
    readonly property bool timeToolsOpen: timePopup.isOpen
    readonly property bool anyPopupOpen: popupOpen || menuOpen || timeToolsOpen

    function formatDuration(seconds) {
        const safeSeconds = Math.max(0, seconds);
        const minutes = Math.floor(safeSeconds / 60);
        const remainder = safeSeconds % 60;
        return minutes.toString().padStart(2, "0") + ":"
            + remainder.toString().padStart(2, "0");
    }

    function toggleCenterMenu() {
        if (dashboardPopup.isOpen) {
            dashboardPopup.close();
            return;
        }

        GlobalStates.dashboardCurrentTab = 0;
        // claimBarPopup closes any sibling popup (e.g. weather) in the same turn.
        dashboardPopup.open();
    }

    function toggleWallpapers() {
        if (dashboardPopup.isOpen && GlobalStates.dashboardCurrentTab === 1) {
            dashboardPopup.close();
            return;
        }

        GlobalStates.dashboardCurrentTab = 1;
        dashboardPopup.open();
    }

    readonly property bool weatherAvailable: WeatherService.dataAvailable

    implicitWidth: buttonBg.implicitWidth
    implicitHeight: 36
    Layout.preferredWidth: buttonBg.implicitWidth
    Layout.preferredHeight: 36

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // Main button
    StyledRect {
        id: buttonBg
        variant: root.anyPopupOpen ? "primary" : "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled

        topLeftRadius: root.startRadius
        topRightRadius: root.endRadius
        bottomLeftRadius: root.startRadius
        bottomRightRadius: root.endRadius

        implicitWidth: rowLayout.implicitWidth + 24
        implicitHeight: 36

        HoverTint {
            hovered: root.isHovered && !root.anyPopupOpen
        }

        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 8

            Item {
                Layout.preferredWidth: weatherDisplay.implicitWidth
                Layout.preferredHeight: 28
                scale: weatherMouse.pressed ? 0.90 : 1.0

                PressBehavior on scale {
                    pressed: weatherMouse.pressed
                }

                StyledText {
                    id: weatherDisplay
                    anchors.centerIn: parent
                    text: root.weatherAvailable
                        ? WeatherService.weatherSymbol + " " + Math.round(WeatherService.currentTemp) + "°"
                        : root.currentDayAbbrev
                    color: root.anyPopupOpen ? buttonBg.item : Colors.overBackground
                    font.pixelSize: Config.theme.fontSize
                    font.family: Config.theme.font
                    font.bold: true
                }

                MouseArea {
                    id: weatherMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // claimBarPopup closes the dashboard if it was open.
                    onClicked: clockPopup.toggle()
                }
            }

            Separator {
                id: separator
                vert: true
            }

            Item {
                Layout.preferredWidth: dateDisplay.implicitWidth
                Layout.preferredHeight: 28
                scale: dateMouse.pressed ? 0.90 : 1.0

                PressBehavior on scale {
                    pressed: dateMouse.pressed
                }

                StyledText {
                    id: dateDisplay
                    anchors.centerIn: parent
                    text: root.currentFullDate
                    color: root.anyPopupOpen ? buttonBg.item : Colors.overBackground
                    font.pixelSize: Config.theme.fontSize
                    font.family: Config.theme.font
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: dateMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleCenterMenu()
                }
            }

            Separator {
                vert: true
            }

            Item {
                id: timeAnchor
                Layout.preferredWidth: timeDisplay.implicitWidth
                // Reach the same bar edge used by the weather/dashboard
                // anchor so every clock popup has an identical visual gap.
                Layout.preferredHeight: buttonBg.height
                scale: timeMouse.pressed ? 0.90 : 1.0

                PressBehavior on scale {
                    pressed: timeMouse.pressed
                }

                StyledText {
                    id: timeDisplay
                    anchors.centerIn: parent
                    text: pomodoroWidget.isRunning || pomodoroWidget.alarmActive || pomodoroWidget.isResuming
                        ? root.formatDuration(pomodoroWidget.timeLeft)
                        : root.currentTime
                    color: root.anyPopupOpen ? buttonBg.item : Colors.overBackground
                    font.pixelSize: Config.theme.fontSize
                    font.family: Config.theme.font
                    font.bold: true
                }

                MouseArea {
                    id: timeMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton)
                            pomodoroWidget.toggleTimer();
                        else
                            timePopup.toggle();
                    }
                }
            }
        }

    }

    // Compact countdown timer.
    BarPopup {
        id: timePopup
        anchorItem: timeAnchor
        grabFocus: true

        contentWidth: 316
        contentHeight: pomodoroWidget.implicitHeight + popupPadding * 2

        onIsOpenChanged: {
            if (isOpen)
                Qt.callLater(() => pomodoroWidget.focusInput());
        }

        Pomodoro {
            id: pomodoroWidget
            width: parent.width
            height: implicitHeight
            onRequestPopupOpen: timePopup.open()
        }
    }

    // Clock & Weather popup
    BarPopup {
        id: clockPopup
        anchorItem: buttonBg
        contentWidth: popupContent.width + popupPadding * 2
        contentHeight: WeatherService.dataAvailable ? popupContent.height + popupPadding * 2 : 0

        onIsOpenChanged: {
            if (isOpen) {
                // claimBarPopup already closes siblings; only refresh weather.
                if (!WeatherService.dataAvailable)
                    WeatherService.updateWeather();
            }
        }

        Column {
            id: popupContent
            spacing: 4

            // Weather widget with sun arc
            WeatherWidget {
                id: weatherWidget
                width: 300
                height: 140
                showDebugControls: false
                animationsEnabled: clockPopup.isOpen
            }

            // 7-day forecast panel (below weather widget)
            Item {
                id: forecastPanel
                width: weatherWidget.width
                height: WeatherService.dataAvailable && WeatherService.forecast.length > 0 ? forecastContent.implicitHeight : 0
                clip: true
                visible: height > 0

                StyledRect {
                    id: forecastContent
                    variant: "pane"
                    anchors.fill: parent
                    implicitHeight: forecastRow.implicitHeight + 16

                    Row {
                        id: forecastRow
                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            model: WeatherService.forecast.slice(0, 5)

                            Row {
                                id: forecastDayRow
                                required property var modelData
                                required property int index
                                spacing: 4

                                Column {
                                    id: forecastDay
                                    spacing: 2
                                    width: (weatherWidget.width - 16 - (4 * 4) - (4 * 6)) / 5

                                    // Day name
                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: forecastDayRow.modelData.dayName
                                        color: Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        font.weight: Font.Medium
                                    }

                                    // Weather emoji
                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: forecastDayRow.modelData.emoji
                                        font.pixelSize: Styling.fontSize(4)
                                    }

                                    // Max temperature
                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: (Math.round(forecastDayRow.modelData.maxTemp) >= 0 ? "+" : "") + Math.round(forecastDayRow.modelData.maxTemp) + "\u00B0"
                                        color: Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        font.weight: Font.Bold
                                    }

                                    // Min temperature
                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: (Math.round(forecastDayRow.modelData.minTemp) >= 0 ? "+" : "") + Math.round(forecastDayRow.modelData.minTemp) + "\u00B0"
                                        color: Colors.outline
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        font.weight: Font.Normal
                                    }
                                }

                                // Separator between days (not after last)
                                Separator {
                                    vert: true
                                    visible: forecastDayRow.index < 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: forecastDay.height - 16
                                }
                            }
                        }
                    }
                }
            }

            // Debug panel (below weather widget)
            Item {
                id: debugPanel
                width: weatherWidget.width
                height: WeatherService.debugMode ? debugContent.implicitHeight : 0
                clip: true
                visible: height > 0

                ColumnLayout {
                    id: debugContent
                    anchors.fill: parent
                    spacing: 4

                    // Time slider pane
                    StyledRect {
                        variant: "pane"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36

                        StyledSlider {
                            id: sliderContent
                            anchors.fill: parent
                            anchors.margins: 12
                            icon: Icons.clock
                            value: WeatherService.debugHour / 24
                            tooltipText: {
                                var hour = Math.floor(WeatherService.debugHour);
                                var minutes = Math.round((WeatherService.debugHour - hour) * 60);
                                return hour.toString().padStart(2, '0') + ":" + minutes.toString().padStart(2, '0');
                            }
                            onValueChanged: WeatherService.debugHour = value * 24
                        }
                    }

                    // Weather type selector pane
                    StyledRect {
                        id: weatherSelector
                        variant: "pane"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64 + 8

                        readonly property int buttonPadding: 4
                        readonly property int buttonSpacing: 2

                        readonly property var weatherTypes: [
                            {
                                code: 0,
                                icon: "☀️",
                                name: "Clear"
                            },
                            {
                                code: 1,
                                icon: "🌤️",
                                name: "Mainly clear"
                            },
                            {
                                code: 2,
                                icon: "⛅",
                                name: "Partly cloudy"
                            },
                            {
                                code: 3,
                                icon: "☁️",
                                name: "Overcast"
                            },
                            {
                                code: 45,
                                icon: "🌫️",
                                name: "Fog"
                            },
                            {
                                code: 51,
                                icon: "🌦️",
                                name: "Drizzle"
                            },
                            {
                                code: 61,
                                icon: "🌧️",
                                name: "Rain"
                            },
                            {
                                code: 65,
                                icon: "🌧️",
                                name: "Heavy rain"
                            },
                            {
                                code: 71,
                                icon: "❄️",
                                name: "Snow"
                            },
                            {
                                code: 75,
                                icon: "❄️",
                                name: "Heavy snow"
                            },
                            {
                                code: 95,
                                icon: "⛈️",
                                name: "Thunder"
                            },
                            {
                                code: 96,
                                icon: "🌩️",
                                name: "Hail"
                            }
                        ]

                        readonly property int columns: 6
                        readonly property int rows: Math.ceil(weatherTypes.length / columns)

                        Grid {
                            id: weatherButtonsGrid
                            anchors.fill: parent
                            anchors.margins: weatherSelector.buttonPadding
                            columns: weatherSelector.columns
                            rowSpacing: weatherSelector.buttonSpacing
                            columnSpacing: weatherSelector.buttonSpacing

                            Repeater {
                                model: weatherSelector.weatherTypes

                                delegate: StyledRect {
                                    id: weatherBtn
                                    required property var modelData
                                    required property int index

                                    readonly property bool isSelected: WeatherService.debugWeatherCode === modelData.code
                                    readonly property int row: Math.floor(index / weatherSelector.columns)
                                    readonly property int col: index % weatherSelector.columns
                                    readonly property bool isFirstCol: col === 0
                                    readonly property bool isLastCol: col === weatherSelector.columns - 1
                                    readonly property bool isFirstRow: row === 0
                                    readonly property bool isLastRow: row === weatherSelector.rows - 1
                                    property bool buttonHovered: false

                                    readonly property real defaultRadius: Styling.radius(0)
                                    readonly property real selectedRadius: Styling.radius(0) / 2

                                    readonly property real gridWidth: weatherButtonsGrid.width
                                    readonly property real gridHeight: weatherButtonsGrid.height

                                    variant: isSelected ? "primary" : (buttonHovered ? "focus" : "internalbg")
                                    enableShadow: false
                                    width: (gridWidth - (weatherSelector.columns - 1) * weatherSelector.buttonSpacing) / weatherSelector.columns
                                    height: (gridHeight - (weatherSelector.rows - 1) * weatherSelector.buttonSpacing) / weatherSelector.rows

                                    topLeftRadius: isSelected ? (isFirstCol && isFirstRow ? defaultRadius : selectedRadius) : defaultRadius
                                    topRightRadius: isSelected ? (isLastCol && isFirstRow ? defaultRadius : selectedRadius) : defaultRadius
                                    bottomLeftRadius: isSelected ? (isFirstCol && isLastRow ? defaultRadius : selectedRadius) : defaultRadius
                                    bottomRightRadius: isSelected ? (isLastCol && isLastRow ? defaultRadius : selectedRadius) : defaultRadius

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: weatherBtn.modelData.icon
                                        font.pixelSize: 14
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: weatherBtn.buttonHovered = true
                                        onExited: weatherBtn.buttonHovered = false
                                        onClicked: WeatherService.debugWeatherCode = weatherBtn.modelData.code
                                    }

                                    StyledToolTip {
                                        show: weatherBtn.buttonHovered
                                        tooltipText: weatherBtn.modelData.name
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Keep the dashboard on the unified layer-shell surface. Niri sends
    // keyboard input to that surface; a child PopupWindow can paint and take
    // pointer input while key events continue to the client underneath.
    Item {
        id: dashboardPopup
        parent: root.bar

        property bool isOpen: false
        readonly property bool bottomBar: (Config.bar?.position ?? "top") === "bottom"
        readonly property int edgeGap: 8
        readonly property real barClearance: root.bar.totalBarHeight + edgeGap
        readonly property Item hitbox: dashboardSurface.fullyHidden ? null : dashboardSurface.body

        z: 1000
        x: 0
        y: bottomBar ? 0 : barClearance
        width: parent.width
        height: Math.max(0, parent.height - barClearance)
        visible: isOpen || !dashboardSurface.fullyHidden

        function open() {
            if (isOpen)
                return;
            Visibilities.claimBarPopup(dashboardPopup);
            isOpen = true;
            Qt.callLater(() => {
                if (dashboardPopup.isOpen && dashboardLoader.item)
                    dashboardLoader.item.focusCurrentTab();
            });
        }

        function close() {
            if (!isOpen)
                return;
            isOpen = false;
            Visibilities.releaseBarPopup(dashboardPopup);
        }

        FocusGrab {
            active: dashboardPopup.isOpen
            windows: []
            onCleared: dashboardPopup.close()
        }

        onIsOpenChanged: {
            const screenName = root.bar?.screen?.name ?? "";
            if (isOpen) {
                GlobalStates.dashboardPopupScreen = screenName;
            } else if (GlobalStates.dashboardPopupScreen === screenName) {
                GlobalStates.dashboardPopupScreen = "";
            }
        }

        MorphSurface {
            id: dashboardSurface

            shown: dashboardPopup.isOpen
            contentWidth: dashboardLoader.item ? dashboardLoader.item.implicitWidth + padding * 2 : 916
            contentHeight: dashboardLoader.item ? dashboardLoader.item.implicitHeight + padding * 2 : 360
            originWidth: buttonBg.width
            fromBottom: dashboardPopup.bottomBar
            x: Math.round((dashboardPopup.width - width) / 2)
            y: dashboardPopup.bottomBar ? dashboardPopup.height - height : 0

            Loader {
                id: dashboardLoader
                // Always warm: weather→dashboard must not hitch on first create.
                active: true
                anchors.fill: parent

                sourceComponent: Component {
                    DashboardView {
                        screenName: root.bar?.screen?.name ?? ""
                        popupMode: true
                        onCloseRequested: dashboardPopup.close()
                    }
                }
            }
        }
    }

    function scheduleNextDayUpdate() {
        const now = new Date();
        const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 1);
        const ms = next - now;
        dayUpdateTimer.interval = ms;
        dayUpdateTimer.start();
    }

    function updateDay() {
        const now = new Date();
        const day = now.toLocaleDateString(Qt.locale(), "ddd");
        root.currentDayAbbrev = day.slice(0, 3).charAt(0).toUpperCase() + day.slice(1, 3);
        root.currentFullDate = now.toLocaleDateString(Qt.locale(), "dddd, d MMMM yyyy");
        scheduleNextDayUpdate();
    }

    Timer {
        interval: 1000
        running: !SuspendManager.isSuspending
        repeat: true
        onTriggered: {
            const now = new Date();
            const format = Config.bar.use12hFormat ? "h:mm ap" : "hh:mm";
            const formatted = Qt.formatDateTime(now, format);
            root.currentTime = formatted;
        }
    }

    Timer {
        id: dayUpdateTimer
        repeat: false
        running: false
        onTriggered: updateDay()
    }

    Component.onDestruction: {
        const screenName = root.bar?.screen?.name ?? "";
        if (screenName)
            Visibilities.unregisterDashboardController(screenName, root);
        if (GlobalStates.dashboardPopupScreen === screenName)
            GlobalStates.dashboardPopupScreen = "";
    }

    Component.onCompleted: {
        const now = new Date();
        const format = Config.bar.use12hFormat ? "h:mm ap" : "hh:mm";
        const formatted = Qt.formatDateTime(now, format);
        root.currentTime = formatted;
        updateDay();

        const screenName = root.bar?.screen?.name ?? "";
        if (screenName)
            Visibilities.registerDashboardController(screenName, root);
    }
}
