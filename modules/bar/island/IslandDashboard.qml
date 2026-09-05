pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.bar.systray
import qs.config

Item {
    id: root

    implicitWidth: 400
    implicitHeight: mainColumn.implicitHeight + 28

    signal openPower()
    signal openSound()
    signal openMic()
    signal openWifi()
    signal openBluetooth()
    signal openStats()
    signal openAlerts()
    signal openWallpapers()
    signal openBattery()
    signal openWeather()

    property ShellScreen screen: null

    readonly property var currentMonitor: {
        if (root.screen)
            return Brightness.getMonitorForScreen(root.screen);
        const focused = NiriService.focusedMonitor;
        if (focused)
            return Brightness.getMonitorForScreen(focused);
        return Brightness.monitors.length > 0 ? Brightness.monitors[0] : null;
    }
    readonly property real brightnessVal: currentMonitor?.brightness ?? 0.5

    function setBrightness(val: real) {
        if (Brightness.syncBrightness) {
            for (let i = 0; i < Brightness.monitors.length; i++) {
                const m = Brightness.monitors[i];
                if (m?.ready) m.setBrightness(val);
            }
        } else if (currentMonitor?.ready) {
            currentMonitor.setBrightness(val);
        }
    }

    readonly property bool audioMuted: Audio.sink?.audio?.muted ?? false
    readonly property real audioVolume: Audio.sink?.audio?.volume ?? 0.0

    readonly property bool wifiConnected: NetworkService.wifiEnabled && (NetworkService.networkName !== "" || NetworkService.active !== null || NetworkService.wifiStatus === "connected")
    readonly property string wifiSsid: NetworkService.networkName || NetworkService.active?.ssid || ""
    readonly property bool btConnected: BluetoothService.enabled && BluetoothService.connected
    readonly property string btDeviceName: {
        if (!btConnected) return "Bluetooth";
        const list = BluetoothService.friendlyDeviceList;
        if (list) {
            for (let i = 0; i < list.length; i++) {
                if (list[i]?.connected && list[i]?.name) return list[i].name;
            }
            if (list.length > 0 && list[0]?.name) {
                return list[0].name;
            }
        }
        return "Bluetooth";
    }

    readonly property int alertsCount: {
        let count = 0;
        const list = Notifications.appNameList;
        for (let i = 0; i < list.length; i++) {
            const grp = Notifications.groupsByAppName[list[i]];
            if (grp?.notifications)
                count += grp.notifications.length;
        }
        return count;
    }

    ColumnLayout {
        id: mainColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 12

        // ═══════════════════════════════════════════════════════════════
        // ROW 1: HEADER (Clock, Date, Weather + Alerts, Settings, Power)
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                spacing: 1

                RowLayout {
                    spacing: 6

                    Text {
                        id: clockText
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Qt.formatTime(new Date(), Config.bar?.use12hFormat ? "hh:mm ap" : "hh:mm")
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(4)
                        font.bold: true
                        color: Colors.overBackground

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: clockText.text = Qt.formatTime(new Date(), Config.bar?.use12hFormat ? "hh:mm ap" : "hh:mm")
                        }
                    }

                    Text {
                        id: secondsText
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Qt.formatTime(new Date(), "ss")
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 3

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: secondsText.text = Qt.formatTime(new Date(), "ss")
                        }
                    }
                }

                Text {
                    id: dateText
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Qt.formatDate(new Date(), "ddd, d MMM")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurfaceVariant
                    Layout.maximumWidth: 120
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillWidth: true }

            // Weather pill
            StyledRect {
                implicitHeight: 32
                implicitWidth: weatherRow.implicitWidth + 14
                radius: height / 2
                variant: weatherMouse.containsMouse ? "focus" : "internalbg"

                RowLayout {
                    id: weatherRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: WeatherService.weatherSymbol || Icons.sun
                        font.family: Icons.font
                        font.pixelSize: 15
                        color: Colors.yellow
                    }

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: (WeatherService.currentTemp > 0 ? Math.round(WeatherService.currentTemp) + "°C" : "24°C")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.bold: true
                        color: weatherMouse.containsMouse ? Colors.primary : Colors.overBackground
                    }
                }

                MouseArea {
                    id: weatherMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openWeather()
                }
            }

            // Alerts / Notifications button
            StyledRect {
                implicitHeight: 32
                implicitWidth: root.alertsCount > 0 ? alertsRow.implicitWidth + 14 : 32
                radius: root.alertsCount > 0 ? height / 2 : width / 2
                variant: alertsMouse.containsMouse ? "focus" : "internalbg"

                RowLayout {
                    id: alertsRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Notifications.silent ? Icons.bellZ : Icons.bell
                        font.family: Icons.font
                        font.pixelSize: 15
                        color: Notifications.silent ? Colors.primary : Colors.overBackground
                    }

                    StyledRect {
                        visible: root.alertsCount > 0
                        implicitWidth: alertBadgeText.implicitWidth + 8
                        implicitHeight: 16
                        radius: 8
                        variant: "primary"

                        Text {
                            id: alertBadgeText
                            anchors.centerIn: parent
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: String(root.alertsCount)
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(-4)
                            font.bold: true
                            color: Colors.overPrimary
                        }
                    }
                }

                MouseArea {
                    id: alertsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openAlerts()
                }
            }

            // Settings button
            StyledRect {
                implicitHeight: 32
                implicitWidth: 32
                radius: width / 2
                variant: settingsMouse.containsMouse ? "focus" : "internalbg"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.gear
                    font.family: Icons.font
                    font.pixelSize: 15
                    color: Colors.overBackground
                }

                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: GlobalStates.settingsWindowVisible = true
                }
            }

            // Power Menu trigger button
            StyledRect {
                implicitHeight: 32
                implicitWidth: 32
                radius: width / 2
                variant: powerMouse.containsMouse ? "error" : "internalbg"

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 2
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.shutdown
                    font.family: Icons.font
                    font.pixelSize: 15
                    color: powerMouse.containsMouse ? Colors.overError : Colors.red
                }

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openPower()
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // ROW 1: 2 MAIN CAPSULES (Wi-Fi & Bluetooth)
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // 1. Wi-Fi Capsule
            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 26
                variant: root.wifiConnected ? "primary" : (wifiMouse.containsMouse ? "focus" : "internalbg")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    // Left: Icon (click toggles Wi-Fi)
                    Item {
                        implicitWidth: 26
                        implicitHeight: 26
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: root.wifiConnected ? Icons.wifiHigh : (NetworkService.wifiEnabled ? Icons.wifiHigh : Icons.wifiOff)
                            font.family: Icons.font
                            font.pixelSize: 22
                            color: root.wifiConnected ? Colors.overPrimary : Colors.overBackground
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NetworkService.toggleWifi()
                        }
                    }

                    // Middle: Divider
                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignVCenter
                        color: root.wifiConnected ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(1, 1, 1, 0.15)
                    }

                    // Right: Text (click opens Wi-Fi panel)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: root.wifiConnected ? root.wifiSsid : "Wi-Fi"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: root.wifiConnected ? Colors.overPrimary : Colors.overBackground
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: wifiMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openWifi()
                        }
                    }
                }
            }

            // 2. Bluetooth Capsule
            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 26
                variant: root.btConnected ? "primary" : (btMouse.containsMouse ? "focus" : "internalbg")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    // Left: Icon (click toggles Bluetooth)
                    Item {
                        implicitWidth: 26
                        implicitHeight: 26
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: root.btConnected ? Icons.bluetoothConnected : (BluetoothService.enabled ? Icons.bluetooth : Icons.bluetoothOff)
                            font.family: Icons.font
                            font.pixelSize: 22
                            color: root.btConnected ? Colors.overPrimary : Colors.overBackground
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BluetoothService.toggle()
                        }
                    }

                    // Middle: Divider
                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignVCenter
                        color: root.btConnected ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(1, 1, 1, 0.15)
                    }

                    // Right: Text (click opens Bluetooth panel)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: root.btConnected ? root.btDeviceName : "Bluetooth"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: root.btConnected ? Colors.overPrimary : Colors.overBackground
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: btMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openBluetooth()
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // ROW 2: 5 QUICK TILES (Sound, Mic, Battery, Stats, Wallpapers)
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            id: quickTilesRow
            Layout.fillWidth: true
            spacing: Math.max(8, Math.round((quickTilesRow.width - (5 * 52)) / 4))

            // 1. Sound (Vol)
            IslandGaugeButton {
                showArc: true
                value: root.audioMuted ? 0 : root.audioVolume
                arcColor: root.audioMuted ? Colors.outlineVariant : Colors.primary
                icon: root.audioMuted ? Icons.speakerSlash : (root.audioVolume > 0.5 ? Icons.speakerHigh : (root.audioVolume > 0 ? Icons.speakerLow : Icons.speakerSlash))
                iconColor: root.audioMuted ? Colors.red : Colors.overBackground
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        Audio.toggleMute();
                    } else {
                        root.openSound();
                    }
                }
                onWheelScrolled: (delta) => {
                    if (delta > 0) Audio.incrementVolume();
                    else Audio.decrementVolume();
                }
            }

            // 2. Microphone
            IslandGaugeButton {
                readonly property bool micMuted: Audio.source?.audio?.muted ?? false
                readonly property real micVol: Audio.source?.audio?.volume ?? 0.0
                showArc: true
                value: micMuted ? 0 : micVol
                arcColor: micMuted ? Colors.outlineVariant : Colors.primary
                icon: micMuted ? Icons.micSlash : Icons.mic
                iconColor: micMuted ? Colors.red : Colors.overBackground
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        Audio.toggleMicMute();
                    } else {
                        root.openMic();
                    }
                }
                onWheelScrolled: (delta) => {
                    if (delta > 0) Audio.setMicVolume(Math.min(1.0, micVol + 0.05));
                    else Audio.setMicVolume(Math.max(0, micVol - 0.05));
                }
            }

            // 3. Battery
            IslandGaugeButton {
                showArc: Battery.available
                value: Battery.available ? (Battery.percentage / 100) : 0
                arcColor: Battery.statusColor()
                icon: Battery.isPluggedIn ? Icons.plug : Battery.getBatteryIcon()
                iconColor: Battery.isPluggedIn ? Colors.green : (Battery.percentage <= 20 ? Colors.red : Colors.overBackground)
                onClicked: (mouse) => root.openBattery()
            }

            // 4. Sysmonitor / Stats
            IslandGaugeButton {
                icon: Icons.cpu
                onClicked: (mouse) => root.openStats()
            }

            // 5. Wallpapers
            IslandGaugeButton {
                icon: Icons.image
                onClicked: (mouse) => root.openWallpapers()
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // ROW 3: BRIGHTNESS & NIGHT LIGHT SECTION
        // ═══════════════════════════════════════════════════════════════
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: Styling.radius(2)
            variant: "internalbg"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 10

                // Sun icon
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.sun
                    font.family: Icons.font
                    font.pixelSize: 18
                    color: Colors.overBackground
                }

                // Brightness slider
                StyledSlider {
                    id: brightSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    value: root.brightnessVal
                    onValueChanged: {
                        if (Math.abs(value - root.brightnessVal) > 0.01) {
                            root.setBrightness(value);
                        }
                    }
                }

                // Brightness percentage
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Math.round(root.brightnessVal * 100) + "%"
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-1)
                    font.bold: true
                    color: Colors.overBackground
                }

                // Divider
                Separator {
                    vert: true
                    Layout.preferredHeight: 20
                }

                // Night Light scrollable strength toggle
                StyledRect {
                    id: nightLightPill
                    implicitHeight: 30
                    implicitWidth: nlContentRow.implicitWidth + 14
                    radius: Styling.radius(2)
                    variant: NightLightService.active ? "primary" : (nlMouse.containsMouse ? "focus" : "common")

                    RowLayout {
                        id: nlContentRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: Icons.moon
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: NightLightService.active ? Colors.overPrimary : Colors.overBackground
                        }

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: NightLightService.active
                                ? Math.round((1.0 - NightLightService.normalizedTemperature) * 100) + "%"
                                : "Night"
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(-2)
                            font.bold: true
                            color: NightLightService.active ? Colors.overPrimary : Colors.overSurfaceVariant
                        }
                    }

                    MouseArea {
                        id: nlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NightLightService.toggle()
                        onWheel: wheel => {
                            if (!NightLightService.active) {
                                NightLightService.toggle();
                            }
                            const step = 100;
                            const delta = wheel.angleDelta.y > 0 ? -step : step;
                            NightLightService.setTemperature(NightLightService.temperature + delta);
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // ROW 4: MEDIA PLAYER CARD (Wallpaper bg + circular photo + waveform)
        // ═══════════════════════════════════════════════════════════════
        IslandMediaCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 110
        }

        // ═══════════════════════════════════════════════════════════════
        // ROW 5: INTEGRATED SYSTEM TRAY
        // ═══════════════════════════════════════════════════════════════
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Styling.radius(2)
            variant: "internalbg"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: "TRAY"
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-2)
                    font.bold: true
                    color: Colors.overSurfaceVariant
                }

                Item { Layout.fillWidth: true }

                SysTray {
                    enableShadow: false
                    startRadius: 4
                    endRadius: 4
                }
            }
        }
    }
}
