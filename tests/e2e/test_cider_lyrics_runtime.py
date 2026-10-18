"""Run the production lyrics helper and QML views against private MPRIS players."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tests.e2e import test_mpris_runtime as mpris_runtime


ROOT = Path(__file__).resolve().parents[2]
QML = r'''
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.theme
import qs.modules.widgets.dashboard.widgets

ShellRoot {
    FloatingWindow {
        visible: true
        color: Colors.background
        implicitWidth: 800
        implicitHeight: 500
        LyricsView { id: compact; width: 350; height: 22 }
        LyricsView { id: detail; width: 350; height: 140; y: 40; mode: "detail" }
        LockPlayer { id: lock; width: 350; y: 220 }
        Process { id: control }
        TestCase {
            name: "CiderLyricsRuntime"
            when: Config.initialLoadComplete && MprisController.filteredPlayers.length === 2

            function update(method, argument) {
                control.command = ["gdbus", "call", "--session", "--dest",
                    "org.mpris.MediaPlayer2.cider", "--object-path", "/org/mpris/MediaPlayer2",
                    "--method", "org.nonchalant.Test." + method, String(argument)]
                control.running = true
                tryCompare(control, "running", false, 2000)
                wait(30)
            }

            function controlOfType(item, type) {
                if (String(item).startsWith(type))
                    return item
                for (const child of item.children ?? []) {
                    const found = controlOfType(child, type)
                    if (found)
                        return found
                }
                return null
            }

            function test_cider_words_follow_playback_and_provider_switches() {
                try {
                    MprisController.trackedPlayer = MprisController.filteredPlayers.find(
                        player => player.dbusName === "org.mpris.MediaPlayer2.cider")
                    compare(LyricsService.ciderPlayer, true)
                    compare(LyricsService.ciderTrackId, "1")
                    update("SetDuration", 12)
                    update("MovePosition", 0)
                    compact.active = true
                    detail.active = true
                    tryCompare(LyricsService, "status", "timed", 5000)
                    compare(LyricsService.source, "cider")
                    compare(LyricsService.lead, 0)
                    compare(LyricsService.lines[0].words.length, 2)
                    compare(LyricsService.current, 0)
                    const text = findChild(compact, "compactLyricText")
                    verify(text !== undefined)
                    tryVerify(() => text.text === "One <two>" && text.characterProgress < 3)
                    if (text.GraphicsInfo.api !== GraphicsInfo.Software) {
                        waitForRendering(text)
                        const unfilled = grabImage(text)
                        verify(LyricsService.seekTo(1.5))
                        wait(Config.animDuration + 50)
                        verify(!grabImage(text).equals(unfilled), "The GPU shader must visibly fill the text")
                        const filled = grabImage(text)
                        wait(120)
                        verify(grabImage(text).equals(filled), "Paused GPU fill must remain unchanged")
                        const snapshots = Quickshell.env("NONCHALANT_LYRICS_SNAPSHOTS")
                        if (snapshots) grabImage(detail).save(snapshots + "/lyrics-fluid.png")
                        console.log("CIDER_LYRICS_GPU_PASSED")
                        verify(LyricsService.seekTo(0))
                    }
                    update("MovePosition", 1)
                    tryVerify(() => text.characterProgress >= 4 && text.characterProgress < 9)
                    compare(text.text, "One <two>", "Word progress must not rebuild text markup")
                    verify(text.fluidEnabled, "Pausing must preserve the shader fill")
                    const pausedProgress = text.characterProgress
                    wait(180)
                    compare(text.characterProgress, pausedProgress, "Paused playback must not advance words")
                    const geometry = text.geometryGeneration
                    compact.phase += 1
                    verify(LyricsService.seekTo(1.25))
                    wait(80)
                    compare(text.geometryGeneration, geometry, "Shader updates must not rebuild text geometry")
                    verify(!findChild(detail, "compactLyricText").fluidEnabled,
                        "The hidden compact label must not render a second shader")
                    compact.width = 40
                    tryVerify(() => text.width > compact.width && text.x < 0, 1000)
                    verify(!text.truncated, "Long word-timed lines must follow the current word")
                    compact.width = 350
                    verify(LyricsService.seekTo(0))
                    tryVerify(() => text.text === "One <two>" && text.characterProgress < 3)
                    update("SetPlayback", "Playing")
                    tryVerify(() => text.characterProgress >= 4, 2000)
                    update("SetPlayback", "Paused")
                    verify(LyricsService.seekTo(0))
                    update("SetPlayback", "Playing")
                    update("SetRate", 2)
                    const rateStart = LyricsService.playbackPosition
                    const rateTime = Date.now()
                    wait(250)
                    const expectedPosition = rateStart + (Date.now() - rateTime) / 1000 * 2
                    verify(Math.abs(LyricsService.playbackPosition - expectedPosition) < 0.08,
                        "Lyrics must follow the player's rate rather than another wall clock")
                    verify(Math.abs(LyricsService.playbackPosition - MprisController.activePlayer.position) < 0.08)
                    update("SetRate", 0.5)
                    const slowStart = LyricsService.playbackPosition
                    const slowTime = Date.now()
                    wait(250)
                    verify(Math.abs(LyricsService.playbackPosition - slowStart
                        - (Date.now() - slowTime) / 1000 * 0.5) < 0.08,
                        "Slow playback must not use a normal-speed lyric clock")
                    update("SetPlayback", "Paused")
                    update("MovePosition", 3)
                    tryCompare(LyricsService, "current", 1)
                    compare(LyricsService.lines[1].text, "", "Explicit TTML ends must create a timed gap")
                    compare(compact.compactText, "", "An interlude must not retain an ended lyric")
                    verify(findChild(compact, "compactInterlude").visible)
                    verify(!text.visible, "Music dots replace the lyric, rather than underlining it")
                    const lines = findChild(detail, "lyricLines")
                    tryCompare(lines, "currentIndex", 1)
                    verify(findChild(lines.currentItem, "lineInterlude").visible)
                    const snapshots = Quickshell.env("NONCHALANT_LYRICS_SNAPSHOTS")
                    if (snapshots) grabImage(detail).save(snapshots + "/lyrics-interlude.png")
                    compare(compact.isMusicInterlude, true, "Blank timed lines must show music dots")
                    update("MovePosition", 4)
                    tryCompare(LyricsService, "current", 2)
                    tryCompare(text, "text", "Last line")
                    compare(findChild(compact, "compactInterlude").visible, false)
                    verify(LyricsService.seekTo(3.9))
                    tryCompare(LyricsService, "current", 1)
                    update("SetPlayback", "Playing")
                    tryCompare(LyricsService, "current", 2, 1000)
                    verify(text.parent.entryOffset > 0,
                        "The next compact lyric must enter from the right")
                    verify(text.parent.mapToItem(compact, 0, 0).x > 0)
                    tryCompare(text.parent, "entryOffset", 0, Config.animDuration + 500)
                    update("SetPlayback", "Paused")
                    verify(LyricsService.seekTo(4.75))
                    detail.width = 40
                    const wrapped = findChild(lines.currentItem, "detailLyricText")
                    tryVerify(() => wrapped.lineCount > 1)
                    tryVerify(() => wrapped.fillCursor.y > 0,
                        1000, "The fill must reach the second rendered row")
                    tryVerify(() => Math.abs(lines.currentItem.y + lines.currentItem.height / 2
                        - lines.contentY - lines.height / 2) < 1, 1000,
                        "The entire wrapped lyric must be centered")
                    detail.width = 350
                    verify(LyricsService.seekTo(6))
                    tryCompare(LyricsService, "current", 3)
                    verify(findChild(compact, "compactInterlude").visible, "Explicit ends must preserve the outro")
                    const intro = LyricsService.withInterludes([{t: 2, end: 3, text: "Verse", words: []}], 12)
                    compare(intro[0].text, "")
                    compare(intro[0].t, 0)
                    compare(intro[0].end, 2)
                    const lineTimed = LyricsService.withInterludes([
                        {t: 0, end: -1, text: "One", words: []},
                        {t: 8, end: -1, text: "Two", words: []}], 0)
                    compare(lineTimed.length, 2, "Unknown line ends must not invent instrumental breaks")
                    const breathingGap = LyricsService.withInterludes([
                        {t: 0, end: 2, text: "One", words: []},
                        {t: 2.08, end: 4, text: "Two", words: []}], 4)
                    compare(breathingGap.length, 2, "An 80 ms breath must not become a dot row")
                    const explicitCue = LyricsService.withInterludes([
                        {t: 0, end: 2, text: "One", words: []},
                        {t: 2, end: 2.08, text: "", words: []},
                        {t: 2.08, end: 4, text: "Two", words: []}], 4)
                    compare(explicitCue[1].text, "", "Explicit blank API cues must be preserved")
                    const unknownDuration = LyricsService.withInterludes([{t: 0, end: 2, text: "Verse", words: []}], 0)
                    compare(unknownDuration[1].text, "")
                    compare(unknownDuration[1].t, 2)
                    compare(unknownDuration[1].end, -1, "An outro must not invent a missing track duration")
                    verify(LyricsService.seekTo(0))
                    tryVerify(() => text.text === "One <two>" && text.characterProgress < 3)
                    tryCompare(lines, "currentIndex", 0)
                    const detailText = findChild(lines.currentItem, "detailLyricText")
                    tryVerify(() => detailText.text === "One <two>" && detailText.characterProgress < 3)
                    // Reproduce Cider silently correcting its exported position.
                    // A 500 ms correction is below Cider's 1.5 s Seeked threshold.
                    verify(LyricsService.seekTo(3.5))
                    wait(40)
                    update("SilentMovePosition", 4)
                    verify(Math.abs(MprisController.activePlayer.position - 3.5) < 0.1)
                    tryCompare(LyricsService, "current", 2, 1500)
                    verify(Math.abs(LyricsService.playbackPosition - 4) < 0.1)
                    compare(text.text, "Last line")
                    tryCompare(lines, "currentIndex", 2)
                    update("SetPlayback", "Playing")
                    update("SilentMovePosition", 3)
                    tryCompare(LyricsService, "current", 1, 1000)
                    verify(LyricsService.playbackPosition >= 3 && LyricsService.playbackPosition < 4,
                        "A silent backward correction must also work during playback")
                    update("SetPlayback", "Paused")
                    verify(LyricsService.seekTo(0))
                    tryCompare(LyricsService, "current", 0)
                    Config.lockscreen.lyricsEnabled = true
                    GlobalStates.lockscreenVisible = true
                    tryCompare(LyricsService, "watchers", 3)
                    const lockLyrics = controlOfType(lock, "LyricsView")
                    compare(lockLyrics.mode, "compact")
                    const lockText = findChild(lockLyrics, "compactLyricText")
                    tryVerify(() => lockText.text === "One <two>" && lockText.characterProgress < 3)
                    verify(!lockText.truncated)
                    update("SetTrack", 100)
                    tryVerify(() => LyricsService.readFor === LyricsService.track && LyricsService.source === "lrclib", 5000)
                    compare(LyricsService.lines[0].text, "Fallback")
                    compare(LyricsService.lines[0].words.length, 0)
                    CiderPosition.refresh()
                    MprisController.trackedPlayer = MprisController.filteredPlayers.find(
                        player => player.dbusName === "org.mpris.MediaPlayer2.nonchalant_test")
                    compare(LyricsService.ciderPlayer, false)
                    tryCompare(CiderPosition, "enabled", false)
                    tryCompare(CiderPosition, "queryActive", false)
                    compare(CiderPosition.sampleAt, 0)
                    compare(LyricsService.ciderTrackId, "")
                    tryVerify(() => LyricsService.readFor === LyricsService.track && LyricsService.source === "lrclib", 5000)
                    compare(LyricsService.lines[0].text, "Fallback")
                    verify(!text.text.includes("<font"), "Cider word highlighting must not leak into another player")
                    MprisController.trackedPlayer = MprisController.filteredPlayers.find(
                        player => player.dbusName === "org.mpris.MediaPlayer2.cider")
                    tryCompare(CiderPosition, "enabled", true)
                    compact.active = false
                    detail.active = false
                    GlobalStates.lockscreenVisible = false
                    tryCompare(LyricsService, "watchers", 0)
                    tryCompare(LyricsService, "queryActive", false)
                    tryCompare(CiderPosition, "enabled", false)
                    tryCompare(CiderPosition, "queryActive", false)
                    console.log("CIDER_LYRICS_RUNTIME_PASSED")
                    Qt.quit()
                } catch (error) {
                    console.error("CIDER_ASSERTION", error.message, error.stack)
                    throw error
                }
            }
        }
    }
    Timer { interval: 15000; running: true; onTriggered: { console.error("CIDER_TIMEOUT"); Qt.quit() } }
}
'''

BACKEND = r'''
import json, sys
from pathlib import Path
root = Path(sys.argv.pop(1))
sys.path.insert(0, str(root / "scripts"))
import cider_lyrics

def request(url, headers):
    if url.endswith("/now-playing"):
        return {"info": {"name": "Ella Langley - Choosin' Texas (Official Video)",
                         "artistName": "EllaLangleyVEVO", "playParams": {"id": "1"}}}
    if url.endswith("/tokens"):
        return {"data": {"developerToken": "fixture", "userToken": "fixture", "storefront": "us"}}
    return {"data": [{"attributes": {"ttml": '<tt xmlns="http://www.w3.org/ns/ttml"><body><p begin="0" end="2"><span begin="0" end="1">One</span> <span begin="1" end="2">&lt;two&gt;</span></p><p begin="4" end="5">Last line</p></body></tt>'}}]}

cider_lyrics.request_json = request
import lyrics
lyrics.lookup = lambda *args, **kwargs: {"syncedLyrics": "[00:00]Fallback"}
args = sys.argv[1:]
print(json.dumps(lyrics.report(args[0], args[1], args[2], float(args[3]), args[4],
                              args[5] if len(args) > 5 else None)))
'''


@unittest.skipIf(getattr(mpris_runtime.MprisRuntimeTests, "__unittest_skip__", False), "MPRIS runtime dependencies required")
class CiderLyricsRuntimeTests(unittest.TestCase):
    def test_word_highlighting_seek_pause_interludes_and_player_switch(self):
        self.run_runtime("software")

    @unittest.skipUnless(os.environ.get("DISPLAY"), "An X display is required for the OpenGL rendering check")
    def test_gpu_shader_fill(self):
        self.run_runtime("rhi")

    def run_runtime(self, backend):
        with tempfile.TemporaryDirectory(prefix="nonchalant-cider-runtime-") as directory:
            fixture = Path(directory)
            for name in ("modules", "config", "assets", "version"):
                (fixture / name).symlink_to(ROOT / name, target_is_directory=(ROOT / name).is_dir())
            scripts = fixture / "scripts"
            scripts.mkdir()
            # Production QML invokes this thin helper with the usual metadata arguments.
            (scripts / "lyrics.py").write_text(
                BACKEND.replace('root = Path(sys.argv.pop(1))', f'root = Path({str(ROOT)!r})'))
            (fixture / "shell.qml").write_text(QML)
            home = fixture / "home"
            home.mkdir()
            runtime = fixture / "runtime"
            runtime.mkdir(mode=0o700)
            env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"),
                   "XDG_STATE_HOME": str(home / "state"), "XDG_DATA_HOME": str(home / "data"),
                   "XDG_CACHE_HOME": str(home / "cache"), "XDG_RUNTIME_DIR": str(runtime),
                   "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": backend,
                   "NIRI_SOCKET": str(fixture / "no-compositor.sock"), "PYTHONPATH": str(ROOT)}
            env.pop("WAYLAND_DISPLAY", None)
            env.pop("DBUS_SESSION_BUS_ADDRESS", None)
            env.pop("CIDER_API_TOKEN_FILE", None)
            if backend == "rhi":
                env.pop("QT_QUICK_BACKEND", None)
                env["QSG_RHI_BACKEND"] = "opengl"
                env["QT_QPA_PLATFORM"] = "xcb"
            result = subprocess.run(
                ["dbus-run-session", "--", sys.executable, "-m", "tests.e2e.test_cider_lyrics_runtime",
                 "--exercise", str(fixture)], env=env, capture_output=True, text=True, timeout=25)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("CIDER_LYRICS_RUNTIME_PASSED", output, output)
            if backend == "rhi":
                self.assertIn("CIDER_LYRICS_GPU_PASSED", output, output)
            self.assertNotIn("Binding loop", output, output)
            self.assertNotIn("TypeError", output, output)
            self.assertNotIn("Failed to link shader program", output, output)
            self.assertNotIn("Failed to build graphics pipeline", output, output)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--exercise":
        sys.exit(mpris_runtime.exercise(Path(sys.argv[2]), player_name="cider", success_marker="CIDER_LYRICS_RUNTIME_PASSED"))
    unittest.main()
