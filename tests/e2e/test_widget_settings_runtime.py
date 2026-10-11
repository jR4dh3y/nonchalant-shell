"""Verify widget settings navigation without the settings redesign."""

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
import qs.modules.globals
import qs.modules.services
import qs.modules.widgets.dashboard.controls

ShellRoot {
    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 800
        SettingsTab { id: settings; anchors.fill: parent }
        TestCase {
            name: "WidgetSettingsRuntime"
            when: Config.initialLoadComplete
            function panel(item, filename) {
                if (item.source !== undefined && item.source.toString().endsWith(filename)
                    && item.visible && item.item)
                    return item.item
                for (const child of item.children ?? []) {
                    const match = panel(child, filename)
                    if (match)
                        return match
                }
                return null
            }
            function test_existing_settings_with_widget_page() {
                verify(Config.desktop !== undefined)
                verify(Config.bar.lyricsEnabled === undefined)
                verify(Config.lockscreen.lyricsEnabled === undefined)
                GlobalStates.openSettings("theme", "general")
                tryCompare(settings, "currentSection", 4, 5000)
                tryVerify(() => panel(settings, "ThemePanel.qml")?.currentSection === "general", 5000)
                GlobalStates.openSettings("theme", "colors")
                tryVerify(() => panel(settings, "ThemePanel.qml")?.currentSection === "colors", 5000)
                GlobalStates.openSettings("desktop", "modules")
                tryCompare(settings, "currentSection", 7, 5000)
                tryVerify(() => panel(settings, "DesktopSettingsPage.qml")?.currentSection === "modules", 5000)
                GlobalStates.openSettings("desktop", "widgets")
                tryVerify(() => panel(settings, "DesktopSettingsPage.qml")?.currentSection === "widgets", 5000)
                settings.searchQuery = "desktop"
                verify(settings.filteredSections.some(section => section.section === 7))
                console.log("WIDGET_SETTINGS_RUNTIME_PASSED")
                Qt.quit()
            }
        }
    }
    Timer {
        interval: 15000
        running: true
        onTriggered: { console.error("WIDGET_SETTINGS_RUNTIME_TIMEOUT"); Qt.quit() }
    }
}
'''


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for runtime checks")
class WidgetSettingsRuntimeTests(unittest.TestCase):
    def test_existing_settings_navigation_and_desktop_page(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-widget-settings-") as directory:
            fixture = Path(directory)
            for name in ("modules", "config", "assets", "scripts", "version"):
                (fixture / name).symlink_to(ROOT / name, target_is_directory=(ROOT / name).is_dir())
            (fixture / "shell.qml").write_text(QML)
            home = fixture / "home"
            home.mkdir()
            runtime = fixture / "runtime"
            runtime.mkdir(mode=0o700)
            env = {
                **os.environ,
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_STATE_HOME": str(home / ".local/state"),
                "XDG_DATA_HOME": str(home / ".local/share"),
                "XDG_CACHE_HOME": str(home / ".cache"),
                "XDG_RUNTIME_DIR": str(runtime),
                "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(runtime / "no-session-bus"),
                "QT_QPA_PLATFORM": "offscreen",
                "QT_QUICK_BACKEND": "software",
                "NIRI_SOCKET": str(fixture / "no-compositor.sock"),
            }
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(
                ["qs", "-p", str(fixture), "--no-duplicate", "--no-color"],
                env=env, capture_output=True, text=True, timeout=25,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("WIDGET_SETTINGS_RUNTIME_PASSED", output, output)
            self.assertNotIn("WIDGET_SETTINGS_RUNTIME_TIMEOUT", output, output)
            self.assertNotIn("FAIL!", output, output)


if __name__ == "__main__":
    unittest.main()
