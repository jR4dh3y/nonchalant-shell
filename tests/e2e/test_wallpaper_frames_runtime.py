"""Exercise per-frame URL revisions in a private offscreen Quickshell."""

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
import qs.modules.globals

ShellRoot {
    QtObject {
        id: wallpaper
        FRAME_FUNCTIONS
    }
    TestCase {
        name: "WallpaperFrames"
        when: true
        function test_independent_revisions() {
            const a = "/wall/A.mp4";
            const b = "/wall/B.mp4";
            const image = "/wall/still.jpg";
            const beforeA = wallpaper.getLockscreenFrameUrl(a);
            const beforeB = wallpaper.getLockscreenFrameUrl(b);
            GlobalStates.bumpWallpaperFrameRevision(wallpaper.getLockscreenFramePath(a));
            const afterA = wallpaper.getLockscreenFrameUrl(a);
            verify(afterA !== beforeA);
            compare(wallpaper.getLockscreenFrameUrl(b), beforeB);
            GlobalStates.bumpWallpaperFrameRevision(wallpaper.getLockscreenFramePath(b));
            compare(wallpaper.getLockscreenFrameUrl(a), afterA);
            verify(wallpaper.getLockscreenFrameUrl(b) !== beforeB);
            compare(wallpaper.getLockscreenFrameUrl(image), "file://" + image);
            console.log("FRAME_REVISIONS_PASSED");
        }
        function cleanupTestCase() { Qt.quit(); }
    }
    Timer { interval: 10000; running: true; onTriggered: Qt.quit() }
}
'''
# Exercise the production URL functions without creating desktop PanelWindows.
wallpaper = (ROOT / "modules/widgets/dashboard/wallpapers/Wallpaper.qml").read_text()
functions = []
for name in ("getFileType", "getLockscreenFramePath", "getLockscreenFrameUrl"):
    start = wallpaper.index("    function " + name + "(")
    end = wallpaper.index("\n    }", start) + len("\n    }")
    functions.append(wallpaper[start:end])
QML = QML.replace("FRAME_FUNCTIONS", "\n".join(functions))


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for runtime checks")
class WallpaperFramesRuntimeTests(unittest.TestCase):
    def test_frame_revisions(self):
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
                ["dbus-run-session", "--", "qs", "-p", str(fixture), "--no-duplicate", "--no-color"],
                env=env, capture_output=True, text=True, timeout=25,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("FRAME_REVISIONS_PASSED", output, output)
            self.assertNotIn("FAIL!", output, output)


if __name__ == "__main__":
    unittest.main()
