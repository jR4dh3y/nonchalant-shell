"""Check bar rendering and transitions without touching the desktop session."""

import os
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
QML = r'''
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.bar.layouts
import qs.modules.bar.workspaces
import qs.modules.services
import qs.modules.services.compositor
import qs.modules.theme

ShellRoot {
    CompositorState { id: compositorState }
    CompositorOutput { id: testOutput; name: Quickshell.screens[0].name; focused: true }
    CompositorWorkspace {
        id: testWorkspace
        Component.onCompleted: this.id = "1"
        active: true
        output: Quickshell.screens[0].name
        windows: compositorState.windows.filter(window => window.workspaceId === "1").length
    }
    CompositorWorkspace {
        id: secondWorkspace
        Component.onCompleted: this.id = "2"
        idx: 2
        name: "2"
        isNamed: true
        output: Quickshell.screens[0].name
        windows: compositorState.windows.filter(window => window.workspaceId === "2").length
    }
    CompositorWorkspace {
        id: thirdWorkspace
        Component.onCompleted: this.id = "3"
        idx: 3
        name: "3"
        isNamed: true
        output: Quickshell.screens[0].name
        windows: compositorState.windows.filter(window => window.workspaceId === "3").length
    }
    CompositorWindow {
        id: testWindow
        Component.onCompleted: this.id = "1"
        workspaceId: "1"
        output: Quickshell.screens[0].name
        tiledAtTop: true
    }
    FloatingWindow {
        visible: true
        implicitWidth: 1200
        implicitHeight: 900
        Item { id: screenHost; property ShellScreen screen: Quickshell.screens[0] }
        Loader { id: bar; anchors.fill: parent }
        Component { id: left; LeftBar { screen: Quickshell.screens[0] } }
        Component { id: taskbar; NonchalantTaskbar { bar: screenHost } }
        Component { id: island; IslandBar { screen: Quickshell.screens[0] } }
        Component { id: pills; PillsBar { screen: Quickshell.screens[0] } }
        Process {
            id: pinCommand
            command: ["qs", "ipc", "-p", Quickshell.shellDir, "call", "nonchalant", "run", "bar-pin"]
        }
        TestCase {
            name: "BarContextText"
            when: Config.initialLoadComplete

            function findLabel(item) {
                if (String(item).startsWith("FluidTextProgress")) return item
                for (const child of item.children ?? []) {
                    const label = findLabel(child)
                    if (label) return label
                }
                return null
            }

            function verifyNoPinIcon(item) {
                if (item.text !== undefined) {
                    verify(item.text !== Icons.pin && item.text !== Icons.unpin,
                        "Bar must not render a pin toggle")
                }
                for (const child of item.children ?? []) verifyNoPinIcon(child)
            }

            function test_workspace_initialization() {
                compositorState.workspaces = [testWorkspace]
                compositorState.windows = [testWindow]
                const components = [left, taskbar, left, taskbar]
                for (let index = 0; index < components.length; index++) {
                    const component = components[index]
                    bar.sourceComponent = component
                    tryVerify(() => bar.item !== null)
                    compare(bar.item.workspaceIds.join(","), "1",
                        "A newly created switcher must populate an already loaded workspace list")
                    tryVerify(() => bar.item.activeWorkspaceButton !== null)
                    const button = bar.item.activeWorkspaceButton
                    testWorkspace.name = "Renamed " + index
                    compare(bar.item.activeWorkspaceButton, button,
                        "A metadata update must not recreate workspace delegates")
                    bar.sourceComponent = undefined
                }
                console.log("BAR_WORKSPACE_INITIALIZATION_PASSED")
            }

            function test_vertical_workspace_occupancy() {
                compositorState.workspaces = [testWorkspace, secondWorkspace, thirdWorkspace]
                testWindow.workspaceId = "2"
                compositorState.windows = [testWindow]
                bar.sourceComponent = left
                tryVerify(() => bar.item !== null)
                const occupied = findChild(bar.item, "verticalWorkspaceButton-2")
                const empty = findChild(bar.item, "verticalWorkspaceButton-3")
                verify(occupied !== undefined && empty !== undefined)
                compare(occupied.foregroundColor, Styling.srItem("overprimary"))
                compare(empty.foregroundColor, Colors.overBackground)
                compare(occupied.description, "1 window")
                const snapshots = Quickshell.env("NONCHALANT_BAR_SNAPSHOTS")
                if (snapshots) grabImage(bar.item.barHitbox).save(snapshots + "/workspace-occupancy.png")
                testWindow.workspaceId = "3"
                tryCompare(occupied, "foregroundColor", Colors.overBackground)
                tryCompare(empty, "foregroundColor", Styling.srItem("overprimary"))
                compare(occupied.description, "0 windows")
                compare(empty.description, "1 window")
                testWorkspace.active = false
                thirdWorkspace.active = true
                tryVerify(() => findChild(bar.item, "verticalWorkspaceButton-3")?.showWindows === true)
                compositorState.windows = []
                tryVerify(() => findChild(bar.item, "verticalWorkspaceButton-3")?.showLabel === true)
                thirdWorkspace.active = false
                testWorkspace.active = true
                // Changing the visible workspace set can recreate delegates.
                tryVerify(() => Qt.colorEqual(
                    findChild(bar.item, "verticalWorkspaceButton-3")?.foregroundColor ?? "transparent",
                    Colors.overBackground))
                testWindow.workspaceId = "1"
                console.log("BAR_WORKSPACE_OCCUPANCY_PASSED")
            }

            function component(item, type) {
                if (String(item).startsWith(type)) return item
                for (const child of item.children ?? []) {
                    const found = component(child, type)
                    if (found) return found
                }
                return null
            }

            function test_vertical_device_status() {
                const originalStyle = Config.bar.style
                Config.bar.style = "left"
                bar.sourceComponent = left
                tryVerify(() => bar.item !== null)
                const clock = component(bar.item, "Clock")
                const trigger = findChild(bar.item, "verticalDeviceStatusButton")
                verify(clock !== null && trigger !== undefined)
                const brightness = findChild(bar.item, "verticalBrightnessControl")
                verify(brightness !== undefined)
                verify(trigger.mapToItem(bar.item, 0, 0).y > brightness.mapToItem(bar.item, 0, brightness.height).y,
                    "Combined status belongs below brightness")
                compare(component(bar.item, "BatteryIndicator"), null,
                    "There must be no separate battery control")
                mouseClick(trigger)
                tryCompare(clock, "deviceMenuActive", true)
                compare(clock.clockSelected, false, "Device menus must not select the clock")
                compare(clock.controlMode, "wifi")
                wait(Motion.expandDuration + 100)
                const owner = Visibilities.activeBarPopup
                verify(owner !== null)
                function tab(mode) { return findChild(bar.item, "deviceStatusTab-" + mode) }
                tryVerify(() => tab("wifi") !== undefined)
                compare(tab("wifi").selected, true)
                const wifiHeight = component(bar.item, "VerticalControlMenu").implicitHeight
                mouseClick(tab("bluetooth"))
                tryCompare(clock, "controlMode", "bluetooth")
                tryVerify(() => tab("bluetooth")?.selected === true)
                compare(clock.menuOpen, true)
                compare(Visibilities.activeBarPopup, owner)
                compare(clock.clockSelected, false)
                wait(80)
                // The clicked tab is destroyed with its old panel. Keyboard
                // navigation must keep working without manually restoring focus.
                keyClick(Qt.Key_Left)
                tryCompare(clock, "controlMode", "wifi")
                keyClick(Qt.Key_Right)
                tryCompare(clock, "controlMode", "bluetooth")
                // Clicking an already selected tab keeps the popup open.
                mouseClick(tab("bluetooth"))
                compare(clock.menuOpen, true)
                mouseClick(tab("battery"))
                tryCompare(clock, "controlMode", "battery")
                tryVerify(() => tab("battery")?.selected === true)
                compare(clock.deviceMenuActive, true)
                compare(Visibilities.activeBarPopup, owner)
                compare(component(bar.item, "VerticalControlMenu").implicitHeight, wifiHeight,
                    "Device tabs must keep the flyout at the same height")
                verify(findChild(bar.item, "batteryPowerRate") !== undefined)
                verify(findChild(bar.item, "batteryHealth") !== undefined)
                const snapshots = Quickshell.env("NONCHALANT_BAR_SNAPSHOTS")
                if (snapshots) grabImage(component(bar.item, "VerticalControlMenu")).save(snapshots + "/battery-menu.png")
                compare(clock.clockSelected, false)
                // The one bar control closes every device tab and remembers it on reopen.
                mouseClick(trigger)
                tryCompare(clock, "menuOpen", false)
                compare(Visibilities.activeBarPopup, null)
                mouseClick(trigger)
                tryCompare(clock, "deviceMenuActive", true)
                compare(clock.controlMode, "battery")
                wait(Motion.expandDuration + 100)
                const menu = component(bar.item, "VerticalControlMenu")
                menu.forceActiveFocus()
                keyClick(Qt.Key_Left)
                tryCompare(clock, "controlMode", "bluetooth")
                keyClick(Qt.Key_Right)
                tryCompare(clock, "controlMode", "battery")
                // Back still dismisses the flyout; direct commands pick the right tab.
                const panel = component(bar.item, "IslandBatteryPanel")
                wait(80)
                mouseClick(panel, 28, 28)
                tryCompare(clock, "menuOpen", false)
                for (const mode of ["wifi", "bluetooth", "battery"]) {
                    clock.openControlMenu(mode)
                    tryCompare(clock, "menuOpen", true)
                    compare(clock.controlMode, mode)
                    compare(clock.clockSelected, false)
                    tryVerify(() => tab(mode)?.selected === true)
                    clock.openControlMenu(mode)
                    tryCompare(clock, "menuOpen", false)
                }
                clock.openControlMenu("wifi")
                component(bar.item, "VerticalControlMenu").forceActiveFocus()
                keyClick(Qt.Key_Escape)
                tryCompare(clock, "menuOpen", false)
                compare(Visibilities.activeBarPopup, null)
                for (const mode of ["sound", "mic", "media"]) {
                    clock.openControlMenu(mode)
                    tryCompare(clock, "menuOpen", true)
                    compare(clock.clockSelected, false, mode + " must not select the clock")
                    clock.openControlMenu(mode)
                    tryCompare(clock, "menuOpen", false)
                }
                clock.toggleCenterMenu()
                tryCompare(clock, "clockSelected", true)
                clock.toggleCenterMenu()
                tryCompare(clock, "clockSelected", false)
                Config.bar.style = originalStyle
                console.log("BAR_DEVICE_STATUS_PASSED")
            }

            function test_vertical_droplets_and_audio() {
                const originalStyle = Config.bar.style
                const originalSize = Config.theme.fontSize
                Config.bar.style = "left"
                bar.sourceComponent = left
                tryVerify(() => bar.item !== null)
                const main = findChild(bar.item, "verticalMainPill")
                const audio = findChild(bar.item, "verticalAudioControl")
                const brightness = findChild(bar.item, "verticalBrightnessDroplet")
                const status = findChild(bar.item, "verticalDeviceStatusButton")
                const clock = findChild(bar.item, "verticalClockDroplet")
                const droplets = [audio, brightness, status, clock]
                function gauges(item, found) {
                    if (String(item).startsWith("BarRadialMeter")) found.push(item)
                    for (const child of item.children ?? []) gauges(child, found)
                    return found
                }
                for (const size of [13, 22]) {
                    Config.theme.fontSize = size
                    wait(80)
                    for (const droplet of droplets) {
                        compare(droplet.width, main.width, "Droplets must match the main pill width")
                        const pillCenter = main.mapToItem(bar.item, main.width / 2, 0).x
                        const center = droplet.mapToItem(bar.item, droplet.width / 2, 0).x
                        compare(center, pillCenter)
                    }
                    verify(main.mapToItem(bar.item, 0, main.height).y
                        + bar.item.contentPadding <= audio.mapToItem(bar.item, 0, 0).y)
                    verify(clock.height > clock.width, "Clock stays elongated")
                    const meters = gauges(audio, []).concat(gauges(brightness, []), gauges(status, []))
                    compare(meters.length, 5, "Audio halves, display halves, and battery share their gauge geometry")
                    for (const meter of meters) {
                        compare(meter.controlSize, main.width)
                        compare(meter.meterRadius, meters[0].meterRadius)
                        compare(meter.lineWidth, meters[0].lineWidth)
                        compare(meter.trackColor, meters[0].trackColor)
                    }
                }
                const sound = findChild(audio, "verticalSoundControl")
                const mic = findChild(audio, "verticalMicControl")
                const soundHover = component(sound, "HoverTint")
                const micHover = component(mic, "HoverTint")
                function snapshotAudio(state) {
                    const snapshots = Quickshell.env("NONCHALANT_BAR_SNAPSHOTS")
                    if (snapshots) grabImage(bar).save(snapshots + "/audio-" + state + ".png")
                }
                mouseMove(sound, sound.width / 2, sound.height / 2)
                tryCompare(soundHover, "hovered", true)
                compare(micHover.hovered, false)
                wait(Motion.hoverDuration)
                snapshotAudio("speaker-hover")
                mouseMove(mic, mic.width / 2, mic.height / 2)
                tryCompare(micHover, "hovered", true)
                compare(soundHover.hovered, false)
                wait(Motion.hoverDuration)
                snapshotAudio("microphone-hover")
                Audio.protectionEnabled = false
                Audio.setVolume(0.4)
                Audio.setMicVolume(0.65)
                mouseWheel(sound, sound.width / 2, sound.height / 2, 0, 120)
                tryVerify(() => Math.abs(Audio.value - 0.45) < 0.001)
                compare(Audio.source.audio.volume, 0.65)
                mouseWheel(mic, mic.width / 2, mic.height / 2, 0, -120)
                tryVerify(() => Math.abs(Audio.source.audio.volume - 0.6) < 0.001)
                verify(Math.abs(Audio.value - 0.45) < 0.001)
                mouseClick(sound, sound.width / 2, sound.height / 2, Qt.RightButton)
                compare(Audio.sink.audio.muted, true)
                compare(Audio.source.audio.muted, false)
                mouseClick(mic, mic.width / 2, mic.height / 2, Qt.RightButton)
                compare(Audio.source.audio.muted, true)
                mouseClick(sound, sound.width / 2, sound.height / 2)
                tryCompare(clock, "controlMode", "sound")
                compare(clock.menuOpen, true)
                compare(sound.selected, true)
                compare(mic.selected, false)
                snapshotAudio("speaker-selected")
                mouseClick(mic, mic.width / 2, mic.height / 2)
                tryCompare(clock, "controlMode", "mic")
                compare(clock.menuOpen, true)
                compare(sound.selected, false)
                compare(mic.selected, true)
                snapshotAudio("microphone-selected")
                mouseClick(mic, mic.width / 2, mic.height / 2)
                tryCompare(clock, "menuOpen", false)
                Audio.sink.audio.muted = false
                Audio.source.audio.muted = false
                Config.theme.fontSize = originalSize
                Config.bar.style = originalStyle
                console.log("BAR_DROPLETS_AUDIO_PASSED")
            }

            function test_pin_command() {
                verify(GlobalShortcuts.ipcHandler !== null)
                Config.bar.pinned = false
                pinCommand.running = true
                tryCompare(Config.bar, "pinned", true)
                tryCompare(pinCommand, "running", false)
                pinCommand.running = true
                tryCompare(Config.bar, "pinned", false)
                tryCompare(pinCommand, "running", false)
                console.log("BAR_PIN_IPC_PASSED")
            }

            function test_vertical_display_control() {
                try {
                    const originalStyle = Config.bar.style
                    Config.bar.style = "left"
                    bar.sourceComponent = left
                    tryVerify(() => bar.item !== null)
                    const display = findChild(bar.item, "verticalBrightnessDroplet")
                    const brightness = findChild(display, "verticalBrightnessControl")
                    const temperature = findChild(display, "verticalTemperatureControl")
                    const monitor = Brightness.getMonitorForScreen(Quickshell.screens[0])
                    const other = Brightness.monitors.find(item => item.screen === null)
                    verify(monitor !== undefined && other !== undefined)
                    tryCompare(NightLightService, "currentTemperature", 6500)
                    compare(display.split, false)
                    compare(temperature.visible, false)
                    compare(brightness.height, display.height)
                    Brightness.syncBrightness = false
                    mouseWheel(brightness, brightness.width / 2, brightness.height / 2, 0, 120)
                    compare(monitor.brightness, 0.55)
                    compare(other.brightness, 0.5, "Unsynced brightness must target only this screen")
                    mouseClick(brightness)
                    tryCompare(display, "split", true)
                    verify(display.splitProgress < 1, "Opening must animate instead of snapping")
                    tryCompare(display, "splitProgress", 1)
                    compare(temperature.visible, true)
                    compare(brightness.height, display.height / 2)
                    compare(temperature.y, display.height / 2)
                    tryCompare(NightLightService, "currentTemperature", NightLightService.temperature)
                    const saved = NightLightService.temperature
                    mouseWheel(temperature, temperature.width / 2, temperature.height / 2, 0, -120)
                    compare(NightLightService.temperature, saved - 100)
                    compare(monitor.brightness, 0.55, "Temperature scroll must leave brightness alone")
                    Brightness.syncBrightness = true
                    mouseWheel(brightness, brightness.width / 2, brightness.height / 2, 0, 120)
                    compare(monitor.brightness, 0.6)
                    compare(other.brightness, 0.6, "Synced brightness must update other ready monitors")
                    other.ready = false
                    brightness.forceActiveFocus()
                    keyClick(Qt.Key_Down)
                    compare(monitor.brightness, 0.55)
                    compare(other.brightness, 0.6, "An unavailable monitor must not receive brightness writes")
                    temperature.forceActiveFocus()
                    keyClick(Qt.Key_Up)
                    compare(NightLightService.temperature, saved)
                    mouseMove(bar, bar.width - 1, 1)
                    tryCompare(component(temperature, "HoverTint"), "hovered", false)
                    compare(component(temperature, "StyledRect").variant, "pane",
                        "Keyboard focus and night light must not latch a selected fill")
                    NightLightService.setTemperature(NightLightService.minTemperature)
                    mouseWheel(temperature, temperature.width / 2, temperature.height / 2, 0, -120)
                    compare(NightLightService.temperature, NightLightService.minTemperature)
                    NightLightService.setTemperature(NightLightService.maxTemperature)
                    tryCompare(display, "split", false)
                    tryCompare(display, "splitProgress", 0)
                    mouseClick(brightness)
                    tryCompare(display, "split", true)
                    tryCompare(display, "splitProgress", 1)
                    compare(NightLightService.temperature, NightLightService.maxTemperature - 100,
                        "Enabling from neutral must restore an active night-light temperature")
                    NightLightService.setTemperature(saved - 100)
                    tryCompare(NightLightService, "currentTemperature", saved - 100)
                    const snapshots = Quickshell.env("NONCHALANT_BAR_SNAPSHOTS")
                    if (snapshots) grabImage(bar).save(snapshots + "/display-split.png")
                    mouseClick(temperature)
                    tryCompare(display, "split", false)
                    verify(display.splitProgress > 0, "The lower half must retract instead of disappearing")
                    compare(temperature.enabled, false)
                    tryCompare(NightLightService, "currentTemperature", 6500)
                    tryCompare(temperature, "visible", false)
                    mouseClick(brightness)
                    tryCompare(display, "split", true)
                    tryCompare(display, "splitProgress", 1)
                    compare(NightLightService.temperature, saved - 100, "Re-enabling must retain the saved temperature")
                    brightness.forceActiveFocus()
                    keyClick(Qt.Key_Space)
                    tryCompare(display, "split", false)
                    tryCompare(NightLightService, "currentTemperature", 6500)
                    other.ready = true
                    Brightness.syncBrightness = false
                    Config.bar.style = originalStyle
                    console.log("BAR_DISPLAY_CONTROL_PASSED")
                } catch (error) {
                    console.error("TEST_ASSERTION", error.stack)
                    throw error
                }
            }

            function test_vertical_weather_section() {
                try {
                    const originalStyle = Config.bar.style
                    Config.bar.style = "left"
                    bar.sourceComponent = left
                    tryVerify(() => bar.item !== null)
                    const clock = findChild(bar.item, "verticalClockDroplet")
                    // The offscreen platform has an unnamed screen; register its controller explicitly.
                    Visibilities.registerDashboardController(clock.bar.screen.name, clock)
                    clock.showDashboardSection("stats")
                    wait(Motion.expandDuration + 100)
                    const stats = findChild(bar.item, "dashboardStatsButton")
                    const weather = findChild(bar.item, "dashboardWeatherButton")
                    verify(stats !== undefined && weather !== undefined)
                    verify(weather.y > stats.y, "Weather is the fourth tab after System Monitor")
                    const controls = component(bar.item, "VerticalDashboardControls")
                    compare(component(controls, "CircularControl"), null, "Night light has moved out of the vertical dashboard")
                    mouseClick(weather)
                    tryCompare(clock, "dashboardSection", "weather")
                    const pane = findChild(bar.item, "dashboardWeatherSection")
                    tryCompare(pane, "selected", true)
                    tryVerify(() => pane.item !== null)
                    compare(component(pane.item, "IslandWeatherPanel").showHeader, false,
                        "Vertical weather keeps the animated sky without island navigation")
                    const sky = component(pane.item, "WeatherWidget")
                    verify(sky !== null)
                    tryVerify(() => sky.height > 140, 2000, "The sky fills the available dashboard height")
                    const weatherPanel = component(pane.item, "IslandWeatherPanel")
                    const forecastCard = findChild(weatherPanel, "weatherForecastCard")
                    verify(weatherPanel.height - forecastCard.mapToItem(weatherPanel, 0, forecastCard.height).y <= 15,
                        "The forecast belongs at the bottom without unused space")
                    compare(findChild(bar.item, "dashboardMediaRow").visible, false, "No player must hide the media and lyrics row")
                    const owner = Visibilities.activeBarPopup
                    compare(findChild(bar.item, "dashboardViewHighlight").targetItem, weather)
                    tryCompare(WeatherService, "isLoading", false)
                    compare(WeatherService.dataAvailable, false, "Fixture starts with unavailable weather")
                    WeatherService.currentTemp = 24
                    WeatherService.weatherCode = 0
                    WeatherService.weatherDescription = "Clear sky"
                    WeatherService.weatherSymbol = "☀"
                    WeatherService.maxTemp = 28
                    WeatherService.minTemp = 17
                    WeatherService.forecast = [
                        {dayName: "Mon", emoji: "☀️", maxTemp: 28, minTemp: 17},
                        {dayName: "Tue", emoji: "⛅", maxTemp: 26, minTemp: 16},
                        {dayName: "Wed", emoji: "☀️", maxTemp: 27, minTemp: 18},
                        {dayName: "Thu", emoji: "☀️", maxTemp: 29, minTemp: 18},
                        {dayName: "Fri", emoji: "☁️", maxTemp: 25, minTemp: 15}]

                    WeatherService.dataAvailable = true
                    WeatherService.hasFailed = false
                    mouseMove(bar, bar.width - 1, 1)
                    const glow = findChild(sky, "weatherCelestialGlow")
                    const initialGlow = glow.opacity
                    wait(200)
                    verify(Math.abs(glow.opacity - initialGlow) > 0.001, "The celestial glow must animate while visible")
                    const snapshots = Quickshell.env("NONCHALANT_BAR_SNAPSHOTS")
                    if (snapshots) {
                        WeatherService.debugMode = true
                        WeatherService.debugHour = 23
                        wait(1200)
                        grabImage(bar).save(snapshots + "/dashboard-weather-night.png")
                        WeatherService.debugHour = 12
                        wait(1200)
                        grabImage(bar).save(snapshots + "/dashboard-weather-day.png")
                        WeatherService.debugMode = false
                    }
                    component(bar.item, "DashboardSidePane").forceActiveFocus()
                    keyClick(Qt.Key_Tab, Qt.ControlModifier)
                    tryCompare(clock, "dashboardSection", "notifications")
                    keyClick(Qt.Key_Tab, Qt.ControlModifier | Qt.ShiftModifier)
                    tryCompare(clock, "dashboardSection", "weather")
                    compare(Visibilities.activeBarPopup, owner)
                    keyClick(Qt.Key_Escape)
                    tryCompare(clock, "menuOpen", false)
                    compositorState.outputs = [testOutput]
                    GlobalShortcuts.run("weather")
                    tryCompare(clock, "menuOpen", true)
                    compare(clock.dashboardSection, "weather")
                    GlobalShortcuts.run("weather")
                    compare(clock.dashboardSection, "notifications")
                    clock.toggleCenterMenu()
                    tryCompare(clock, "menuOpen", false)
                    Config.bar.style = originalStyle
                    console.log("BAR_WEATHER_SECTION_PASSED")
                } catch (error) {
                    console.error("TEST_ASSERTION", error.stack)
                    throw error
                }
            }

            function initTestCase() {
                tryVerify(() => CompositorService.backend !== null)
                CompositorService.backend.state = compositorState
            }

            function cleanup() {
                const clock = bar.item ? findChild(bar.item, "verticalClockDroplet") : null
                if (clock) Visibilities.unregisterDashboardController(clock.bar.screen.name, clock)
                bar.sourceComponent = undefined
                Notifications.dismissAllPopups()
                Notifications.silent = false
                compositorState.workspaces = []
                compositorState.windows = []
                compositorState.outputs = []
            }

            function test_notifications_data() {
                const rows = []
                for (const layout of [{name: "island", component: island}, {name: "pills", component: pills}]) {
                    for (const pinned of [false, true]) {
                        for (const duration of [0, 100]) {
                            rows.push({tag: layout.name + "-" + pinned + "-" + duration,
                                component: layout.component, pinned: pinned, duration: duration})
                        }
                    }
                }
                return rows
            }

            function test_notifications(data) {
                Config.bar.pinned = data.pinned
                Config.theme.animDuration = data.duration
                compositorState.workspaces = [testWorkspace]
                compositorState.windows = [testWindow]
                bar.sourceComponent = data.component
                tryVerify(() => bar.item !== null)
                const panel = bar.item
                compare(panel.hasWindowTouchingTop, true)
                panel.expand("calendar")
                tryCompare(panel, "containerY", 0)
                const notification = Notifications.notifyInternal({appName: "Bar regression",
                    summary: "Network disconnected", body: "The network connection has been disconnected",
                    expireTimeout: 60000})
                tryCompare(panel, "hasNotifications", true)
                compare(panel.currentMode, "calendar")
                panel.collapse()
                tryCompare(panel, "currentMode", "notification")
                tryCompare(panel, "containerY", 0, 1500)
                compare(panel.retractingToHidden, false)
                compare(panel.revealProgress, 1)
                Notifications.timeoutNotification(notification.id)
                tryCompare(panel, "currentMode", "collapsed")
                tryCompare(panel, "retractingToHidden", false)
                tryCompare(panel, "revealProgress", data.pinned ? 1 : 0)

                const background = Notifications.notifyInternal({summary: "Expires behind a panel", expireTimeout: 60000})
                tryCompare(panel, "currentMode", "notification")
                panel.expand("calendar")
                tryCompare(panel, "containerY", 0)
                Notifications.clearPopupById(background.id)
                tryCompare(panel, "hasNotifications", false)
                wait(Motion.collapseDuration + 100)
                compare(panel.currentMode, "calendar", "An expired notification must not close another panel")
                compare(panel.containerY, 0)
                panel.collapse()
                tryCompare(panel, "currentMode", "collapsed")

                Notifications.notifyInternal({summary: "Dismiss through DND", expireTimeout: 60000})
                tryCompare(panel, "currentMode", "notification")
                Notifications.setSilent(true)
                tryCompare(panel, "currentMode", "collapsed")
                tryCompare(panel, "retractingToHidden", false)
                tryCompare(panel, "revealProgress", data.pinned ? 1 : 0)
                console.log("BAR_NOTIFICATION_PASSED_" + data.tag)
            }

            function test_interrupted_retraction_data() {
                return [{tag: "island", component: island}, {tag: "pills", component: pills}]
            }

            function test_interrupted_retraction(data) {
                Config.bar.pinned = false
                Config.theme.animDuration = 100
                compositorState.workspaces = [testWorkspace]
                compositorState.windows = [testWindow]
                bar.sourceComponent = data.component
                tryVerify(() => bar.item !== null)
                const panel = bar.item
                compare(panel.hasWindowTouchingTop, true)
                for (const interrupt of ["notification", "panel", "osd", "pin", "workspace"]) {
                    panel.expand(interrupt === "osd" ? "osd" : "calendar")
                    tryCompare(panel, "containerY", 0)
                    panel.collapse()
                    wait(80)
                    compare(panel.retractingToHidden, true)
                    verify(panel.containerY < 0)
                    if (interrupt === "notification") {
                        Notifications.notifyInternal({summary: "Arrived while closing", expireTimeout: 60000})
                    } else if (interrupt === "panel") {
                        panel.expand("sound")
                    } else if (interrupt === "osd") {
                        panel.triggerOsd("mic", 0.5, false)
                    } else if (interrupt === "pin") {
                        Config.bar.pinned = true
                    } else {
                        compositorState.windows = []
                    }
                    tryCompare(panel, "containerY", 0, 1500)
                    compare(panel.retractingToHidden, false)
                    wait(Motion.collapseDuration + 100)
                    compare(panel.containerY, 0, "A stale close must not hide " + interrupt)
                    Notifications.dismissAllPopups()
                    panel.collapse()
                    Config.bar.pinned = false
                    compositorState.windows = [testWindow]
                    tryCompare(panel, "currentMode", "collapsed")
                    tryCompare(panel, "retractingToHidden", false)
                    tryCompare(panel, "revealProgress", 0)
                }
                console.log("BAR_INTERRUPTED_RETRACTION_PASSED_" + data.tag)
            }

            function test_labels_data() {
                return [{tag: "island", component: island}, {tag: "pills", component: pills}]
            }

            function test_labels(data) {
                Config.bar.pinned = true
                bar.sourceComponent = data.component
                tryVerify(() => bar.item !== null, 2000)
                verifyNoPinIcon(bar.item)
                const label = findLabel(bar.item)
                verify(label !== null)
                const rendered = label.children.find(child => child.truncated !== undefined)
                verify(rendered !== undefined)
                for (const font of ["JetBrains Mono", "Noto Sans"]) {
                    label.fontFamily = font
                    for (const size of [11, 13, 14, 17]) {
                        label.pixelSize = size
                        for (const text of ["Desktop", "Terminal", "Firefox", "Settings", "Café", "डेस्कटॉप"]) {
                            label.text = text
                            tryCompare(rendered, "text", text)
                            tryVerify(() => label.width >= rendered.implicitWidth, 1000,
                                data.tag + ": " + font + " " + size + " " + text
                                + " allocated=" + label.width + " needed=" + rendered.implicitWidth)
                            compare(rendered.truncated, false, "Short labels must be fully visible")
                        }
                    }
                }
                label.pixelSize = 13
                label.fontFamily = "JetBrains Mono"
                label.text = "A long window or media title that should still elide inside the bar"
                tryCompare(rendered, "truncated", true)
                verify(label.implicitWidth > label.width, "The layout must still cap long titles")
                label.text = "Desktop"
                tryCompare(rendered, "truncated", false)
                for (const playing of [true, false]) {
                    label.isPlaying = playing
                    for (const progress of [0, 0.5, 1]) {
                        label.progress = progress
                        tryVerify(() => !rendered.truncated && label.width >= rendered.implicitWidth)
                        tryVerify(() => rendered.height >= rendered.implicitHeight, 1000,
                            "Playback decoration must leave enough height for the label")
                    }
                }
                console.log("BAR_CONTEXT_TEXT_PASSED_" + data.tag)
                bar.sourceComponent = undefined
            }

            function cleanupTestCase() {
                console.log("BAR_CONTEXT_TEXT_RUNTIME_FINISHED")
                CompositorService.backend.state = null
                Qt.quit()
            }
        }
    }
    Timer {
        interval: 60000
        running: true
        onTriggered: { console.error("BAR_CONTEXT_TEXT_RUNTIME_TIMEOUT"); Qt.quit() }
    }
}
'''


