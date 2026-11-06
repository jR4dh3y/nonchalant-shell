"""Exercise the Niri window-chrome color file written from the palette."""

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

ShellRoot {
    NiriGenerator {
        id: generator
    }

    QtObject {
        id: helper
        function palette(hex) {
            return { primary: Qt.color(hex), outlineVariant: Qt.color("#333333"), error: Qt.color("#ff0000") };
        }
    }

    TestCase {
        name: "NiriColors"
        when: Config.initialLoadComplete

        function test_startup_write_without_palette_cache() {
            // colors.json is missing, so Colors only gets loadFailed; the
            // startup write must still happen from the fallback colors.
            tryVerify(() => Colors.niriStartupWritten, 5000)
            tryVerify(() => !Colors.niriGenerator.writerProcess.running, 5000)
            // A later reload (as on every palette change) must not write
            // again; generationTimer owns change-driven writes.
            Colors.reload()
            wait(300)
            compare(Colors.niriGenerator.writerProcess.running, false, "reload must not rewrite outside generationTimer")
            console.log("NIRI_STARTUP_PASSED")
        }

        function test_newest_palette_wins_while_writing() {
            // Same output file as the startup write; let that finish first.
            tryVerify(() => Colors.niriStartupWritten && !Colors.niriGenerator.writerProcess.running, 5000)
            generator.generate(helper.palette("#111111"))
            verify(generator.writerProcess.running, "first write starts")
            generator.generate(helper.palette("#222222"))
            generator.generate(helper.palette("#abcdef"))
            tryVerify(() => !generator.writerProcess.running && generator.pendingCommand.length === 0, 5000)
            console.log("NIRI_QUEUE_PASSED")
        }

        function cleanupTestCase() {
            Qt.quit()
        }
    }

    Timer {
        interval: 15000
        running: true
        onTriggered: { console.error("NIRI_RUNTIME_TIMEOUT"); Qt.quit() }
    }
}
'''


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for runtime checks")
class NiriColorsRuntimeTests(unittest.TestCase):
    def test_niri_colors_file(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-niri-colors-") as directory:
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
            }
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(
                ["qs", "-p", str(fixture), "--no-duplicate", "--no-color"],
                env=env, capture_output=True, text=True, timeout=25,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("NIRI_STARTUP_PASSED", output, output)
            self.assertIn("NIRI_QUEUE_PASSED", output, output)
            self.assertNotIn("NIRI_RUNTIME_TIMEOUT", output, output)
            self.assertNotIn("NiriGenerator Error", output, output)

            written = (home / ".cache/nonchalant/niri-colors.kdl").read_text()
            # The last palette requested mid-write is what lands on disk.
            self.assertIn('active-color "#abcdefff"', written)
            self.assertIn("focus-ring {", written)
            self.assertIn("recent-windows {", written)


if __name__ == "__main__":
    unittest.main()
