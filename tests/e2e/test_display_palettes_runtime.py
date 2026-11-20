"""Verify the per-output palette and app exports on two private Wayland outputs."""

import json
from hashlib import md5
from io import BytesIO
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest

from PIL import Image

from tests.runtime.run_compositor import Session, private_environment


ROOT = Path(__file__).resolve().parents[2]
QML = r'''
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.modules.components
import qs.modules.theme
import qs.modules.widgets.dashboard.wallpapers

ShellRoot {
    WallpaperManager { id: manager }
    Variants {
        id: displays
        model: Quickshell.screens

        Item {
            id: output
            required property ShellScreen modelData
            property string name: modelData?.name ?? ""
            property color source: card.shellPalette.sourceColor
            property color foreground: label.color
            property color background: card.singleGradientColor
            property color paneBackground: pane.singleGradientColor
            property color popupSource: popup.shellPalette.sourceColor
            property color popupForeground: popupLabel.color
            property bool popupVisible: popup.visible
            property alias displayedWallpaper: wallpaper.effectiveWallpaper
            property alias videoPlaying: wallpaper.videoPlaying
            function openPopup(): void { popup.open(); }
            function selectScheme(name: string): string {
                const index = picker.combinedModel.findIndex(scheme => scheme.id === name);
                picker.applySchemeAt(index);
                return picker.getCurrentDisplayName();
            }

            Wallpaper { id: wallpaper; screen: output.modelData }

            PanelWindow {
                screen: output.modelData
                anchors.top: true
                anchors.left: true
                implicitWidth: 240
                implicitHeight: 40
                color: "transparent"

                SchemeSelector { id: picker; visible: false }

                StyledRect {
                    id: card
                    width: 120
                    height: parent.height
                    variant: "primary"
                    StyledText { id: label; text: output.name }
                }

                StyledRect {
                    id: pane
                    anchors.left: card.right
                    width: 120
                    height: parent.height
                    variant: "pane"
                }

                BarPopup {
                    id: popup
                    closeOnFocusLost: false
                    anchorItem: card
                    contentWidth: 110
                    contentHeight: 40
                    StyledText { id: popupLabel; text: "Popup" }
                }
            }
        }
    }

    IpcHandler {
        target: "display-palettes-test"
        function state(): string {
            return JSON.stringify({
                globalSource: Colors.sourceColor.toString(),
                displays: displays.instances.filter(output => output.name).map(output => ({
                    name: output.name,
                    displayedWallpaper: output.displayedWallpaper,
                    videoPlaying: output.videoPlaying,
                    source: output.source.toString(),
                    background: output.background.toString(),
                    paneBackground: output.paneBackground.toString(),
                    foreground: output.foreground.toString(),
                    popupSource: output.popupSource.toString(),
                    popupForeground: output.popupForeground.toString(),
                    popupVisible: output.popupVisible
                }))
            });
        }
        function outputs(): string {
            return JSON.stringify(manager.wallpaperOutputs.map(output => output.currentScreenName).sort());
        }
        function set(path: string, output: string): void { manager.setWallpaper(path, output); }
        function openPopup(name: string): void { displays.instances.find(output => output.name === name)?.openPopup(); }
        function clear(output: string): void { manager.clearPerScreenWallpaper(output); }
        function preset(name: string): void { manager.setColorPreset(name); }
        function scheme(name: string): void { manager.setMatugenScheme(name); }
        function selectScheme(name: string): string { return displays.instances[0].selectScheme(name); }
        function light(on: bool): void { Config.theme.lightMode = on; }
    }
}
'''


