"""Verify button hover and off-month calendar contrast in dark and light themes."""

import json
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
import qs.config
import qs.modules.theme
import qs.modules.widgets.dashboard.widgets
import qs.modules.widgets.dashboard.widgets.calendar

ShellRoot {
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 720
        implicitHeight: 420
        color: Colors.background
        VerticalDashboardControls {
            id: controls
            x: 20; y: 20; width: implicitWidth; height: 360
        }
        ControlButton {
            id: standalone
            x: 180; y: 20; width: 48; height: 48
            isActive: false
            iconName: Icons.gear
            tooltipText: "Settings"
        }
        Calendar {
            id: calendar
            x: 300; y: 20; width: 380; height: 380
        }
        TestCase {
            name: "ButtonHoverContrast"
            when: Config.initialLoadComplete

            function initTestCase() {
                tryCompare(Config.theme.srPrimaryFocus, "itemColor", "primaryContainer")
            }

            function luminance(color) {
                function linear(value) {
                    return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
                }
                return linear(color.r) * 0.2126 + linear(color.g) * 0.7152 + linear(color.b) * 0.0722
            }

            function readable(button, surface) {
                const icon = button.children.find(child => child.text === button.iconName)
                verify(icon !== undefined, "The actual icon text exists")
                tryCompare(icon, "color", button.item)
                const foreground = luminance(icon.color)
                const background = luminance(surface.isSingleColorGradient ? surface.singleGradientColor : surface.solidColor)
                const ratio = (Math.max(foreground, background) + 0.05)
                    / (Math.min(foreground, background) + 0.05)
                verify(ratio >= 3, button.tooltipText + " contrast is " + ratio.toFixed(2))
            }

            function test_standalone_hover_and_press() {
                for (const active of [false, true]) {
                    standalone.isActive = active
                    mouseMove(window.contentItem, 320, 390)
                    tryCompare(standalone, "isHovered", false)
                    readable(standalone, standalone)
                    mouseMove(standalone, 24, 24)
                    tryCompare(standalone, "isHovered", true)
                    readable(standalone, standalone)
                    mousePress(standalone, 24, 24)
                    readable(standalone, standalone)
                    mouseRelease(standalone, 24, 24)
                }
                console.log("STANDALONE_HOVER_CONTRAST_PASSED")
            }

            function test_shared_highlight_hover_and_exit() {
                const highlight = findChild(controls, "dashboardViewHighlight")
                verify(highlight !== null)
                for (const section of ["notifications", "wallpapers", "stats", "weather"]) {
                    controls.dashboardSection = section
                    const button = controls.selectedControl
                    verify(button !== null)
                    mouseMove(button, button.width / 2, button.height / 2)
                    tryCompare(button, "isHovered", true)
                    compare(highlight.targetItem, button)
                    readable(button, highlight)
                    mousePress(button, button.width / 2, button.height / 2)
                    readable(button, highlight)
                    mouseRelease(button, button.width / 2, button.height / 2)
                    mouseMove(window.contentItem, 320, 390)
                    tryCompare(button, "isHovered", false)
                    readable(button, highlight)
                }
                console.log("SHARED_HOVER_CONTRAST_PASSED")
            }

            function test_off_month_dates_remain_readable() {
                function offMonthButtons(item) {
                    let result = []
                    if (String(item).startsWith("CalendarDayButton") && item.isToday === -1)
                        result.push(item)
                    for (const child of item.children ?? [])
                        result = result.concat(offMonthButtons(child))
                    return result
                }
                function label(item) {
                    if (item.text !== undefined)
                        return item
                    for (const child of item.children ?? []) {
                        const found = label(child)
                        if (found !== null)
                            return found
                    }
                    return null
                }
                for (const month of [-1, 0, 1]) {
                    calendar.monthShift = month
                    const days = offMonthButtons(calendar)
                    verify(days.length > 0, "The calendar includes neighboring months")
                    for (const day of days) {
                        const text = label(day)
                        verify(text !== null)
                        const muted = Colors.withAlpha(Colors.overSurfaceVariant, 0.7)
                        tryVerify(() => ["r", "g", "b", "a"].every(channel =>
                            Math.abs(text.color[channel] - muted[channel]) <= 1 / 255))
                        for (const background of [Colors.background, Colors.surface]) {
                            const alpha = text.color.a
                            const first = luminance(Qt.rgba(
                                text.color.r * alpha + background.r * (1 - alpha),
                                text.color.g * alpha + background.g * (1 - alpha),
                                text.color.b * alpha + background.b * (1 - alpha), 1))
                            const second = luminance(background)
                            const ratio = (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05)
                            verify(ratio >= 3, "Off-month day " + day.day + " contrast is " + ratio.toFixed(2))
                            const normal = luminance(Colors.overSurface)
                            const normalRatio = (Math.max(normal, second) + 0.05) / (Math.min(normal, second) + 0.05)
                            verify(ratio < normalRatio, "Off-month dates are more muted than current-month dates")
                        }
                        verify(text.color !== Colors.overSurface, "Off-month dates remain visually secondary")
                    }
                }
                calendar.monthShift = 0
                console.log("CALENDAR_OFF_MONTH_CONTRAST_PASSED")
            }

            function cleanupTestCase() { Qt.quit() }
        }
        Timer {
            interval: 15000
            running: true
            onTriggered: { console.error("BUTTON_HOVER_TIMEOUT"); Qt.quit() }
        }
    }
}
'''


@unittest.skipUnless(shutil.which("qs") and shutil.which("dbus-run-session"),
                     "Quickshell and D-Bus are required for the runtime check")
class ButtonHoverRuntimeTests(unittest.TestCase):
    def test_hover_contrast_in_dark_and_light_palettes(self):
        for mode in ("dark", "light"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix="nonchalant-hover-") as directory:
                fixture = Path(directory)
                for name in ("modules", "config", "assets", "scripts", "version"):
                    (fixture / name).symlink_to(ROOT / name, target_is_directory=(ROOT / name).is_dir())
                (fixture / "shell.qml").write_text(QML)
                home = fixture / "home"
                config = home / ".config/nonchalant/config"
                config.mkdir(parents=True)
                # Existing installations have the old, unreadable foreground saved.
                (config / "theme.json").write_text(json.dumps({
                    "animDuration": 0, "lightMode": mode == "light",
                    "srPrimaryFocus": {"itemColor": "overPrimary"},
                }))
                (config / "bar.json").write_text(json.dumps({"style": "left"}))
                (config / "ai.json").write_text(json.dumps({"enabled": False}))
                palette = json.loads((ROOT / f"assets/colors/Catppuccin/{mode}.json").read_text())
                palette.update({
                    "background": "#282828" if mode == "dark" else "#f4f4f4",
                    "overBackground": "#ffffff" if mode == "dark" else "#1b1b1b",
                    "surface": "#282828" if mode == "dark" else "#e8e8e8",
                    "surfaceBright": "#383838" if mode == "dark" else "#d4d4d4",
                    "overSurface": "#e2e2e2" if mode == "dark" else "#1b1b1b",
                    "overSurfaceVariant": "#c4c4c4" if mode == "dark" else "#555555",
                    "primary": "#ffffff" if mode == "dark" else "#1b1b1b",
                    "overPrimary": "#1b1b1b" if mode == "dark" else "#ffffff",
                    "primaryContainer": "#d4d4d4" if mode == "dark" else "#474747",
                    "overPrimaryContainer": "#000000" if mode == "dark" else "#ffffff",
                })
                colors = home / ".cache/nonchalant"
                colors.mkdir(parents=True)
                (colors / "colors.json").write_text(json.dumps(palette))
                runtime = fixture / "runtime"
                runtime.mkdir(mode=0o700)
                bus_config = fixture / "dbus.conf"
                bus_config.write_text('<busconfig><type>session</type><auth>EXTERNAL</auth>'
                    f'<listen>unix:path={runtime / "bus"}</listen>'
                    '<policy context="default"><allow send_destination="*"/>'
                    '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
                env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"),
                       "XDG_STATE_HOME": str(home / ".local/state"), "XDG_DATA_HOME": str(home / ".local/share"),
                       "XDG_CACHE_HOME": str(home / ".cache"), "XDG_RUNTIME_DIR": str(runtime),
                       "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                       "NONCHALANT_COMPOSITOR": "niri", "NIRI_SOCKET": str(fixture / "no-compositor.sock")}
                for key in ("WAYLAND_DISPLAY", "WAYLAND_SOCKET", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE",
                            "DBUS_SESSION_BUS_ADDRESS", "DBUS_STARTER_ADDRESS", "DBUS_STARTER_BUS_TYPE"):
                    env.pop(key, None)
                result = subprocess.run(["dbus-run-session", f"--config-file={bus_config}", "--", "qs", "-p", str(fixture),
                                         "--no-duplicate", "--no-color"],
                                        env=env, capture_output=True, text=True, timeout=25)
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, output)
                self.assertIn("STANDALONE_HOVER_CONTRAST_PASSED", output, output)
                self.assertIn("SHARED_HOVER_CONTRAST_PASSED", output, output)
                self.assertIn("CALENDAR_OFF_MONTH_CONTRAST_PASSED", output, output)
                self.assertNotIn("FAIL!", output, output)
                self.assertNotIn("BUTTON_HOVER_TIMEOUT", output, output)
                self.assertNotIn("Binding loop", output, output)


if __name__ == "__main__":
    unittest.main()
