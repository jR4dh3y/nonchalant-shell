"""Check bar rendering and transitions without touching the desktop session."""

import os
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
                verify(trigger.y > brightness.y, "Combined status belongs below brightness")
                compare(component(bar.item, "BatteryIndicator"), null,
                    "There must be no separate battery control")
                mouseClick(trigger)
                tryCompare(clock, "deviceMenuActive", true)
                compare(clock.controlMode, "wifi")
                wait(Motion.expandDuration + 100)
                const owner = Visibilities.activeBarPopup
                verify(owner !== null)
                function tab(mode) { return findChild(bar.item, "deviceStatusTab-" + mode) }
                tryVerify(() => tab("wifi") !== undefined)
                compare(tab("wifi").selected, true)
                mouseClick(tab("bluetooth"))
                tryCompare(clock, "controlMode", "bluetooth")
                tryVerify(() => tab("bluetooth")?.selected === true)
                compare(clock.menuOpen, true)
                compare(Visibilities.activeBarPopup, owner)
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
                    tryVerify(() => tab(mode)?.selected === true)
                    clock.openControlMenu(mode)
                    tryCompare(clock, "menuOpen", false)
                }
                clock.openControlMenu("wifi")
                component(bar.item, "VerticalControlMenu").forceActiveFocus()
                keyClick(Qt.Key_Escape)
                tryCompare(clock, "menuOpen", false)
                compare(Visibilities.activeBarPopup, null)
                Config.bar.style = originalStyle
                console.log("BAR_DEVICE_STATUS_PASSED")
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

            function initTestCase() {
                tryVerify(() => CompositorService.backend !== null)
                CompositorService.backend.state = compositorState
            }

            function cleanup() {
                bar.sourceComponent = undefined
                Notifications.dismissAllPopups()
                Notifications.silent = false
                compositorState.workspaces = []
                compositorState.windows = []
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