def exercise(fixture):
    session = Session(fixture, shutil.which("qs"))
    runtime = Path(session.env["XDG_RUNTIME_DIR"])
    try:
        commands = fixture / "bin"
        commands.mkdir()
        # Keep app exports, but keep their reload commands inside the fixture.
        for name in ("pkill", "gsettings"):
            stub = commands / name
            stub.write_text("#!/bin/sh\nexit 0\n")
            stub.chmod(0o700)
        session.env["PATH"] = str(commands) + os.pathsep + session.env["PATH"]
        (fixture / "source").mkdir()
        shutil.copytree(ROOT / "modules", fixture / "source/modules")
        # Force the image to finish after extraction on both Apply paths.
        renderer = fixture / "source/modules/widgets/dashboard/wallpapers/Wallpaper.qml"
        renderer.write_text(renderer.read_text().replace(
            "onPathChanged: useFrame = false", """onPathChanged: {
            useFrame = false;
            if (path.endsWith("/last.png"))
                holdImage.restart();
            else
                holdImage.stop();
        }
        Timer { id: holdImage; interval: 450 }""").replace(
            'source: slot.isFrame ?', 'source: holdImage.running ? "" : slot.isFrame ?'))
        test_video = session.env.get("NONCHALANT_TEST_MPV") == "1"
        if not test_video:
            (fixture / "source/modules/widgets/dashboard/wallpapers/mpvpaper.sh").write_text("exit 0\n")
        shutil.copytree(ROOT / "scripts", fixture / "source/scripts")
        generator = fixture / "source/scripts/generate_wallpaper_colors.sh"
        hold_extraction = fixture / "hold-extraction"
        session.env["NONCHALANT_TEST_HOLD_EXTRACTION"] = str(hold_extraction)
        generator.write_text(generator.read_text().replace("set -euo pipefail", """set -euo pipefail
gate=$NONCHALANT_TEST_HOLD_EXTRACTION
if [[ -f $gate && ${1##*/} == "$(cat "$gate")" ]]; then
    while [[ -f $gate ]]; do sleep 0.025; done
fi""", 1))
        for name in ("config", "assets", "version"):
            (fixture / "source" / name).symlink_to(ROOT / name, target_is_directory=(ROOT / name).is_dir())
        shell = fixture / "source/shell.qml"
        shell.write_text(QML)

        wallpapers = fixture / "wallpapers"
        wallpapers.mkdir()
        colors = {"global": "#42a04c", "left": "#d43c3a", "right": "#407ed0",
                  "next": "#a743be", "last": "#b47f38"}
        for name, color in colors.items():
            Image.new("RGB", (64, 64), color).save(wallpapers / f"{name}.png")
        (wallpapers / "bad.png").write_text("invalid image")
        frames = [Image.new("RGB", (64, 64), color) for color in ("#dd2288", "#22cc88")]
        animated = wallpapers / "animated.webp"
        frames[0].save(animated, save_all=True, append_images=frames[1:], duration=600, loop=0, lossless=True)
        gif = wallpapers / "animated.gif"
        frames[0].save(gif, save_all=True, append_images=frames[1:], duration=600, loop=0)
        avif = wallpapers / "avif-with-webp-name.webp"
        Image.init()
        if "AVIF" in Image.SAVE:
            Image.new("RGB", (64, 64), "#2299dd").save(avif, "AVIF")
        if test_video:
            video = wallpapers / "animated.mp4"
            session.run(["ffmpeg", "-v", "error",
                         "-f", "lavfi", "-i", "color=c=0xdd2288:s=256x144:r=20:d=0.75",
                         "-f", "lavfi", "-i", "color=c=0x22cc88:s=256x144:r=20:d=0.75",
                         "-filter_complex", "[0:v][1:v]concat=n=2:v=1:a=0",
                         "-threads", "1", str(video)])

        cache = Path(session.env["HOME"]) / ".cache/nonchalant"
        cache.mkdir(parents=True)
        config = fixture / "sway.conf"
        config.write_text("output HEADLESS-1 pos 0 0\noutput HEADLESS-2 pos 1280 0\n")
        session.env.pop("SWAYSOCK", None)
        sway_env = dict(session.env, WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS="2",
                        WLR_LIBINPUT_NO_DEVICES="1", WLR_RENDERER="pixman")
        session.start("sway", ["sway", "--config", str(config)], sway_env)
        session.env["SWAYSOCK"] = str(session.wait("private Sway IPC", lambda: next(runtime.glob("sway-ipc.*.sock"), None)))
        session.env["WAYLAND_DISPLAY"] = session.wait("private Wayland display", lambda: next(
            (path.name for path in runtime.glob("wayland-*") if path.is_socket()), None))
        session.env["QT_QPA_PLATFORM"] = "wayland"

        outputs = sorted(output["name"] for output in json.loads(session.run(["swaymsg", "-t", "get_outputs"])))
        assert len(outputs) == 2, outputs
        left, right = outputs
        paths = {name: str(wallpapers / f"{name}.png") for name in (*colors, "bad")}
        theme_dir = Path(session.env["XDG_CONFIG_HOME"]) / "nonchalant/config"
        theme_dir.mkdir(parents=True)
        (theme_dir / "theme.json").write_text(json.dumps({"srPrimary": {"gradient": [["primary", 0]]}}))
        (cache / "wallpapers.json").write_text(json.dumps({
            "wallPath": str(wallpapers),
            "currentWall": paths["global"],
            "perScreenWallpapers": {left: paths["left"], right: paths["right"]},
        }))

        process = session.start("quickshell", ["qs", "-p", str(shell), "--no-color"])

        def ipc(method, *args):
            return session.ipc(process, "display-palettes-test", method, *args)

        def state():
            data = json.loads(ipc("state"))
            return data["globalSource"], {display["name"]: display for display in data["displays"]}

        def expect(expected, global_source=colors["global"]):
            def matches():
                source, displays = state()
                seen = {name: display["source"] for name, display in displays.items()}
                if source == global_source and seen == expected:
                    return displays
                return None

            try:
                return session.wait(f"global {global_source} and display colors {expected}", matches, timeout=10)
            except RuntimeError as error:
                raise AssertionError(f"{error}. Last state: {state()}") from error

        def check_pixels(displays):
            if not shutil.which("grim"):
                return

            def colors_match(name):
                screenshot = subprocess.run(["grim", "-o", name, "-"], env=session.env,
                                            capture_output=True, timeout=10, check=True).stdout
                with Image.open(BytesIO(screenshot)) as image:
                    rgb = image.convert("RGB")
                    pixels = {role: "#" + bytes(rgb.getpixel(position)).hex() for role, position in (
                        ("background", (104, 22)), ("paneBackground", (224, 22)))}
                return all(color == displays[name][role] for role, color in pixels.items())

            for name in displays:
                session.wait("rendered accent and pane colors on " + name, lambda: colors_match(name))

        def capture(name):
            shot = subprocess.run(["grim", "-o", name, "-"], env=session.env,
                                  capture_output=True, timeout=10, check=True).stdout
            with Image.open(BytesIO(shot)) as image:
                rgb = image.convert("RGB")
                return tuple("#" + bytes(rgb.getpixel(point)).hex() for point in ((400, 240), (104, 22)))

        def trace_apply(name, action):
            frames = [(time.monotonic(), capture(name))]
            action()
            deadline = time.monotonic() + 1.15
            while time.monotonic() < deadline:
                frame = capture(name)
                if frame != frames[-1][1]:
                    frames.append((time.monotonic(), frame))
                time.sleep(0.025)
            return frames

        def check_apply_trace(frames, before, after):
            assert frames[0][1] == before and frames[-1][1] == after, frames
            # Wallpaper and bar are independent Wayland surfaces. They can
            # present one refresh apart, even after one QML state update.
            for _, (image, accent) in frames:
                assert image in (before[0], after[0]) and accent in (before[1], after[1]), frames
            for index in (0, 1):
                changes = [frame[index] for _, frame in frames]
                assert changes == sorted(changes, key=[before[index], after[index]].index), frames
            assert frames[-1][0] - frames[1][0] < 0.10, frames

        def cached_frame(path):
            return cache / "lockscreen" / (md5(os.fsencode(path), usedforsecurity=False).hexdigest() + ".jpg")

        session.wait("wallpaper windows registered", lambda: json.loads(ipc("outputs")) == outputs)
        initial = expect({left: colors["left"], right: colors["right"]})
        check_pixels(initial)
        for name in (left, right):
            ipc("openPopup", name)
            session.wait("anchored popup on " + name, lambda: state()[1][name]["popupVisible"])
            popup = state()[1][name]
            assert popup["popupSource"] == initial[name]["source"], popup
            assert popup["popupForeground"] == initial[name]["foreground"], popup
        for role in ("foreground", "background", "paneBackground"):
            assert initial[left][role] != initial[right][role], initial

        global_file = cache / "colors.json"
        niri_file = cache / "niri-colors.kdl"
        primary = json.loads(global_file.read_text())["primary"]
        home = Path(session.env["HOME"])
        exports = {
            niri_file: f'active-color "{primary}ff"',
            cache / "kitty.conf": f"color4 {primary}",
            home / ".config/gtk-4.0/colors.css": f"accent_color {primary}",
            home / ".config/qt6ct/colors/nonchalant.colors": f"DecorationFocus={primary}",
        }
        session.wait("global application palettes", lambda: all(
            path.exists() and marker in path.read_text() for path, marker in exports.items()))
        initial_exports = {path: path.stat().st_mtime_ns for path in (*exports, global_file)}
        initial_right = (cache / f"colors-{right}.json").stat().st_mtime_ns

        hold_extraction.write_text("last.png")
        ipc("set", paths["next"], left)
        ipc("set", paths["last"], left)
        pending = state()[1][left]
        assert pending["source"] == initial[left]["source"], pending
        assert pending["displayedWallpaper"] == paths["left"], pending
        check_pixels({left: pending})
        if shutil.which("grim"):
            frames = trace_apply(left, hold_extraction.unlink)
        else:
            hold_extraction.unlink()
        changed = expect({left: colors["last"], right: colors["right"]})
        assert changed[left]["displayedWallpaper"] == paths["last"], changed
        if shutil.which("grim"):
            check_apply_trace(frames, (colors["left"], initial[left]["background"]),
                              (colors["last"], changed[left]["background"]))
        for role in ("source", "background", "paneBackground", "foreground", "popupSource"):
            assert changed[right][role] == initial[right][role], changed
        assert changed[left]["popupSource"] == colors["last"], changed
        assert {path: path.stat().st_mtime_ns for path in initial_exports} == initial_exports
        assert (cache / f"colors-{right}.json").stat().st_mtime_ns == initial_right

        if shutil.which("grim"):
            frames = trace_apply(left, lambda: ipc("clear", left))
        else:
            ipc("clear", left)
        inherited = expect({left: colors["global"], right: colors["right"]})
        if shutil.which("grim"):
            check_apply_trace(frames, (colors["last"], changed[left]["background"]),
                              (colors["global"], inherited[left]["background"]))
        hold_extraction.write_text("last.png")
        ipc("set", paths["last"], "")
        pending = state()[1][left]
        assert pending["source"] == colors["global"], pending
        assert pending["displayedWallpaper"] == paths["global"], pending
        if shutil.which("grim"):
            frames = trace_apply(left, hold_extraction.unlink)
        else:
            hold_extraction.unlink()
        changed = expect({left: colors["last"], right: colors["right"]}, colors["last"])
        assert changed[left]["displayedWallpaper"] == paths["last"], changed
        if shutil.which("grim"):
            check_apply_trace(frames, (colors["global"], inherited[left]["background"]),
                              (colors["last"], changed[left]["background"]))
        ipc("set", paths["global"], "")
        inherited = expect({left: colors["global"], right: colors["right"]})
        if shutil.which("grim"):
            frames = trace_apply(right, lambda: ipc("set", paths["bad"], right))
            assert [frame for _, frame in frames] == [(colors["right"], inherited[right]["background"])], frames
        else:
            ipc("set", paths["bad"], right)
        session.wait("Qt rejected the broken file", lambda: "Error decoding" in (fixture / "quickshell.log").read_text())
        saved = json.loads((cache / "wallpapers.json").read_text())
        assert saved["perScreenWallpapers"][right] == paths["right"], saved
        assert state()[1][right]["displayedWallpaper"] == paths["right"]
        repaired = "#b359c0"
        Image.new("RGB", (64, 64), repaired).save(paths["bad"])
        ipc("set", paths["bad"], right)
        expect({left: colors["global"], right: repaired})
        ipc("set", paths["right"], right)
        expect({left: colors["global"], right: colors["right"]})

        preset_source = json.loads((ROOT / "assets/colors/Catppuccin/dark.json").read_text())["sourceColor"].lower()
        ipc("preset", "Catppuccin")
        expect({left: preset_source, right: preset_source}, preset_source)
        ipc("clear", left)
        hold_extraction.write_text("right.png")
        ipc("scheme", "scheme-noctalia-vibrant")
        session.wait("global palette is ready while the override is pending", lambda: state()[0] == colors["global"])
        pending = state()[1][right]
        assert pending["source"] == preset_source, pending
        hold_extraction.unlink()
        vibrant = expect({left: colors["global"], right: colors["right"]})
        check_pixels(vibrant)

        previous_right = json.loads((cache / f"colors-{right}.json").read_text())["primary"]
        ipc("light", "true")
        session.wait("light mode regenerates the override", lambda:
            json.loads((cache / f"colors-{right}.json").read_text())["primary"] != previous_right)

        session.run(["swaymsg", "output", left, "disable"])
        expect({right: colors["right"]})
        ipc("set", paths["next"], right)
        expect({right: colors["next"]})
        session.run(["swaymsg", "output", left, "enable"])
        expect({left: colors["global"], right: colors["next"]})

        if shutil.which("grim"):
            def wallpaper_shows(color):
                return all(abs(a - b) <= 4 for a, b in zip(bytes.fromhex(capture(right)[0][1:]), bytes.fromhex(color)))

            for path in (gif, animated):
                ipc("set", path, right)
                for color in ("dd2288", "22cc88"):
                    session.wait(f"{path.suffix} frame #{color}", lambda: wallpaper_shows(color))
                session.wait(f"{path.suffix} lockscreen frame", cached_frame(path).exists)
            if avif.exists():
                frames = trace_apply(right, lambda: ipc("set", avif, right))
                session.wait("AVIF with a WebP filename", lambda: wallpaper_shows("2299dd"))
                session.wait("AVIF lockscreen frame", cached_frame(avif).exists)
                assert all(pixel in ("#dd2288", "#22cc88") or
                           all(abs(a - b) <= 4 for a, b in zip(bytes.fromhex(pixel[1:]), bytes.fromhex("2299dd")))
                           for _, (pixel, _) in frames), frames
            if test_video:
                ipc("set", video, right)
                session.wait("mpvpaper is playing", lambda: state()[1][right]["videoPlaying"])
                for color in ("dd2288", "22cc88"):
                    session.wait(f"video playback frame #{color}", lambda: wallpaper_shows(color))
                ipc("set", paths["next"], right)
                session.wait("still image after mpvpaper", lambda: wallpaper_shows(colors["next"][1:]))
                def player_stopped():
                    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
                        return connection.connect_ex(str(runtime / f"nonchalant_mpv_socket_{right}")) != 0

                session.wait("owned video process stopped", player_stopped)
        if shutil.which("matugen"):
            previous = json.loads(global_file.read_text())["primary"]
            assert ipc("selectScheme", "scheme-content-dominant") == "Content"
            session.wait("picker saves its scheme", lambda:
                json.loads((cache / "wallpapers.json").read_text())["matugenScheme"] == "scheme-content-dominant")
            session.wait("picker regenerates the global palette", lambda:
                json.loads(global_file.read_text())["primary"] != previous)
        log = (fixture / "quickshell.log").read_text()
        assert not any(error in log for error in ("TypeError:", "ReferenceError:", "Binding loop")), log
    except Exception:
        if (fixture / "quickshell.log").exists():
            print((fixture / "quickshell.log").read_text()[-10000:])
        if (fixture / "sway.log").exists():
            print((fixture / "sway.log").read_text()[-2000:])
        raise
    finally:
        session.stop()


@unittest.skipUnless(all(shutil.which(tool) for tool in ("sway", "swaymsg", "qs", "dbus-run-session")),
                     "Quickshell and headless Sway are required")
class DisplayPalettesRuntimeTests(unittest.TestCase):
    def test_two_outputs_keep_independent_palettes(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-display-colors-") as fixture:
            env = private_environment(Path(fixture))
            try:
                result = subprocess.run(
                    ["dbus-run-session", "--", sys.executable, "-m", "tests.e2e.test_display_palettes_runtime", "--exercise", fixture],
                    env=env, capture_output=True, text=True, timeout=65)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            finally:
                shutil.rmtree(env["XDG_RUNTIME_DIR"])


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--exercise":
        exercise(Path(sys.argv[2]))
    else:
        unittest.main()
