"""Exercise Deck's populated layout, custom controls, and action boundaries."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from tests.e2e.test_bar_text_runtime import install_fake_audio_nodes, install_fake_brightness_monitors

ROOT = Path(__file__).resolve().parents[2]
QML = r'''
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.config
import qs.modules.bar
import qs.modules.services
import qs.modules.services.compositor
import qs.modules.theme
import qs.modules.widgets.launcher
import qs.modules.bar.deck
import qs.modules.globals

ShellRoot {
    id: shellRoot
    property string fixtureResponse: ""
    property list<string> fixtureArguments: ["State"]
    property bool fixtureBusy: false
    // Quickshell.env returns null for unset variables; the tray checks need both.
    readonly property string trayPython: Quickshell.env("DECK_TEST_PYTHON") ?? ""
    readonly property string trayFixture: Quickshell.env("DECK_TRAY_FIXTURE") ?? ""
    Process {
        command: [shellRoot.trayPython, shellRoot.trayFixture]
        running: shellRoot.trayPython !== ""
    }
    Process {
        id: trayQuery
        command: [shellRoot.trayPython, shellRoot.trayFixture].concat(fixtureArguments)
        stdout: StdioCollector { id: trayOutput }
        onExited: { fixtureResponse = trayOutput.text; fixtureBusy = false; }
    }
    CompositorState { id: compositorState }
    CompositorOutput { id: output; name: Quickshell.screens[0].name; focused: true }
    FloatingWindow {
        visible: true
        implicitWidth: 1280
        implicitHeight: 720
        Item {
            id: host
            width: 1280
            height: 720
            BarContent { id: content; anchors.fill: parent; screen: Quickshell.screens[0] }
            RunMenuHost { id: runMenu; anchors.fill: parent; screen: Quickshell.screens[0]; z: 200 }
        }
        TestCase {
            id: test
            name: "DeckRuntime"
            when: Config.initialLoadComplete
            property list<CompositorWorkspace> workspaces: []
            property list<CompositorWindow> windows: []
            property bool notificationActionRan: false
            function item(name) { return findChild(content, name) }
            function check(condition, message) {
                if (!condition) console.error("DECK_ASSERTION", message)
                verify(condition, message)
            }
            function click(name, button = Qt.LeftButton) {
                const drawer = item("deckDrawer")
                if (drawer?.isOpen) tryCompare(drawer, "progress", 1)
                // A page change lays out its controls on a later frame, so actionability is polled first.
                tryVerify(() => item(name)?.visible === true && item(name).width > 0, 2000)
                const target = item(name)
                check(target !== null && target.visible && target.width > 0, name + " is actionable")
                mouseClick(target, target.width / 2, target.height / 2, button)
            }
            function fixtureCall(args) {
                shellRoot.fixtureResponse = ""
                shellRoot.fixtureArguments = args
                shellRoot.fixtureBusy = true
                trayQuery.running = true
                tryCompare(shellRoot, "fixtureBusy", false, 5000)
                return shellRoot.fixtureResponse ? JSON.parse(shellRoot.fixtureResponse) : null
            }
            // Cards land in sequence after their page opens; wait out the longest entrance before measuring.
            function waitForCardEntrance() {
                wait(DeckMotion.delayFor(DeckMotion.maximumStaggerSteps) + DeckMotion.cardDuration)
            }
            function initTestCase() {
                tryCompare(Icons, "fontReady", true, 3000)
                compare(Icons.font, "Phosphor-Bold")
                tryVerify(() => CompositorService.backend !== null)
                compositorState.outputs = [output]
                CompositorService.backend.state = compositorState
                const workspaceComponent = Qt.createComponent("modules/services/compositor/CompositorWorkspace.qml")
                const windowComponent = Qt.createComponent("modules/services/compositor/CompositorWindow.qml")
                const workspaceItems = []
                const windowItems = []
                for (let index = 1; index <= 12; index++) {
                    workspaceItems.push(workspaceComponent.createObject(test, {
                        id: "ws" + index, idx: index, name: "Workspace " + index, isNamed: true,
                        output: output.name, active: index === 1, focused: index === 1,
                        activeWindowId: index === 1 ? "w1" : "", windows: index === 1 ? 8 : 0
                    }))
                }
                for (let index = 1; index <= 8; index++) {
                    windowItems.push(windowComponent.createObject(test, {
                        id: "w" + index, appId: "org.kde.kate", title: "Document " + index + " — a long descriptive window title",
                        output: output.name, workspaceId: "ws1", is_focused: index === 1
                    }))
                }
                workspaces = workspaceItems
                windows = windowItems
                compositorState.workspaces = workspaces
                compositorState.windows = windows
                Config.bar.style = "deck"
                tryVerify(() => item("deckClock") !== null)
                Visibilities.registerDashboardController(output.name, item("deckSurface").parent)
            }
            function init() {
                Visibilities.closeActiveBarPopup()
                host.width = 1280
                compositorState.fullscreenOutputs = []
                compositorState.overviewOpen = false
                Config.bar.position = "top"
                Config.bar.use12hFormat = false
            }
            function test_compact_footprint_and_populated_geometry() {
                compare(content.barTargetHeight, 32)
                check(content.barTargetHeight + content.baseOuterMargin <= 40, "default reserved edge is at most 40px")
                for (const position of ["top", "bottom"]) {
                    Config.bar.position = position
                    for (const width of [360, 480, 640, 768, 1024, 1280, 1920]) {
                        host.width = width
                        for (const format of [false, true]) {
                            Config.bar.use12hFormat = format
                            // Geometry settles when the layout polishes, which happens before a frame is drawn.
                            waitForRendering(content)
                            const hitbox = content.barHitbox
                            check(hitbox.x >= 0 && hitbox.x + hitbox.width <= width, "bar fits horizontally at " + width)
                            check(hitbox.y >= 0 && hitbox.y + hitbox.height <= host.height, "bar fits vertically")
                            for (const name of ["deckNavigationZone", "deckStatusZone", "deckClock", "deckVolume"]) {
                                const target = item(name)
                                const left = target.mapToItem(content, 0, 0).x
                                check(left >= 0 && left + target.width <= width + 0.5, name + " fits at " + width)
                            }
                            const navigation = item("deckNavigationZone")
                            const status = item("deckStatusZone")
                            check(navigation.x + navigation.width <= status.x, "zones do not overlap")
                        }
                    }
                }
                console.log("DECK_FOOTPRINT_PASSED")
            }
            function test_task_flyout_geometry() {
                const drawer = item("deckDrawer")
                for (const edge of ["top", "bottom"]) {
                    Config.bar.position = edge
                    for (const width of [360, 640, 1280]) {
                        host.width = width
                        for (const route of ["controls", "connections", "today", "alerts", "tray", "power", "wallpapers", "stats", "media"]) {
                            GlobalShortcuts.run(route)
                            tryCompare(drawer, "isOpen", true)
                            tryCompare(drawer, "progress", 1)
                            tryVerify(() => Math.abs(drawer.width - Math.min(host.width - Styling.fontSize(0), drawer.preferredWidth)) < 1)
                            tryVerify(() => Math.abs(drawer.height - Math.min(host.height - content.barTargetHeight - content.baseOuterMargin - Styling.fontSize(0) * 2, drawer.preferredHeight)) < 6)
                            check(drawer.x >= 0 && drawer.x + drawer.width <= host.width + 1, route + " stays within output")
                            check(drawer.y >= 0 && drawer.y + drawer.height <= host.height + 1, route + " fits above or below bar")
                            check(item("deckPageRail").visible === drawer.dash, route + " shows the page rail only on dash pages")
                            compare(item("deckWindowSearch"), null)
                            GlobalShortcuts.run(route)
                            tryCompare(drawer, "isOpen", false)
                        }
                    }
                }
                host.width = 1280
                GlobalShortcuts.run("connections")
                tryCompare(drawer, "progress", 1)
                const dashWidth = drawer.width
                const dashX = drawer.x
                click("deckPage-today")
                check(drawer.isOpen && drawer.mode === "today", "rail switches pages without closing")
                wait(Math.max(50, DeckMotion.resizeDuration))
                compare(drawer.width, dashWidth)
                compare(drawer.x, dashX)
                const indicator = item("deckRailIndicator")
                tryVerify(() => Math.abs(indicator.y - item("deckPage-today").y) < 1, 2000, "rail indicator settles on the selected page")
                const lastDay = item("deckCalendarDay-" + item("deckCalendar").daysInMonth)
                check(lastDay.mapToItem(drawer, 0, lastDay.height).y <= drawer.height, "last calendar week is visible")
                for (const card of ["deckTodayDate", "deckTodayWeather", "deckMonth"])
                    check(item(card) !== null && item(card).visible, card + " is its own card")
                drawer.forceActiveFocus()
                keyClick(Qt.Key_Tab, Qt.ControlModifier)
                compare(drawer.mode, "alerts")
                keyClick(Qt.Key_Backtab, Qt.ControlModifier | Qt.ShiftModifier)
                compare(drawer.mode, "today")
                GlobalShortcuts.run("power")
                tryVerify(() => drawer.width < dashWidth, 2000, "power is a compact flyout rather than the dash")
                check(!item("deckPageRail").visible, "flyouts hide the page rail")
                GlobalShortcuts.run("power")
                tryCompare(drawer, "isOpen", false)
                const busyPips = item("deckWorkspace-ws1-pips")
                check(busyPips.visible && busyPips.children.length >= 4, "workspace occupancy pips stay in the bar")
                console.log("DECK_REFINEMENT_PASSED")
            }
            function test_connection_groups() {
                const component = Qt.createComponent("modules/services/WifiAccessPoint.qml")
                const nodes = []
                for (let index = 0; index < 31; index++)
                    nodes.push(component.createObject(test, {lastIpcObject: {ssid: "Network " + index, active: index === 0}}))
                for (const node of nodes) NetworkService.wifiNetworks.push(node)
                GlobalShortcuts.run("connections")
                const drawer = item("deckDrawer")
                tryCompare(drawer, "progress", 1)
                waitForCardEntrance()
                const currentGroup = item("deckConnectedNetworks")
                const availableGroup = item("deckAvailableNetworks")
                compare(currentGroup.networks.length, 1)
                compare(availableGroup.networks.length, 30)
                const list = item("deckNetworkList")
                const viewport = list.contentItem
                tryVerify(() => viewport.contentHeight > viewport.height)
                const toolbar = item("deckConnectionToolbar")
                const toolbarY = toolbar.mapToItem(drawer, 0, 0).y
                const currentY = currentGroup.mapToItem(drawer, 0, 0).y
                const popupHeight = drawer.height
                const row = item("deckNetwork-Network 1")
                mouseWheel(row, row.width / 2, row.height / 2, 0, -480)
                tryVerify(() => viewport.contentY > 0, 2000, "wheel over an SSID scrolls only the list")
                compare(toolbar.mapToItem(drawer, 0, 0).y, toolbarY)
                compare(currentGroup.mapToItem(drawer, 0, 0).y, currentY)
                compare(drawer.height, popupHeight)
                nodes[30].askingPassword = true
                const password = item("deckPassword-Network 30")
                tryVerify(() => password.activeFocus)
                tryVerify(() => password.mapToItem(list, 0, password.height).y <= list.height + 1, 2000, "password stays in list viewport")
                password.text = "fixture value"
                keyClick(Qt.Key_Escape)
                compare(password.text, "")
                nodes[0].active = false
                tryCompare(currentGroup, "visible", false)
                compare(availableGroup.networks.length, 31)
                click("deckConnectionBluetooth")
                check(!currentGroup.visible, "Wi-Fi groups hide on Bluetooth tab")
                compare(drawer.tab, "bluetooth")
                GlobalShortcuts.run("wifi")
                check(drawer.isOpen && drawer.tab === "wifi", "IPC switches the manually chosen Bluetooth tab back to Wi-Fi")
                click("deckConnectionWifi")
                check(drawer.isOpen, "selected tab stays open")
                drawer.close()
                NetworkService.wifiNetworks.splice(0, NetworkService.wifiNetworks.length)
                for (const node of nodes) node.destroy()
                console.log("DECK_NETWORK_PASSED")
            }
            function test_deck_launcher() {
                const screenState = Visibilities.getForScreen(output.name)
                screenState.launcher = true
                const launcher = findChild(runMenu, "deckLauncher")
                check(launcher !== null, "Deck replaces the generic run menu")
                tryCompare(launcher, "progress", 1)
                const frame = findChild(runMenu, "deckLauncherFrame")
                check(frame.x < Styling.fontSize(0) && frame.y >= runMenu.barClearance - 1, "launcher unrolls under the launcher button")
                check(runMenu.hitbox === frame, "launcher frame receives input")
                tryVerify(() => findChild(runMenu, "deckLauncherInput").activeFocus)
                keyClick(Qt.Key_Tab)
                compare(GlobalStates.launcherMode, "projects")
                keyClick(Qt.Key_Tab)
                compare(GlobalStates.launcherMode, "apps")
                screenState.launcher = false
                tryCompare(launcher, "progress", 0)
                compare(runMenu.hitbox, null)
                console.log("DECK_LAUNCHER_PASSED")
            }
            function test_window_and_workspace_actions() {
                click("deckTask-w1")
                compare(CompositorService.backend.lastAction, "focus:w1")
                click("deckTask-w1", Qt.MiddleButton)
                compare(CompositorService.backend.lastAction, "close:w1")
                click("deckWorkspace-ws2")
                compare(CompositorService.backend.lastAction, "workspace:ws2")
                const workspace = item("deckWorkspace-ws1")
                mouseWheel(workspace, workspace.width / 2, workspace.height / 2, 0, -120)
                compare(CompositorService.backend.lastAction, "adjacent:1")
                GlobalShortcuts.run("dashboard")
                const drawer = item("deckDrawer")
                tryCompare(drawer, "isOpen", true)
                GlobalShortcuts.run("windows")
                check(!drawer.isOpen, "overview releases the flyout grab")
                compare(CompositorService.backend.lastAction, "overview")
                CompositorService.backend.supportsOverview = false
                check(!CompositorService.toggleOverview(), "unsupported compositor rejects overview explicitly")
                CompositorService.backend.supportsOverview = true
                console.log("DECK_ACTIONS_PASSED")
            }
            function test_drawer_routes_keyboard_and_dismissal() {
                const drawer = item("deckDrawer")
                for (const mode of ["sound", "mic", "wifi", "bluetooth", "battery", "media", "calendar", "alerts"]) {
                    GlobalShortcuts.run(mode)
                    tryCompare(drawer, "isOpen", true)
                    check(content.keyboardInputActive, "drawer owns keyboard input")
                    check(Visibilities.activeBarPopup === drawer, "drawer uses shared popup ownership")
                    GlobalShortcuts.run(mode)
                    tryCompare(drawer, "isOpen", false)
                }
                GlobalShortcuts.run("sound")
                GlobalShortcuts.run("mic")
                check(!drawer.isOpen, "aliases of the same sound flyout toggle closed")
                GlobalShortcuts.run("wifi")
                GlobalShortcuts.run("bluetooth")
                check(drawer.isOpen && drawer.tab === "bluetooth", "connection route switches without closing")
                GlobalShortcuts.run("today")
                tryVerify(() => item("deckCalendar") !== null)
                drawer.currentDate = new Date(2024, 1, 29, 23, 59)
                const calendar = item("deckCalendar")
                compare(calendar.daysInMonth, 29)
                drawer.currentDate = new Date(2024, 2, 1, 0, 1)
                check(item("deckCalendar") === calendar, "rollover keeps the same calendar page loaded")
                compare(calendar.today.getDate(), 1)
                compare(calendar.month.getMonth(), 2)
                compare(calendar.daysInMonth, 31)
                calendar.monthOffset = -1
                click("deckCalendarToday")
                compare(calendar.month.getMonth(), 2)
                drawer.forceActiveFocus()
                keyClick(Qt.Key_Escape)
                tryCompare(drawer, "isOpen", false)
                GlobalShortcuts.run("dashboard")
                FocusGrabManager.clearTopGrab()
                tryCompare(drawer, "isOpen", false)
                check(!content.keyboardInputActive, "closing releases keyboard")
                console.log("DECK_ROUTES_PASSED")
            }
            function test_custom_audio_faders_and_notifications() {
                const wasMuted = Audio.sink.audio.muted
                click("deckVolume", Qt.RightButton)
                check(Audio.sink.audio.muted === !wasMuted, "right-click mutes output")
                const volume = Audio.sink.audio.volume
                const trigger = item("deckVolume")
                mouseWheel(trigger, trigger.width / 2, trigger.height / 2, 0, 120)
                tryVerify(() => Audio.sink.audio.volume > volume, 2000, "bar volume wheel changes output")
                click("deckVolume")
                tryVerify(() => item("deckOutput-slider") !== null)
                tryCompare(item("deckDrawer"), "progress", 1)
                check(!item("deckDisplay-mute").visible && !item("deckDisplay-mute").enabled,
                    "brightness does not expose a nonfunctional mute button")
                check(item("deckDisplay-icon").visible, "brightness retains a passive icon")
                check(item("deckMediaSeek-mute") === null, "playback does not expose a nonfunctional mute button")
                const slider = item("deckOutput-slider")
                check(slider.orientation === Qt.Vertical && slider.height > slider.width * 2,
                    "output is a vertical channel fader " + slider.width + "x" + slider.height)
                for (const channel of ["deckOutput", "deckInput", "deckDisplay"]) {
                    const strip = item(channel + "-slider").mapToItem(item("deckDrawer"), 0, 0)
                    check(strip.y >= 0 && strip.y + item(channel + "-slider").height <= item("deckDrawer").height, channel + " fits in the fixed drawer")
                }
                const before = Audio.sink.audio.volume
                mouseWheel(slider, slider.width / 2, slider.height / 2, 0, -120)
                tryVerify(() => Audio.sink.audio.volume < before, 2000, "custom fader wheel changes output")
                click("deckInput-mute")
                check(Audio.source.audio.muted, "microphone mute changes input state")
                const dnd = Notifications.silent
                GlobalShortcuts.run("alerts")
                tryVerify(() => item("deckInboxDnd") !== null)
                click("deckInboxDnd")
                check(Notifications.silent === !dnd, "inbox toggles do not disturb")
                const notification = Notifications.notifyInternal({
                    appName: "Deck fixture", summary: "Build complete", body: "A fixture notification", popup: false,
                    actions: [{identifier: "open", text: "Open build"}],
                    actionHandlers: {open: () => { test.notificationActionRan = true; }}
                })
                tryVerify(() => item("deckNoticeAction-" + notification.id + "-open") !== null)
                click("deckNoticeAction-" + notification.id + "-open")
                tryCompare(test, "notificationActionRan", true)
                const dismissible = Notifications.notifyInternal({summary: "Dismiss fixture", popup: false})
                tryVerify(() => item("deckNoticeDismiss-" + dismissible.id) !== null)
                const dismissId = dismissible.id
                click("deckNoticeDismiss-" + dismissId)
                check(!Notifications.list.some(notice => notice.id === dismissId), "inbox dismissal removes the actual notification")
                console.log("DECK_CONTROLS_PASSED")
            }
            function test_power_confirmation() {
                GlobalShortcuts.run("power")
                const drawer = item("deckDrawer")
                tryCompare(drawer, "progress", 1)
                const restart = item("deckPower-reboot")
                const restartY = restart.mapToItem(host, 0, 0).y
                click("deckPower-reboot")
                compare(restart.mapToItem(host, 0, 0).y, restartY)
                check(item("deckPower-reboot").label.indexOf("Click again") === 0, "restart arms without executing")
                check(item("deckPowerCancel").visible, "armed action can be cancelled")
                click("deckPowerCancel")
                compare(item("deckPower-reboot").label, "Restart")
                click("deckPower-poweroff")
                GlobalShortcuts.run("power")
                GlobalShortcuts.run("power")
                tryCompare(drawer, "progress", 1)
                compare(item("deckPower-poweroff").label, "Shut down")
                click("deckPower-logout")
                tryCompare(item("deckPower-logout"), "label", "Log out", 4000)
                console.log("DECK_POWER_PASSED")
            }
            function test_real_tray_menu_dispatch_and_removal() {
                if (shellRoot.trayPython === "") { console.log("DECK_TRAY_SKIPPED"); return; }
                tryVerify(() => SystemTray.items.values.length === 2, 5000)
                GlobalShortcuts.run("dashboard")
                GlobalShortcuts.run("tray")
                tryCompare(item("deckDrawer"), "progress", 1)
                tryVerify(() => item("deckTrayItem-test-0") !== null)
                click("deckTrayItem-test-0")
                tryCompare(item("deckDrawer"), "isOpen", false)
                const events = fixtureCall(["State"]).events
                check(events.length === 1 && events[0].activate === true, "tray activation reaches real service")
                GlobalShortcuts.run("dashboard")
                GlobalShortcuts.run("tray")
                tryCompare(item("deckDrawer"), "progress", 1)
                click("deckTrayItem-test-0", Qt.RightButton)
                tryVerify(() => item("deckTrayMenu-Unavailable action") !== null)
                check(!item("deckTrayMenu-Unavailable action").enabled, "disabled menu action stays disabled")
                click("deckTrayBack")
                click("deckTrayItem-test-1")
                tryVerify(() => item("deckTrayMenu-More actions") !== null)
                click("deckTrayMenu-More actions")
                tryVerify(() => item("deckTrayMenu-Nested action") !== null)
                click("deckTrayMenu-Nested action")
                tryCompare(item("deckDrawer"), "isOpen", false)
                check(fixtureCall(["State"]).events.some(event => event.item === "test-1" && event.menu === 3), "nested menu dispatch reaches real app")
                GlobalShortcuts.run("dashboard")
                GlobalShortcuts.run("tray")
                tryCompare(item("deckDrawer"), "progress", 1)
                click("deckTrayItem-test-1")
                fixtureCall(["SetCount", "0"])
                tryVerify(() => SystemTray.items.values.length === 0)
                check(item("deckTrayBack") === null || !item("deckTrayBack").visible, "removal resets stale tray menu")
                fixtureCall(["SetCount", "2"])
                tryVerify(() => item("deckTrayItem-test-0") !== null)
                console.log("DECK_TRAY_PASSED")
            }
            function test_hidden_input_and_no_idle_sampling() {
                const drawer = item("deckDrawer")
                GlobalShortcuts.run("stats")
                tryCompare(drawer, "isOpen", true)
                check(drawer.sampling, "resource sampling starts for resource page")
                GlobalShortcuts.run("controls")
                check(!drawer.sampling, "resource sampling stops on page switch")
                compositorState.fullscreenOutputs = [output.name]
                tryCompare(drawer, "isOpen", false)
                compare(content.barHitbox.width, 0)
                compare(content.barHitbox.height, 0)
                compositorState.fullscreenOutputs = []
                tryVerify(() => content.barHitbox.width > 0)
                compositorState.overviewOpen = true
                compare(content.barHitbox.width, 0)
                compositorState.overviewOpen = false
                tryVerify(() => content.barHitbox.width > 0)
                console.log("DECK_HIDDEN_PASSED")
            }
            function cleanupTestCase() { CompositorService.backend.state = null; Qt.quit() }
        }
    }
    Timer { interval: 60000; running: true; onTriggered: { console.error("DECK_TIMEOUT"); Qt.quit() } }
}
'''
BACKEND = '''import QtQuick
CompositorBackend {
    id: root
    ready: true
    supportsOverview: true
    function toggleOverview(): void { lastAction = "overview" }
    property string lastAction: ""
    function focusWindow(id: string): void { lastAction = "focus:" + id }
    function closeWindow(id: string): void { lastAction = "close:" + id }
    function focusWorkspace(id: string): void { lastAction = "workspace:" + id }
    function focusAdjacentWorkspace(output: string, direction: int): void { lastAction = "adjacent:" + direction }
    function moveWindowToWorkspace(window: string, workspace: string, follow: bool): void {
        lastAction = "move:" + window + ":" + workspace + ":" + follow
    }
}
'''

@unittest.skipUnless(shutil.which("qs"), "Quickshell is required")
class DeckRuntimeTests(unittest.TestCase):
    def test_populated_layout_and_interactions(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-deck-") as directory:
            fixture = Path(directory)
            for name in ("config", "assets", "scripts", "version"):
                (fixture / name).symlink_to(ROOT / name, target_is_directory=(ROOT / name).is_dir())
            modules = fixture / "modules"
            modules.mkdir()
            for source in (ROOT / "modules").iterdir():
                if source.name != "services":
                    (modules / source.name).symlink_to(source, target_is_directory=source.is_dir())
            shutil.copytree(ROOT / "modules/services", modules / "services")
            (modules / "services/compositor/NiriBackend.qml").write_text(BACKEND)
            install_fake_audio_nodes(modules / "services/Audio.qml")
            install_fake_brightness_monitors(modules / "services/Brightness.qml")
            (fixture / "shell.qml").write_text(QML)
            home = fixture / "home"
            home.mkdir()
            runtime = fixture / "runtime"
            runtime.mkdir(mode=0o700)
            env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_STATE_HOME": str(home / ".local/state"), "XDG_DATA_HOME": str(home / ".local/share"),
                "XDG_CACHE_HOME": str(home / ".cache"), "XDG_RUNTIME_DIR": str(runtime),
                "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                "NIRI_SOCKET": str(fixture / "no-compositor.sock"), "NONCHALANT_COMPOSITOR": "niri",
                "DBUS_SYSTEM_BUS_ADDRESS": "unix:path=" + str(fixture / "no-system-bus")}
            for name in ("DBUS_SESSION_BUS_ADDRESS", "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "HYPRLAND_INSTANCE_SIGNATURE", "DISPLAY"):
                env.pop(name, None)
            if os.environ.get("DECK_TEST_PYTHON"):
                env["DECK_TRAY_FIXTURE"] = str(ROOT / "tests/runtime/tray_fixture.py")
            config = home / ".config/nonchalant/config"
            config.mkdir(parents=True)
            (config / "bar.json").write_text('{"style":"deck"}')
            bus = fixture / "dbus.conf"
            bus.write_text('<busconfig><type>session</type><auth>EXTERNAL</auth>'
                f'<listen>unix:path={runtime / "bus"}</listen>'
                '<policy context="default"><allow send_destination="*"/>'
                '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
            result = subprocess.run(["dbus-run-session", f"--config-file={bus}", "--", "qs", "-p", str(fixture), "--no-duplicate", "--no-color"],
                env=env, capture_output=True, text=True, timeout=75)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            # QtTest failures inside a test function print nothing here, so each function must prove it ran.
            markers = ["DECK_" + marker + "_PASSED" for marker in ("FOOTPRINT", "ACTIONS", "ROUTES", "CONTROLS", "HIDDEN", "REFINEMENT", "LAUNCHER", "NETWORK", "POWER")]
            markers.append("DECK_TRAY_PASSED" if env.get("DECK_TEST_PYTHON") else "DECK_TRAY_SKIPPED")
            missing = [marker for marker in markers if marker not in output]
            self.assertEqual(missing, [], output)
            for failure in ("DECK_TIMEOUT", "DECK_ASSERTION", "Binding loop", "TypeError", "ReferenceError", "Unable to assign [undefined]", "FAIL!"):
                self.assertNotIn(failure, output, output)

if __name__ == "__main__":
    unittest.main()
