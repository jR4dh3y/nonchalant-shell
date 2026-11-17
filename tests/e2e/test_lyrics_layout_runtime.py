"""Exercise wrapped lyric sizing and scrolling with a private MPRIS player."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

from tests.e2e import test_mpris_runtime as mpris_runtime


ROOT = Path(__file__).resolve().parents[2]
QML = r'''
import QtQuick
import QtTest
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.dashboard

ShellRoot {
    FloatingWindow {
        visible: true
        color: Colors.background
        implicitWidth: 900
        implicitHeight: 650
        VerticalControlMenu {
            id: menu
            mode: "media"
            width: implicitWidth
            height: implicitHeight
        }
        LyricsView { id: bounded; x: 450; width: 364; height: 90; mode: "detail" }
        LyricsView { id: compact; x: 450; y: 150; width: 364; height: 22 }

        TestCase {
            name: "LyricsLayout"
            when: Config.initialLoadComplete && MprisController.activePlayer !== null

            function controlOfType(item, type) {
                if (String(item).startsWith(type)) return item
                for (const child of item.children ?? []) {
                    const found = controlOfType(child, type)
                    if (found) return found
                }
                return null
            }

            function setCue(text) {
                LyricsService.lines = [{t: 0, end: 200, text: text, words: []}]
                LyricsService.readFor = LyricsService.track
                LyricsService.synced = true
                LyricsService.status = "timed"
                LyricsService.current = 0
            }

            function verifyTop(list) {
                tryVerify(() => list.currentItem !== null)
                tryVerify(() => Math.abs(list.currentItem.y - list.contentY) < 1,
                    Config.animDuration + 1000, "Oversized cues must start at the top")
            }

            function snapshot(name) {
                const directory = Quickshell.env("NONCHALANT_LYRICS_SNAPSHOTS")
                if (directory) {
                    waitForRendering(menu)
                    wait(150)
                    grabImage(menu).save(directory + "/" + name + ".png")
                }
            }

            function verifyCurrentPaints(list) {
                if (Quickshell.env("NONCHALANT_LAYOUT_OPENGL") !== "1") return
                verify(menu.GraphicsInfo.api !== GraphicsInfo.Software)
                const text = findChild(list.currentItem, "detailLyricText")
                text.opacity = 0
                wait(100)
                const hidden = grabImage(menu)
                text.opacity = 1
                tryVerify(() => !grabImage(menu).equals(hidden), 2000,
                    "The active lyric must paint visible pixels")
            }

            function test_wrapped_cues_fit_or_scroll_and_shrink_again() {
                const stanza = "She'll be the death of me if I\nlet her stand any nearer\n"
                    + "Is this a fantasy or is that\nthe man in the mirror?\n"
                    + "Save yourself girl you won't\nsave us"
                setCue(stanza)
                menu.lyricsActive = true
                bounded.active = true
                compact.active = true
                const panel = findChild(menu, "verticalMediaCenter")
                verify(panel !== null)
                const lyrics = controlOfType(panel, "LyricsView")
                tryVerify(() => findChild(lyrics, "lyricLines") !== null)
                const list = findChild(lyrics, "lyricLines")
                tryVerify(() => list.currentItem !== null && list.currentItem.height > 140)
                tryVerify(() => lyrics.height >= list.currentItem.height,
                    1000, "The square panel must use its spare space for the whole stanza")
                tryVerify(() => list.currentItem.y - list.contentY >= -1
                    && list.currentItem.y + list.currentItem.height - list.contentY <= list.height + 1)
                compare(panel.height, panel.width, "A fitting cue must keep the panel square")
                compare(compact.implicitHeight, 22)

                LyricsService.lines = [
                    {t: 0, end: 40, text: "Because you know you're my\nmadonna yeah", words: []},
                    {t: 40, end: 60, text: "You want me crying in the\ncourthouse", words: []},
                    {t: 60, end: 90, text: "I'm tired of acting like we're\ncat and mouse", words: []}
                ]
                LyricsService.current = 1
                wait(Config.animDuration + 200)
                for (const index of [0, 1, 2]) {
                    const cue = list.itemAtIndex(index)
                    verify(cue !== null)
                    verify(cue.opacity > 0, "Fitting context must remain visible")
                    verify(cue.y - list.contentY >= -1,
                        "The previous lyric must be fully visible, including its top")
                    verify(cue.y + cue.height - list.contentY <= list.height + 1,
                        "The next lyric must be fully visible")
                }
                verifyCurrentPaints(list)
                snapshot("context-cues")

                LyricsService.lines = [
                    {t: 0, end: 20, text: stanza, words: []},
                    {t: 20, end: 40, text: stanza, words: []},
                    {t: 40, end: 60, text: "Current lyric", words: []},
                    {t: 60, end: 80, text: stanza, words: []},
                    {t: 80, end: 100, text: stanza, words: []}
                ]
                LyricsService.current = 2
                wait(Config.animDuration + 200)
                for (let index = 0; index < list.count; ++index) {
                    const cue = list.itemAtIndex(index)
                    if (cue && index !== list.currentIndex) {
                        const text = findChild(cue, "detailLyricText")
                        const top = text.mapToItem(lyrics, 0, 0).y
                        const bottom = text.mapToItem(lyrics, 0, text.height).y
                        if (top < 0 || bottom > lyrics.height)
                            compare(cue.opacity, 0, "Context must disappear before glyphs cross the clip edge")
                    }
                }
                verify(list.currentItem.opacity > 0, "The current lyric must stay visible")
                verifyCurrentPaints(list)
                snapshot("overflowing-context")

                setCue(stanza)

                const boundedList = findChild(bounded, "lyricLines")
                verifyTop(boundedList)
                verify(boundedList.interactive, "Height-limited cues must allow manual scrolling")
                const start = boundedList.contentY
                mouseDrag(boundedList, 30, 75, 0, -50, Qt.LeftButton)
                tryVerify(() => boundedList.contentY > start + 10,
                    1000, "Dragging must reveal the rest of a height-limited cue")

                setCue(stanza + "\n" + stanza + "\n" + stanza)
                tryVerify(() => list.currentItem.height > list.height)
                verifyTop(list)
                verify(list.interactive)
                const controls = findChild(panel, "mediaCenterPlayback")
                verify(controls.mapToItem(panel, 0, controls.height).y <= panel.height)

                setCue("Short lyric")
                tryCompare(lyrics, "implicitHeight", 140)
                tryCompare(list, "interactive", false)
                tryVerify(() => Math.abs(list.currentItem.y + list.currentItem.height / 2
                    - list.contentY - list.height / 2) < 1)
                compare(compact.implicitHeight, 22)

                LyricsService.synced = false
                LyricsService.status = "plain"
                tryCompare(list, "interactive", true)
                compare(lyrics.implicitHeight, 140)
                menu.lyricsActive = false
                bounded.active = false
                compact.active = false
                tryCompare(LyricsService, "watchers", 0)
                console.log("LYRICS_LAYOUT_RUNTIME_PASSED")
            }
            function cleanupTestCase() { Qt.quit() }
        }
    }
}
'''


@unittest.skipIf(getattr(mpris_runtime.MprisRuntimeTests, "__unittest_skip__", False),
                 "MPRIS runtime dependencies required")
class LyricsLayoutRuntimeTests(unittest.TestCase):
    def test_wrapped_cues_fit_or_scroll_and_shrink_again(self):
        self.run_runtime("software")

    @unittest.skipUnless(shutil.which("weston"), "Weston is required for private GPU rendering")
    def test_rendered_context_cues(self):
        self.run_runtime("opengl")

    def run_runtime(self, backend):
        with tempfile.TemporaryDirectory(prefix="nonchalant-lyrics-layout-") as directory:
            fixture = Path(directory)
            for name in ("modules", "config", "assets", "version"):
                (fixture / name).symlink_to(ROOT / name)
            (fixture / "shell.qml").write_text(QML)
            home = fixture / "home"
            home.mkdir()
            runtime = fixture / "runtime"
            runtime.mkdir(mode=0o700)
            env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / "config"),
                   "XDG_STATE_HOME": str(home / "state"), "XDG_DATA_HOME": str(home / "data"),
                   "XDG_CACHE_HOME": str(home / "cache"), "XDG_RUNTIME_DIR": str(runtime),
                   "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                   "NIRI_SOCKET": str(fixture / "no-compositor.sock"), "PYTHONPATH": str(ROOT)}
            for key in ("WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE"):
                env.pop(key, None)
            weston = None
            try:
                if backend == "opengl":
                    env.pop("QT_QUICK_BACKEND", None)
                    env.pop("DISPLAY", None)
                    env.pop("XAUTHORITY", None)
                    env.update(QT_QPA_PLATFORM="wayland", WAYLAND_DISPLAY="lyrics-test",
                               LIBGL_ALWAYS_SOFTWARE="1", GALLIUM_DRIVER="llvmpipe",
                               QSG_RHI_BACKEND="opengl", NONCHALANT_LAYOUT_OPENGL="1")
                    config = fixture / "weston.ini"
                    config.write_text("[core]\nidle-time=0\n[shell]\npanel-position=none\n")
                    with (fixture / "weston.log").open("w") as log:
                        weston = subprocess.Popen(
                            ["weston", "--backend=headless", "--renderer=gl", "--width=1000",
                             "--height=700", "--socket=lyrics-test", f"--config={config}"],
                            env=env, stdout=log, stderr=subprocess.STDOUT)
                    deadline = time.monotonic() + 10
                    while not (runtime / "lyrics-test").exists():
                        self.assertIsNone(weston.poll(), (fixture / "weston.log").read_text())
                        self.assertLess(time.monotonic(), deadline, "Private Weston socket did not appear")
                        time.sleep(0.05)
                result = subprocess.run(
                    ["dbus-run-session", "--", sys.executable, "-m",
                     "tests.e2e.test_lyrics_layout_runtime", "--exercise", str(fixture)],
                    env=env, capture_output=True, text=True, timeout=30)
            finally:
                if weston is not None:
                    weston.terminate()
                    weston.wait(timeout=5)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("LYRICS_LAYOUT_RUNTIME_PASSED", output)
            for error in ("FAIL!", "Binding loop", "TypeError", "Failed to link shader program",
                          "Failed to build graphics pipeline"):
                self.assertNotIn(error, output)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--exercise":
        sys.exit(mpris_runtime.exercise(Path(sys.argv[2]), success_marker="LYRICS_LAYOUT_RUNTIME_PASSED"))
    unittest.main()
