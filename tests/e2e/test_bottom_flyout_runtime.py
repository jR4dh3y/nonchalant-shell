"""Check bottom flyout origins on a disposable Wayland compositor."""

from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tests.e2e.test_bar_text_runtime import install_fake_audio_nodes, install_fake_brightness_monitors
from tests.runtime.run_compositor import Session, private_environment, start_compositor

QML = r'''
import QtQuick
import QtTest
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.theme
import qs.modules.widgets.powermenu
import qs.modules.shell.osd

ShellRoot {
    QtObject { id: panel; property ShellScreen targetScreen: Quickshell.screens[0] }
    OSD { id: osd; targetScreen: panel.targetScreen }
    FloatingWindow {
        visible: true
        implicitWidth: 100
        implicitHeight: 100
        PowerMenuHost { id: power; panel: panel }
        TestCase {
            name: "BottomFlyoutOrigin"
            when: Config.initialLoadComplete

            function bottomGap(surface) {
                return surface.parent.height - surface.body.mapToItem(surface.parent, 0, surface.body.height).y
            }

            function checkOpening(surface) {
                tryVerify(() => surface.progress > 0 && surface.progress < 1)
                const gap = bottomGap(surface)
                verify(gap > 0 && gap < 48, "Reveal must travel from the screen edge, not start at the resting gap")
                tryCompare(surface, "progress", 1)
                compare(bottomGap(surface), 48)
            }

            function checkClosing(surface) {
                tryVerify(() => surface.progress > 0 && surface.progress < 1)
                verify(bottomGap(surface) < 48, "Closing must return toward the screen edge")
                tryCompare(surface, "progress", 0)
                compare(bottomGap(surface), 0)
            }

            function test_bottom_origins() {
                try {
                    Config.bar.style = "left"
                    Config.animDuration = 400
                    const powerSurface = findChild(power, "powerMenuMorph")
                    const osdSurface = findChild(osd, "osdMorph")
                    verify(powerSurface !== null && osdSurface !== null)
                    compare(bottomGap(powerSurface), 0)
                    power.openMenu()
                    checkOpening(powerSurface)
                    power.closeMenu()
                    checkClosing(powerSurface)
                    GlobalStates.osdIndicator = "volume"
                    GlobalStates.osdVisible = true
                    checkOpening(osdSurface)
                    GlobalStates.osdVisible = false
                    checkClosing(osdSurface)
                    // A reversal must continue from the current edge offset.
                    power.openMenu()
                    tryVerify(() => powerSurface.progress > 0.15 && powerSurface.progress < 1)
                    const before = bottomGap(powerSurface)
                    power.closeMenu()
                    verify(Math.abs(bottomGap(powerSurface) - before) < 1)
                    tryCompare(powerSurface, "progress", 0)
                    compare(bottomGap(powerSurface), 0)
                    Config.animDuration = 0
                    power.openMenu()
                    tryCompare(powerSurface, "progress", 1)
                    compare(bottomGap(powerSurface), 48)
                    power.closeMenu()
                    tryCompare(powerSurface, "progress", 0)
                    console.log("BOTTOM_FLYOUT_ORIGINS_PASSED")
                } catch (error) {
                    console.error("BOTTOM_FLYOUT_ASSERTION", error.stack)
                }
                Qt.quit()
            }
        }
    }
    Timer {
        interval: 15000
        running: true
        onTriggered: { console.error("BOTTOM_FLYOUT_TIMEOUT"); Qt.quit() }
    }
}
'''


def exercise(fixture):
    session = Session(fixture, shutil.which("qs"))
    try:
        start_compositor(session, "niri")
        session.env["NONCHALANT_COMPOSITOR"] = "niri"
        process = session.start("flyouts", [session.quickshell, "-p", str(fixture / "shell"),
                                            "--no-duplicate", "--no-color"])
        process.wait(timeout=20)
        output = (fixture / "flyouts.log").read_text()
        print(output)
        return 0 if process.returncode == 0 and "BOTTOM_FLYOUT_ORIGINS_PASSED" in output else 1
    finally:
        session.stop()


@unittest.skipUnless(all(shutil.which(tool) for tool in ("qs", "weston", "niri", "dbus-run-session")),
                     "Quickshell, Weston, Niri, and D-Bus are required")
class BottomFlyoutRuntimeTests(unittest.TestCase):
    def test_reveal_and_retract_at_screen_edge(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-flyouts-") as directory:
            fixture = Path(directory)
            env = private_environment(fixture)
            env["DBUS_SYSTEM_BUS_ADDRESS"] = "unix:path=" + str(fixture / "no-system-bus")
            shell = fixture / "shell"
            shell.mkdir()
            for name in ("config", "assets", "scripts", "version"):
                (shell / name).symlink_to(ROOT / name, target_is_directory=(ROOT / name).is_dir())
            modules = shell / "modules"
            modules.mkdir()
            for source in (ROOT / "modules").iterdir():
                if source.name != "services":
                    (modules / source.name).symlink_to(source, target_is_directory=source.is_dir())
            shutil.copytree(ROOT / "modules/services", modules / "services")
            install_fake_audio_nodes(modules / "services/Audio.qml")
            install_fake_brightness_monitors(modules / "services/Brightness.qml")
            (shell / "shell.qml").write_text(QML)
            bus_config = fixture / "dbus.conf"
            bus_config.write_text('<busconfig><type>session</type><auth>EXTERNAL</auth>'
                f'<listen>unix:path={Path(env["XDG_RUNTIME_DIR"]) / "bus"}</listen>'
                '<policy context="default"><allow send_destination="*"/>'
                '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
            try:
                result = subprocess.run(["dbus-run-session", f"--config-file={bus_config}", "--",
                    sys.executable, __file__, "--exercise", str(fixture)],
                    env=env, capture_output=True, text=True, timeout=45)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            finally:
                shutil.rmtree(env["XDG_RUNTIME_DIR"])


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--exercise":
        raise SystemExit(exercise(Path(sys.argv[2])))
    unittest.main()
