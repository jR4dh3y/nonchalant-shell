"""Run the shared focus stack in Quickshell, including separate-window grabs."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required")
class TestFocusGrabManager(unittest.TestCase):
    def test_input_ownership_and_dismissal(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-focus-test-") as directory:
            config = Path(directory)
            services = config / "modules" / "services"
            services.mkdir(parents=True)
            shutil.copyfile(ROOT / "modules/services/FocusGrabManager.qml",
                            services / "FocusGrabManager.qml")
            (config / "shell.qml").write_text('''
import QtQuick
import Quickshell
import qs.modules.services

ShellRoot {
    property int dismissed: 0

    function verify(condition: bool, message: string): void {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: Qt.callLater(() => {
        try {
            verify(!FocusGrabManager.hasActiveGrab && !FocusGrabManager.hasPanelGrab, "initial state")
            FocusGrabManager.requestGrab("desktop", () => { dismissed += 1 }, false)
            verify(FocusGrabManager.hasActiveGrab && !FocusGrabManager.hasPanelGrab, "desktop owns input")
            FocusGrabManager.requestGrab("popup", () => { dismissed += 10 })
            verify(FocusGrabManager.hasPanelGrab, "popup owns panel backdrop")
            FocusGrabManager.requestGrab("details", () => { dismissed += 100 }, false)
            verify(FocusGrabManager.hasPanelGrab, "independent window keeps underlying panel grab")
            FocusGrabManager.releaseGrab("details")
            FocusGrabManager.clearTopGrab()
            verify(FocusGrabManager.hasActiveGrab && !FocusGrabManager.hasPanelGrab, "desktop input restored")
            Qt.callLater(() => {
                try {
                    verify(dismissed === 10, "top callback fired once")
                    FocusGrabManager.clearTopGrab()
                    verify(!FocusGrabManager.hasActiveGrab && !FocusGrabManager.hasPanelGrab, "all input released")
                    Qt.callLater(() => {
                        if (dismissed === 11)
                            console.log("FOCUS_INPUT_OWNERSHIP_PASS")
                        else
                            console.error("wrong dismissal count", dismissed)
                        Qt.quit()
                    })
                } catch (error) {
                    console.error(error)
                    Qt.quit()
                }
            })
        } catch (error) {
            console.error(error)
            Qt.quit()
        }
    })
}
''')
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
            result = subprocess.run(["qs", "--no-color", "-p", str(config)],
                                    env=env, text=True, capture_output=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("FOCUS_INPUT_OWNERSHIP_PASS", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
