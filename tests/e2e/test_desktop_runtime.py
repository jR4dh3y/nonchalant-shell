"""Exercise desktop placement and monitor demand in an isolated Quickshell process."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]

QML = r"""
import QtQuick
import QtTest
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services

ShellRoot {
    FloatingWindow {
        visible: true
        implicitWidth: 800
        implicitHeight: 600
        TestCase {
            name: "DesktopRuntime"
            when: Config.initialLoadComplete

            function test_placement() {
                const svc = DesktopWidgetService
                const name = svc.fallbackOutput
                svc.boards = ({[name]: {width: 426, height: 426}})
                svc.widgets = [
                    {key: "media-a", id: "media", screen: name, family: "4x4", col: 0, row: 0},
                    {key: "media-b", id: "media", screen: name, family: "4x4", col: 0, row: 0}
                ]
                const a = svc.geometry(svc.widgets[0], 426, 426)
                const b = svc.geometry(svc.widgets[1], 426, 426)
                verify(a.valid !== b.valid, "A cramped board must not draw overlapping widgets")
                compare(svc.widgets.length, 2, "Overflow widgets must remain saved")
                compare(svc.firstFree(name, "4x4"), null)
                svc.boards = ({[name]: {width: 850, height: 426}})
                const expandedA = svc.geometry(svc.widgets[0], 850, 426)
                const expandedB = svc.geometry(svc.widgets[1], 850, 426)
                verify(expandedA.valid && expandedB.valid)
                verify(expandedA.x + expandedA.width <= expandedB.x
                    || expandedB.x + expandedB.width <= expandedA.x)
                compare(svc.nearestFree(name, 0, 0, "4x4", "media-a").col, 0)
                compare(svc.nearestFree(name, 0, 0, "4x4"), null)
                console.log("PLACEMENT_RUNTIME_PASSED")
            }

            function test_resource_demand_survives_restart() {
                const monitor = SystemResources
                verify(!GlobalStates.systemMonitorOpen)
                GlobalStates.islandStatsOpen = false
                monitor.subscribe()
                tryVerify(() => monitor.monitorProcess.processId > 0, 5000)
                monitor.updateInterval += 1
                monitor.release()
                tryVerify(() => !monitor.restartPending && monitor.monitorProcess.processId === null, 5000)
                wait(100)
                verify(!monitor.monitorProcess.running, "Released demand must not restart the monitor")
                monitor.subscribe()
                tryVerify(() => monitor.monitorProcess.processId > 0, 5000)
                monitor.release()
                tryVerify(() => monitor.monitorProcess.processId === null, 5000)
                console.log("MONITOR_RUNTIME_PASSED")
                Qt.quit()
            }
        }
    }
    Timer {
        interval: 20000
        running: true
        onTriggered: { console.error("DESKTOP_RUNTIME_TIMEOUT"); Qt.quit() }
    }
}
"""


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for runtime checks")
class DesktopRuntimeTests(unittest.TestCase):
    def test_placement_and_monitor_lifecycle(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-desktop-test-") as directory:
            fixture = Path(directory)
            for name in ("modules", "config", "assets", "scripts", "version"):
                (fixture / name).symlink_to(ROOT / name, target_is_directory=(ROOT / name).is_dir())
            (fixture / "shell.qml").write_text(QML)
            home = fixture / "home"
            home.mkdir()
            env = {
                **os.environ,
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_STATE_HOME": str(home / ".local/state"),
                "XDG_DATA_HOME": str(home / ".local/share"),
                "XDG_CACHE_HOME": str(home / ".cache"),
                "QT_QPA_PLATFORM": "offscreen",
                "QT_QUICK_BACKEND": "software",
                "NIRI_SOCKET": str(fixture / "no-compositor.sock"),
            }
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(
                ["qs", "-p", str(fixture), "--no-duplicate", "--no-color"],
                env=env, capture_output=True, text=True, timeout=30,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("PLACEMENT_RUNTIME_PASSED", output, output)
            self.assertIn("MONITOR_RUNTIME_PASSED", output, output)
            self.assertNotIn("DESKTOP_RUNTIME_TIMEOUT", output, output)


if __name__ == "__main__":
    unittest.main()
