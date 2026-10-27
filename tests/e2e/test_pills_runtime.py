"""Exercise pills transitions and feedback in an isolated Quickshell process."""

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
import qs.modules.bar.layouts
import qs.modules.services
import qs.modules.services.compositor
import qs.modules.theme

ShellRoot {
    CompositorState { id: compositorState }
    FloatingWindow {
        visible: true
        implicitWidth: 1200
        implicitHeight: 900
        PillsBar { id: bar; screen: Quickshell.screens[0] }
        TestCase {
            name: "PillsRuntime"
            when: Config.initialLoadComplete

            function childOfType(item, type) {
                if (String(item).startsWith(type)) return item
                for (const child of item.children ?? []) {
                    const found = childOfType(child, type)
                    if (found) return found
                }
                return null
            }

            function assertLevel(actual, expected, message) {
                verify(Math.abs(actual - expected) < 0.001, message + ": expected " + expected + ", got " + actual)
            }

            function initTestCase() {
                tryVerify(() => CompositorService.backend !== null)
                CompositorService.backend.state = compositorState
            }

            function init() {
                Notifications.popupList = []
                Config.bar.pinned = true
                compositorState.overviewOpen = false
                bar.collapse()
                tryCompare(bar, "currentMode", "collapsed")
                tryCompare(bar, "isMorphing", false)
                tryCompare(bar, "containerY", 0)
            }

            function test_late_geometry_during_open() {
                const panel = childOfType(bar, "IslandMediaCenterPanel")
                verify(panel !== null)
                bar.expand("media")
                tryCompare(bar, "isMorphing", true)
                const original = panel.implicitHeight
                panel.implicitHeight = original + 90
                compare(bar.targetHeight, original + 90)
                tryCompare(bar, "isMorphing", false)
                tryCompare(bar, "targetCardHeight", bar.targetHeight)
                panel.implicitHeight = original
                tryCompare(bar, "targetCardHeight", original)
                console.log("PILLS_LATE_GEOMETRY_PASSED")
            }

            function test_interrupted_retraction() {
                Config.bar.pinned = false
                compositorState.overviewOpen = true
                tryCompare(bar, "shouldBeRevealed", false)
                bar.expand("media")
                tryCompare(bar, "containerY", 0)
                verify(bar.openedFromHidden)
                bar.collapse()
                tryVerify(() => bar.retractingToHidden && bar.containerY < -1)
                bar.expand("media")
                tryCompare(bar, "containerY", 0)
                compare(bar.currentMode, "media")
                verify(!bar.retractingToHidden)
                console.log("PILLS_INTERRUPTED_RETRACTION_PASSED")
            }

            function test_hidden_inline_osd() {
                Config.bar.pinned = false
                compositorState.overviewOpen = true
                tryCompare(bar, "shouldBeRevealed", false)
                for (const indicator of ["volume", "mic", "brightness"]) {
                    bar.triggerOsd(indicator, 0.5, false)
                    compare(bar.inlineOsdActive, true)
                    compare(bar.shouldBeRevealed, true)
                    tryCompare(bar, "containerY", 0)
                    tryCompare(bar, "inlineOsdActive", false, 2500)
                    compare(bar.shouldBeRevealed, false)
                    tryVerify(() => bar.containerY < -bar.pillHeight)
                }
                console.log("PILLS_HIDDEN_OSD_PASSED")
            }

            function test_inline_osd_keeps_scrolling() {
                function wheelHandlers(item, out) {
                    for (const d of item.data ?? [])
                        if (String(d).startsWith("QQuickWheelHandler")) out.push(d)
                    for (const child of item.children ?? []) wheelHandlers(child, out)
                    return out
                }
                const icons = childOfType(bar, "IslandStatusIcons")
                verify(icons !== null)
                tryCompare(bar, "containerY", 0)
                Audio.sink.audio.volume = 0.5
                const handlers = wheelHandlers(icons.parent, [])
                let hits = 0
                for (const handler of handlers) handler.wheel.connect(() => hits++)
                const volume = icons.children[1]
                const point = volume.mapToItem(bar, volume.width / 2, volume.height / 2)
                bar.triggerOsd("volume", 0.5, false)
                verify(bar.inlineOsdActive)
                wait(Motion.hoverDuration + 50)
                for (let i = 1; i <= 3; i++) {
                    mouseWheel(bar, point.x, point.y, 0, -120)
                    assertLevel(Audio.sink.audio.volume, 0.5 - 0.05 * i, "each notch lowers the level by one step")
                }
                compare(hits, 3, "every notch reaches a handler while the inline OSD covers the icons")
                // The first timeout would lapse about 1.8 s after triggerOsd, so
                // a notch sent later must restart it for the OSD to still be up.
                wait(1200)
                mouseWheel(bar, point.x, point.y, 0, -120)
                assertLevel(Audio.sink.audio.volume, 0.3, "a notch after the first timeout still adjusts the level")
                wait(1200)
                verify(bar.inlineOsdActive, "the OSD stays up past its original timeout while scrolling")
                tryCompare(bar, "inlineOsdActive", false, 2500)
                console.log("PILLS_INLINE_OSD_SCROLL_PASSED")
            }

            function test_inline_osd_keeps_boosted_levels() {
                const icons = childOfType(bar, "IslandStatusIcons")
                verify(icons !== null)
                tryCompare(bar, "containerY", 0)
                Audio.sink.audio.volume = 1.5
                Audio.source.audio.volume = 1.5
                bar.triggerOsd("volume", 1.5, false)
                verify(bar.inlineOsdActive)
                wait(Motion.hoverDuration + 50)
                const point = icons.mapToItem(bar, icons.width / 2, icons.height / 2)
                mouseWheel(bar, point.x, point.y, 0, -120)
                assertLevel(Audio.sink.audio.volume, 1.45, "a notch steps a boosted output down from where it is")
                mouseWheel(bar, point.x, point.y, 0, 120)
                assertLevel(Audio.sink.audio.volume, 1.45, "scrolling up never snaps a boosted output down to 100%")
                bar.triggerOsd("mic", 1.5, false)
                mouseWheel(bar, point.x, point.y, 0, -120)
                assertLevel(Audio.source.audio.volume, 1.45, "a notch steps a boosted mic down from where it is")
                console.log("PILLS_INLINE_OSD_BOOSTED_PASSED")
            }

            function test_background_notification_dismissal() {
                for (const mode of ["dashboard", "media", "apps", "projects"]) {
                    bar.expand(mode)
                    tryCompare(bar, "isMorphing", false)
                    Notifications.popupList = [{id: 999, appName: "Review test", summary: "Background"}]
                    compare(bar.currentMode, mode)
                    Notifications.popupList = []
                    compare(bar.currentMode, mode)
                }
                bar.collapse()
                tryCompare(bar, "isMorphing", false)
                Notifications.popupList = [{id: 1000, appName: "Review test", summary: "Foreground"}]
                tryCompare(bar, "currentMode", "notification")
                Notifications.popupList = []
                tryCompare(bar, "currentMode", "collapsed")
                console.log("PILLS_BACKGROUND_NOTIFICATION_PASSED")
            }

            function test_stats_badges_share_configured_accent() {
                const panel = childOfType(bar, "IslandStatsPanel")
                verify(panel !== null)
                SystemResources.monitorProcess.running = false
                SystemResources.gpuNames = ["Test NVIDIA", "Test AMD"]
                SystemResources.gpuUsages = [0, 2]
                SystemResources.gpuTemps = [47, 45]
                SystemResources.gpuVramUsed = [0, 0]
                SystemResources.gpuVramTotal = [0, 0]
                SystemResources.gpuCount = 2
                SystemResources.gpuDetected = true
                SystemResources.validDisks = ["/"]
                SystemResources.diskUsage = {"/": 59}

                function descendants(item, predicate) {
                    let result = predicate(item) ? [item] : []
                    for (const child of item.children ?? [])
                        result = result.concat(descendants(child, predicate))
                    return result
                }

                function styledParent(item) {
                    let parent = item.parent
                    while (parent && parent.variant === undefined)
                        parent = parent.parent
                    return parent
                }

                const originalGradient = Config.theme.srPrimary.gradient
                const originalForeground = Config.theme.srPrimary.itemColor
                try {
                    for (const role of ["primary", "magenta"]) {
                        Config.theme.srPrimary.gradient = [[role, 0]]
                        Config.theme.srPrimary.itemColor = role === "primary" ? "overPrimary" : "overMagenta"
                        for (const usage of [4, 70, 95, 4]) {
                            SystemResources.cpuUsage = usage
                            SystemResources.ramUsage = usage
                            SystemResources.diskUsage = {"/": usage}
                            SystemResources.gpuUsages = [usage, 2]
                            const glyphs = [Icons.cpu, Icons.ram, Icons.gpu, Icons.disk,
                                Icons.vpnKey, Icons.wifiHigh, Icons.ethernet]
                            const badges = descendants(panel, item => glyphs.includes(item.text))
                            compare(badges.length, 6, "CPU, RAM, both GPUs, disk and network")
                            for (const icon of badges) {
                                const badge = styledParent(icon)
                                verify(badge !== null)
                                compare(badge.variant, "primary")
                                tryCompare(badge, "singleGradientColor", Colors[role])
                                tryCompare(icon, "color", Styling.srItem("primary"))
                            }
                            const fills = descendants(panel, item =>
                                item.variant !== undefined && styledParent(item)?.height === 4)
                            compare(fills.length, 5, "CPU, RAM, both GPUs and disk progress fills")
                            for (const fill of fills) {
                                compare(fill.variant, "primary")
                                tryCompare(fill, "singleGradientColor", Colors[role])
                            }
                        }
                    }
                } finally {
                    Config.theme.srPrimary.gradient = originalGradient
                    Config.theme.srPrimary.itemColor = originalForeground
                }
                console.log("PILLS_STATS_ACCENT_PASSED")
            }

            function cleanupTestCase() {
                CompositorService.backend.state = null
                Qt.quit()
            }
        }
    }
    Timer {
        interval: 25000
        running: true
        onTriggered: { console.error("PILLS_RUNTIME_TIMEOUT"); Qt.quit() }
    }
}
'''


# Stands in for the PipeWire wrapper so the wheel handlers adjust a level the
# test can read back. The real service has no sink in this sandbox.
AUDIO_STUB = r'''
pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property real hardMaxValue: 2.0
    readonly property real value: sinkAudio.volume
    property bool protectionEnabled: false
    property bool protectionTriggered: false
    readonly property list<var> outputAppNodes: []
    readonly property list<var> inputAppNodes: []
    readonly property list<var> outputDevices: []
    readonly property list<var> inputDevices: []

    readonly property QtObject sink: QtObject {
        id: sinkNode
        readonly property bool ready: true
        readonly property string id: "test-sink"
        readonly property QtObject audio: QtObject {
            id: sinkAudio
            property real volume: 0.5
            property bool muted: false
            onVolumeChanged: root.volumeChanged(volume, muted, sinkNode)
            onMutedChanged: root.volumeChanged(volume, muted, sinkNode)
        }
    }

    readonly property QtObject source: QtObject {
        id: sourceNode
        readonly property bool ready: true
        readonly property string id: "test-source"
        readonly property QtObject audio: QtObject {
            id: sourceAudio
            property real volume: 0.5
            property bool muted: false
            onVolumeChanged: root.micVolumeChanged(volume, muted, sourceNode)
            onMutedChanged: root.micVolumeChanged(volume, muted, sourceNode)
        }
    }

    signal volumeChanged(real volume, bool muted, var node)
    signal micVolumeChanged(real volume, bool muted, var node)
    signal sinkProtectionTriggered(string reason)

    function setVolume(volume: real) {
        sinkAudio.volume = Math.max(0, Math.min(hardMaxValue, volume));
    }

    function setMicVolume(volume: real) {
        sourceAudio.volume = Math.max(0, Math.min(hardMaxValue, volume));
    }

    function setNodeVolume(node, volume: real) {}
    function setProtectionEnabled(enabled: bool) { protectionEnabled = enabled; }
    function toggleMute() { sinkAudio.muted = !sinkAudio.muted; }
    function toggleMicMute() { sourceAudio.muted = !sourceAudio.muted; }
    function incrementVolume() { setVolume(sinkAudio.volume + 0.02); }
    function decrementVolume() { setVolume(sinkAudio.volume - 0.02); }
    function setDefaultSink(node) {}
    function setDefaultSource(node) {}
    function friendlyDeviceName(node): string { return "Test device"; }
    function appNodeDisplayName(node): string { return "Test app"; }
    function volumeIcon(volume: real, muted: bool): string { return ""; }
}
'''


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for runtime checks")
class PillsRuntimeTests(unittest.TestCase):
    def test_transitions_and_feedback(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-pills-") as directory:
            fixture = Path(directory)
            for name in ("config", "assets", "scripts", "version"):
                (fixture / name).symlink_to(ROOT / name, target_is_directory=(ROOT / name).is_dir())
            modules = fixture / "modules"
            modules.mkdir()
            for source in (ROOT / "modules").iterdir():
                if source.name != "services":
                    (modules / source.name).symlink_to(source, target_is_directory=source.is_dir())
            shutil.copytree(ROOT / "modules/services", modules / "services")
            (modules / "services/compositor/NiriBackend.qml").write_text(
                "import QtQuick\nCompositorBackend {}\n")
            (modules / "services/Audio.qml").write_text(AUDIO_STUB)
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
                env=env, capture_output=True, text=True, timeout=30,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            for marker in ("LATE_GEOMETRY", "INLINE_OSD_SCROLL", "INLINE_OSD_BOOSTED", "INTERRUPTED_RETRACTION", "HIDDEN_OSD", "BACKGROUND_NOTIFICATION", "STATS_ACCENT"):
                self.assertIn("PILLS_" + marker + "_PASSED", output, output)
            self.assertNotIn("PILLS_RUNTIME_TIMEOUT", output, output)
            self.assertNotIn("Binding loop", output, output)
            self.assertNotIn("TypeError", output, output)
            self.assertNotIn("Unable to assign [undefined]", output, output)


if __name__ == "__main__":
    unittest.main()