def install_fake_audio_nodes(path):
    """Keep the real audio methods while replacing native nodes in private fixtures."""
    source = path.read_text()
    for name, level in (("sink", 0.4), ("source", 0.65)):
        native = "property PwNode " + name + ": Pipewire.defaultAudio" + ("Sink" if name == "sink" else "Source")
        replacement = """property QtObject %s: QtObject {
        property bool ready: true
        property string name: "Test %s"
        property QtObject audio: QtObject {
            property real volume: %s
            property bool muted: false
        }
    }""" % (name, name, level)
        if native not in source:
            raise AssertionError("Audio fixture no longer matches the native node declaration")
        source = source.replace(native, replacement)
    source = source.replace("    PwObjectTracker {\n        objects: [sink, source]\n    }", "")
    path.write_text(source)


def install_fake_brightness_monitors(path):
    """Keep monitor selection/sync policy while replacing hardware I/O."""
    source = path.read_text()
    start = source.index("    component BrightnessMonitor: QtObject {")
    end = source.index("    Component {\n        id: monitorComp", start)
    source = source[:start] + """    component BrightnessMonitor: QtObject {
        required property ShellScreen screen
        property bool ready: true
        property real brightness: 0.5
        function setBrightness(value: real): void {
            brightness = Math.max(0, Math.min(1, value));
        }
    }

""" + source[end:]
    source = source.replace("Quickshell.screens.map(screen =>", "Quickshell.screens.concat([null]).map(screen =>")
    path.write_text(source)


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for runtime checks")
class BarTextRuntimeTests(unittest.TestCase):
    def test_bar_labels_and_pin_command(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-bar-text-") as directory:
            fixture = Path(directory)
            for name in ("config", "assets", "scripts", "version"):
                (fixture / name).symlink_to(ROOT / name, target_is_directory=(ROOT / name).is_dir())
            modules = fixture / "modules"
            modules.mkdir()
            for source in (ROOT / "modules").iterdir():
                if source.name != "services":
                    (modules / source.name).symlink_to(source, target_is_directory=source.is_dir())
            shutil.copytree(ROOT / "modules/services", modules / "services")
            install_fake_audio_nodes(modules / "services/Audio.qml")
            install_fake_brightness_monitors(modules / "services/Brightness.qml")
            weather = modules / "services/WeatherService.qml"
            weather.write_text(weather.read_text().replace(
                'Quickshell.shellDir + "/scripts/weather.sh"',
                json.dumps(str(fixture / "weather.sh"))).replace(
                    'readonly property int maxRetries: 3', 'readonly property int maxRetries: 0'))
            (fixture / "weather.sh").write_text("#!/bin/sh\nprintf '%s\\n' '{\"error\":\"Fixture offline\"}'\n")
            (fixture / "weather.sh").chmod(0o755)
            shortcuts = modules / "services/GlobalShortcuts.qml"
            shortcuts.write_text(shortcuts.read_text().replace(
                '"/tmp/nonchalant_ipc.pipe"', '"' + str(fixture / "ipc.pipe") + '"'))
            (modules / "services/compositor/NiriBackend.qml").write_text(
                "import QtQuick\nCompositorBackend {}\n")
            (fixture / "shell.qml").write_text(QML)
            home = fixture / "home"
            home.mkdir()
            # Keep locally installed fonts available inside the isolated home.
            fonts = Path.home() / ".local/share/fonts"
            if fonts.is_dir():
                (home / ".local/share").mkdir(parents=True)
                (home / ".local/share/fonts").symlink_to(fonts, target_is_directory=True)
            # Menu initialization must not address the user's network adapters.
            binaries = fixture / "bin"
            binaries.mkdir()
            for command in ("nmcli", "bluetoothctl", "ddcutil", "brightnessctl"):
                stub = binaries / command
                stub.write_text("#!/bin/sh\nexit 0\n")
                stub.chmod(0o755)
            gamma = fixture / "gamma.json"
            gamma.write_text(json.dumps({"temperature": 6500, "writes": []}))
            busctl = binaries / "busctl"
            busctl.write_text("#!/usr/bin/python3\n" + f"""import json, sys
from pathlib import Path
path = Path({str(gamma)!r})
state = json.loads(path.read_text())
args = sys.argv[1:]
if args[:3] == ['--user', 'set-property', 'rs.wl-gammarelay']:
    state['temperature'] = int(args[-1])
    state['writes'].append(state['temperature'])
    path.write_text(json.dumps(state))
elif args[:3] == ['--user', 'get-property', 'rs.wl-gammarelay']:
    print('q', state['temperature'])
else:
    sys.exit(1)
""")
            busctl.chmod(0o755)
            runtime = fixture / "runtime"
            runtime.mkdir(mode=0o700)
            env = {
                **os.environ,
                "HOME": str(home),
                "PATH": str(binaries) + os.pathsep + os.environ["PATH"],
                "DBUS_SYSTEM_BUS_ADDRESS": "unix:path=" + str(fixture / "no-system-bus"),
                "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_STATE_HOME": str(home / ".local/state"),
                "XDG_DATA_HOME": str(home / ".local/share"),
                "XDG_CACHE_HOME": str(home / ".cache"),
                "XDG_RUNTIME_DIR": str(runtime),
                "QT_QPA_PLATFORM": "offscreen",
                "QT_QUICK_BACKEND": "software",
                "NIRI_SOCKET": str(fixture / "no-compositor.sock"),
                "NONCHALANT_COMPOSITOR": "niri",
            }
            bus_config = fixture / "dbus.conf"
            bus_config.write_text(
                '<busconfig><type>session</type><auth>EXTERNAL</auth>'
                f'<listen>unix:path={runtime / "bus"}</listen>'
                '<policy context="default"><allow send_destination="*"/>'
                '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
            env.pop("DBUS_SESSION_BUS_ADDRESS", None)
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(
                ["dbus-run-session", f"--config-file={bus_config}", "--", "qs", "-p", str(fixture), "--no-duplicate", "--no-color"],
                env=env, capture_output=True, text=True, timeout=65,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("BAR_CONTEXT_TEXT_RUNTIME_FINISHED", output, output)
            self.assertIn("BAR_PIN_IPC_PASSED", output, output)
            self.assertIn("BAR_DEVICE_STATUS_PASSED", output, output)
            self.assertIn("BAR_DROPLETS_AUDIO_PASSED", output, output)
            self.assertIn("BAR_DISPLAY_CONTROL_PASSED", output, output)
            self.assertIn("BAR_WEATHER_SECTION_PASSED", output, output)
            self.assertIn("BAR_WORKSPACE_INITIALIZATION_PASSED", output, output)
            self.assertIn("BAR_WORKSPACE_OCCUPANCY_PASSED", output, output)
            for layout in ("island", "pills"):
                self.assertIn("BAR_CONTEXT_TEXT_PASSED_" + layout, output, output)
                self.assertIn("BAR_INTERRUPTED_RETRACTION_PASSED_" + layout, output, output)
                for pinned in ("false", "true"):
                    for duration in (0, 100):
                        marker = f"BAR_NOTIFICATION_PASSED_{layout}-{pinned}-{duration}"
                        self.assertIn(marker, output, output)
            self.assertNotIn("BAR_CONTEXT_TEXT_RUNTIME_TIMEOUT", output, output)
            self.assertNotIn("FAIL!", output, output)
            self.assertNotIn("Binding loop", output, output)


if __name__ == "__main__":
    unittest.main()
