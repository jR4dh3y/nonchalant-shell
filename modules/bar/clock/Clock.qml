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

    IpcHandler {
        target: "dashboard-animation-debug"

        function open(): void {
            if (!dashboardPopup.isOpen)
                root.toggleCenterMenu();
        }

        function close(): void {
            if (dashboardPopup.isOpen)
                dashboardPopup.close();
        }

        function toggle(): void {
            root.toggleCenterMenu();
        }
    }

    property string currentTime: ""
    property string currentDayAbbrev: ""
    property string currentFullDate: ""

    required property var bar
    property bool isHovered: false
    property bool layerEnabled: false
    
    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Popup visibility state
    property bool popupOpen: clockPopup.isOpen
    readonly property bool menuOpen: dashboardPopup.isOpen
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

        // Warm the dashboard so the open frame already has real size.
        GlobalStates.dashboardCurrentTab = 0;
        dashboardLoader.active = true;
        // Single open path: claimBarPopup quick-closes weather and opens
        // dashboard in the same turn (no double-close / callLater hitch).
        dashboardPopup.open();
    }

    function toggleWallpapers() {
        if (dashboardPopup.isOpen && GlobalStates.dashboardCurrentTab === 1) {
            dashboardPopup.close();
            return;
        }

        GlobalStates.dashboardCurrentTab = 1;
        dashboardLoader.active = true;
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

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.anyPopupOpen ? 0 : (root.isHovered ? 0.25 : 0)
            radius: parent.radius ?? 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 8

            Item {
                Layout.preferredWidth: weatherDisplay.implicitWidth
                Layout.preferredHeight: 28

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
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
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // claimBarPopup quick-closes dashboard if it was open.
                    onClicked: {
                        if (dashboardPopup.isOpen)
                            dashboardPopup.closeQuick();
                        clockPopup.toggle();
                    }
                }
            }

            Separator {
                id: separator
                vert: true
            }

            Item {
                Layout.preferredWidth: dateDisplay.implicitWidth
                Layout.preferredHeight: 28

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    id: dateDisplay
                    anchors.centerIn: parent
                    text: root.currentFullDate
                    color: root.anyPopupOpen ? buttonBg.item : Colors.overBackground
                    font.pixelSize: Config.theme.fontSize
                    font.family: Config.theme.font
                    font.weight: Font.Medium
                }

                MouseArea {
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

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
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
        variant: "transparent"
        popupPadding: 0

        contentWidth: timeToolsWrapper.width
        contentHeight: timeToolsWrapper.height

        onIsOpenChanged: {
            if (isOpen)
                Qt.callLater(() => pomodoroWidget.focusInput());
        }

        StyledRect {
            id: timeToolsWrapper
            variant: "popup"
            radius: Styling.radius(8)
            enableShadow: false
            width: 316
            height: pomodoroWidget.implicitHeight + 16

            Pomodoro {
                id: pomodoroWidget
                anchors.centerIn: parent
                width: 300
                height: implicitHeight
                onRequestPopupOpen: timePopup.open()
            }
        }
    }

    // Clock & Weather popup
    BarPopup {
        id: clockPopup
        anchorItem: buttonBg
        variant: "transparent"
        popupPadding: 0

        contentWidth: popupColumn.width
        contentHeight: popupColumn.height

        onIsOpenChanged: {
            if (isOpen) {
                // claimBarPopup already closes siblings; only refresh weather.
                if (!WeatherService.dataAvailable)
                    WeatherService.updateWeather();
            }
        }

        // Main popup column
        Column {
            id: popupColumn
            spacing: 4

            // Weather Wrapper StyledRect
            StyledRect {
                id: popupWrapper
                variant: "popup"
                radius: Styling.radius(8)
                enableShadow: false
                width: popupContent.width + 16
                height: popupContent.height + 16
                visible: WeatherService.dataAvailable

                // Content container
                Column {
                    id: popupContent
                    anchors.centerIn: parent
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
                                            Text {
                                                renderType: Text.NativeRendering
                                                font.hintingPreference: Font.PreferFullHinting
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: forecastDayRow.modelData.dayName
                                                color: Colors.overBackground
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(0)
                                                font.weight: Font.Medium
                                            }

                                            // Weather emoji
                                            Text {
                                                renderType: Text.NativeRendering
                                                font.hintingPreference: Font.PreferFullHinting
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: forecastDayRow.modelData.emoji
                                                font.pixelSize: Styling.fontSize(4)
                                            }

                                            // Max temperature
                                            Text {
                                                renderType: Text.NativeRendering
                                                font.hintingPreference: Font.PreferFullHinting
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: (Math.round(forecastDayRow.modelData.maxTemp) >= 0 ? "+" : "") + Math.round(forecastDayRow.modelData.maxTemp) + "\u00B0"
                                                color: Colors.overBackground
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(0)
                                                font.weight: Font.Bold
                                            }

                                            // Min temperature
                                            Text {
                                                renderType: Text.NativeRendering
                                                font.hintingPreference: Font.PreferFullHinting
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

                                            Text {
                                                renderType: Text.NativeRendering
                                                font.hintingPreference: Font.PreferFullHinting
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
                                                visible: weatherBtn.buttonHovered
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

        }
    }

    // Keep the dashboard on the unified layer-shell surface. Niri sends
    // keyboard input to that surface; a child PopupWindow can paint and take
    // pointer input while key events continue to the client underneath.
    Item {
        id: dashboardPopup
        parent: root.bar

        property bool isOpen: false
        property real revealProgress: 0
        readonly property bool bottomBar: (Config.bar?.position ?? "top") === "bottom"

        z: 1000
        x: Math.round((parent.width - width) / 2)
        y: bottomBar
            ? parent.height - root.bar.totalBarHeight - dashboardWrapper.height - 8
            : root.bar.totalBarHeight + 8
        width: dashboardWrapper.width
        height: dashboardWrapper.height * revealProgress
        visible: isOpen || revealProgress > 0
        clip: true

        Behavior on revealProgress {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: dashboardPopup.isOpen ? Easing.OutCubic : Easing.InCubic
            }
        }

        function open() {
            if (isOpen)
                return;
            Visibilities.claimBarPopup(dashboardPopup);
            isOpen = true;
            revealProgress = 1;
        }

        function close() {
            if (!isOpen && revealProgress <= 0)
                return;
            isOpen = false;
            Visibilities.releaseBarPopup(dashboardPopup);
            revealProgress = 0;
        }

        function closeQuick() {
            close();
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
                Qt.callLater(() => {
                    if (dashboardPopup.isOpen && dashboardLoader.item)
                        dashboardLoader.item.focusCurrentTab();
                });
            } else if (GlobalStates.dashboardPopupScreen === screenName) {
                GlobalStates.dashboardPopupScreen = "";
            }
        }

        StyledRect {
            id: dashboardWrapper
            variant: "popup"
            radius: Styling.radius(8)
            enableShadow: false
            y: dashboardPopup.bottomBar ? dashboardPopup.height - height : 0
            // Stable size so open animation is not a 0→full expand hitch.
            width: dashboardLoader.item ? dashboardLoader.item.implicitWidth + 16 : 916
            height: dashboardLoader.item ? dashboardLoader.item.implicitHeight + 16 : 446

            Loader {
                id: dashboardLoader
                // Always warm: weather→dashboard must not hitch on first create.
                active: true
                anchors.fill: parent
                anchors.margins: 8
                // Avoid painting a heavy tree while closed.
                opacity: dashboardPopup.isOpen || dashboardPopup.visible ? 1 : 0
                enabled: dashboardPopup.isOpen || dashboardPopup.visible

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
        var now = new Date();
        var next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 1);
        var ms = next - now;
        dayUpdateTimer.interval = ms;
        dayUpdateTimer.start();
    }

    function updateDay() {
        var now = new Date();
        var day = now.toLocaleDateString(Qt.locale(), "ddd");
        root.currentDayAbbrev = day.slice(0, 3).charAt(0).toUpperCase() + day.slice(1, 3);
        root.currentFullDate = now.toLocaleDateString(Qt.locale(), "dddd, d MMMM yyyy");
        scheduleNextDayUpdate();
    }

    Timer {
        interval: 1000
        running: !SuspendManager.isSuspending
        repeat: true
        onTriggered: {
            var now = new Date();
            var format = Config.bar.use12hFormat ? "h:mm ap" : "hh:mm";
            var formatted = Qt.formatDateTime(now, format);
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
        var now = new Date();
        var format = Config.bar.use12hFormat ? "h:mm ap" : "hh:mm";
        var formatted = Qt.formatDateTime(now, format);
        root.currentTime = formatted;
        updateDay();

        const screenName = root.bar?.screen?.name ?? "";
        if (screenName)
            Visibilities.registerDashboardController(screenName, root);
    }
}
