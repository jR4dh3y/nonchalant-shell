#!/usr/bin/env python3
"""Exercise a disposable compositor. Every child receives private session paths."""

import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--compositor", choices=("niri", "hyprland"), required=True)
    parser.add_argument("--artifacts", type=Path)
    parser.add_argument("--shell", action="store_true", help="also render the complete shell")
    parser.add_argument("--style", choices=("default", "island", "left"), default="default")
    parser.add_argument("--scale", type=float, default=1, help="scale of the disposable output")
    parser.add_argument("--text-rendering", action="store_true", help="compare nested container text with direct rasterization")
    parser.add_argument("--quickshell", default="qs", help="Quickshell binary, including an older baseline package")
    parser.add_argument("--power-cycle", action="store_true", help="exercise DPMS only on disposable test outputs")
    parser.add_argument("--baseline", action="store_true", help="capture a source without CompositorService")
    parser.add_argument("--inside-session", type=Path, help=argparse.SUPPRESS)
    return parser.parse_args()


def private_environment(root):
    env = dict(os.environ)
    for key in ("WAYLAND_DISPLAY", "WAYLAND_SOCKET", "DISPLAY", "NIRI_SOCKET",
                "HYPRLAND_INSTANCE_SIGNATURE", "DBUS_SESSION_BUS_ADDRESS",
                "DBUS_STARTER_ADDRESS", "DBUS_STARTER_BUS_TYPE", "XAUTHORITY",
                "XDG_ACTIVATION_TOKEN", "DESKTOP_STARTUP_ID", "QT_QPA_PLATFORM",
                "QT_QUICK_BACKEND"):
        env.pop(key, None)
    for key, directory in {
        "HOME": "home", "XDG_CONFIG_HOME": "config",
        "XDG_CACHE_HOME": "cache", "XDG_DATA_HOME": "data", "XDG_STATE_HOME": "state"
    }.items():
        path = root / directory
        path.mkdir(mode=0o700, parents=True, exist_ok=True)
        env[key] = str(path)
    runtime = Path(tempfile.mkdtemp(prefix="nc-", dir="/tmp"))
    runtime.chmod(0o700)
    (root / "runtime").symlink_to(runtime, target_is_directory=True)
    env["XDG_RUNTIME_DIR"] = str(runtime)
    env.update(LIBGL_ALWAYS_SOFTWARE="1", GALLIUM_DRIVER="llvmpipe",
               WLR_RENDERER="gles2", QSG_RHI_BACKEND="opengl",
               XDG_SESSION_TYPE="wayland", XDG_CURRENT_DESKTOP="nonchalant-test")
    env.pop("NONCHALANT_COMPOSITOR", None)
    return env


class Session:
    def __init__(self, root, quickshell):
        self.root = root
        self.env = dict(os.environ)
        self.processes = []
        self.logs = []
        self.quickshell = quickshell
        self.state = None

    def start(self, name, command, env=None):
        log = (self.root / f"{name}.log").open("w")
        self.logs.append(log)
        process = subprocess.Popen(command, env=env or self.env, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        self.processes.append(process)
        return process

    def run(self, command):
        result = subprocess.run(command, env=self.env, capture_output=True,
                                text=True, timeout=15)
        if result.returncode:
            raise RuntimeError(f"{command!r}: {result.stderr or result.stdout}")
        return result.stdout.strip()

    def wait(self, description, predicate, timeout=20):
        deadline = time.monotonic() + timeout
        last_error = None
        while time.monotonic() < deadline:
            try:
                value = predicate()
                if value:
                    return value
            except (RuntimeError, ValueError) as error:
                last_error = error
            time.sleep(0.1)
        raise RuntimeError(f"Timed out waiting for {description}: {last_error}")

    def ipc(self, process, target, method, *args):
        if process not in self.processes:
            raise RuntimeError("IPC target is not owned by this test session")
        return self.run([self.quickshell, "ipc", "--pid", str(process.pid), "call", target,
                         method, *(str(argument) for argument in args)])

    def stop(self):
        for process in reversed(self.processes):
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
        for log in self.logs:
            log.close()


def start_compositor(session, compositor):
    runtime = Path(session.env["XDG_RUNTIME_DIR"])
    weston_config = session.root / "weston.ini"
    weston_config.write_text("[core]\nidle-time=0\n[shell]\npanel-position=none\n")
    compositor_env = dict(session.env)
    if compositor == "hyprland":
        compositor_env.pop("LIBGL_ALWAYS_SOFTWARE", None)
        compositor_env.pop("GALLIUM_DRIVER", None)
    session.start("weston", ["weston", "--backend=headless", "--renderer=gl",
        "--width=1280", "--height=720", "--socket=test-parent",
        f"--config={weston_config}"], compositor_env)
    session.wait("private Weston socket", lambda: (runtime / "test-parent").exists())
    if compositor == "niri":
        config = session.root / "niri.kdl"
        config.write_text('output "winit" {\n mode "1280x720"\n}\n'
                          'workspace "test-one"\nworkspace "test-two"\n'
                          'prefer-no-csd\nscreenshot-path null\n'
                          'gestures {\n hot-corners {\n  off\n }\n}\n'
                          'hotkey-overlay {\n skip-at-startup\n}\n')
        session.run(["niri", "validate", "--config", str(config)])
        env = dict(session.env, WAYLAND_DISPLAY="test-parent", WINIT_UNIX_BACKEND="wayland")
        session.start("niri", ["niri", "--config", str(config)], env)
        socket = session.wait("private Niri IPC socket",
            lambda: next(iter(runtime.glob("niri.*.sock")), None))
        session.env["NIRI_SOCKET"] = str(socket)
    else:
        config = session.root / "hyprland.conf"
        config.write_text('monitor = ,1280x720@60,0x0,1\n'
            'workspace = 1, default:true\nworkspace = 2, persistent:true\n'
            'workspace = name:test-named, monitor:TEST-1, persistent:true\n'
            'misc {\n disable_hyprland_logo = true\n disable_splash_rendering = true\n'
            ' force_default_wallpaper = 0\n}\n'
            'animations {\n enabled = false\n}\n'
            'debug {\n disable_logs = false\n enable_stdout_logs = true\n}\n')
        env = dict(compositor_env, WAYLAND_DISPLAY="test-parent", HYPRLAND_NO_SD_VARS="1",
                   HYPRLAND_NO_SD_NOTIFY="1", XDG_CURRENT_DESKTOP="Hyprland")
        session.start("hyprland", ["Hyprland", "--config", str(config)], env)
        socket = session.wait("private Hyprland IPC socket",
            lambda: next(iter(runtime.glob("hypr/*/.socket.sock")), None))
        session.env["HYPRLAND_INSTANCE_SIGNATURE"] = socket.parent.name
        session.run(["hyprctl", "output", "create", "headless", "TEST-1"])
        session.wait("private Hyprland headless monitor",
            lambda: json.loads(session.run(["hyprctl", "-j", "monitors"])))
        session.run(["hyprctl", "dismissnotify", "-1"])
    display = session.wait("private compositor Wayland socket",
        lambda: next((path for path in runtime.glob("wayland-*")
                      if path.is_socket()), None))
    session.env["WAYLAND_DISPLAY"] = display.name
    session.env["QT_QPA_PLATFORM"] = "wayland"


def check_text_rendering(session, source, scale, passed):
    from PIL import Image, ImageChops

    private_source = session.root / "text-source"
    shutil.copytree(source, private_source, ignore=shutil.ignore_patterns(".git", "__pycache__"))
    shutil.copy2(source / "tests/runtime/text-rendering.qml", private_source / "text-rendering.qml")
    config = Path(session.env["XDG_CONFIG_HOME"]) / "nonchalant/config"
    config.mkdir(parents=True, exist_ok=True)
    theme_file = config / "theme.json"
    theme_file.write_text(json.dumps({
        "srCommon": {"gradientType": "linear", "gradient": [["#a03060", 0], ["#3060a0", 1]]},
        "srFocus": {"gradientType": "radial", "gradient": [["#a03060", 0], ["#3060a0", 1]]},
        "srInternalBg": {"gradientType": "halftone", "halftoneDotColor": "#a03060", "halftoneBackgroundColor": "#3060a0"}
    }))
    probe = session.start("text-rendering", [session.quickshell, "-p", str(private_source / "text-rendering.qml")])
    expected_width = 1920 / scale
    session.wait("fractional surface geometry", lambda:
        abs(float(session.ipc(probe, "text-rendering-test", "width")) - expected_width) < 1)
    time.sleep(0.5)
    screenshot = session.root / "text-rendering.png"
    session.run(["grim", "-o", "TEST-1", str(screenshot)])
    image = Image.open(screenshot).convert("RGB")
    assert image.size == (1920, 1200), image.size
    differences = []
    for row in range(4):
        # Each column is separated by an integer number of physical pixels.
        # Include only the glyphs, excluding the rounded background corners.
        left = round((20 + (row % 2) * 10 + 10) * scale)
        top = round((30 + 50 + row * 70 + 10) * scale)
        width, height = round(250 * scale), round(28 * scale)
        direct = image.crop((left, top, left + width, top + height))
        assert direct.getextrema()[0][1] > 200, "Direct text did not render"
        for column in (1, 2):
            offset = round(column * 300 * scale)
            nested = image.crop((left + offset, top, left + offset + width, top + height))
            delta = ImageChops.difference(direct, nested)
            if column == 1:
                assert delta.getbbox() is None, f"Nested StyledRect text differs from direct text at {scale}x, row {row}"
            else:
                differences.append(delta.getbbox() is not None)
    if scale == 1.2:
        assert any(differences), "Reference texture masks did not reproduce the fractional blur"
    background = image.getpixel((0, 0))
    for column in range(3):
        x = 20 + column * 300
        assert image.getpixel((round((x + 1) * scale), round(381 * scale))) == background, "Gradient escaped rounded corner"
        assert image.getpixel((round((x + 130) * scale), round(435 * scale))) != background, "Gradient did not render"
    assert image.getpixel((round(21 * scale), round(481 * scale))) != background, "Square hover corner is missing"
    assert image.getpixel((round(279 * scale), round(481 * scale))) == background, "Hover escaped rounded corner"
    reference_border = image.getpixel((round(450 * scale), round(481 * scale)))
    for column in range(3):
        border = image.getpixel((round((150 + column * 300) * scale), round(381 * scale)))
        assert max(abs(a - b) for a, b in zip(border, reference_border)) <= 1, f"Procedural border alpha differs from the single solid border: {border} vs {reference_border}"
    passed.append("translucent procedural borders match a single-painted solid border")
    passed.append("linear, radial, halftone backgrounds and asymmetric hover corners render with preserved rounding")
    probe.terminate()
    probe.wait(timeout=5)
    theme_file.unlink()
    passed.append(f"nested StyledRect glyph pixels match direct text at {scale}x; texture-mask reference differences: {sum(differences)}/4")


def tray_icon_pixels(path, geometry, scale):
    from PIL import Image

    x, y, width, height = geometry
    with Image.open(path) as image:
        pixels = image.convert("RGB").crop((round(x * scale), round(y * scale),
                                            round((x + width) * scale), round((y + height) * scale)))
        return sum(1 for red, green, blue in pixels.get_flattened_data()
                   if blue > green > red and blue - red > 80)


def check_tray(session, shell, passed, scale):
    fixture = Path(__file__).with_name("tray_fixture.py")
    session.start("tray-fixture", [sys.executable, str(fixture)])
    state = session.shell_state

    def fixture_call(method, *args):
        output = session.run([sys.executable, str(fixture), method, *(str(arg) for arg in args)])
        return json.loads(output) if output else None

    def item(name):
        return next((item for item in state()["trayItems"]
                     if item["name"] == name and item["visible"]), None)

    def click(target, button="left"):
        assert target and target["visible"], target
        x, y, width, height = target["geometry"]
        assert width > 0 and height > 0, target
        session.run(["wlrctl", "pointer", "move", "-10000", "-10000"])
        session.run(["wlrctl", "pointer", "move", str(round(x + width / 2)), str(round(y + height / 2))])
        session.run(["wlrctl", "pointer", "click", button])
        time.sleep(0.25)

    def open_tray():
        click(state()["trayButton"])
        session.wait("tray flyout opens", lambda: state()["trayOpen"])
        time.sleep(0.7)
        session.wait("tray icons render", lambda: item("trayFlyoutItem_test-0"))

    session.wait("real tray registration", lambda: state()["trayCount"] == 2)
    session.wait("tray trigger appears", lambda: state()["trayButton"] and state()["trayButton"]["visible"])
    button_geometry = state()["trayButton"]["geometry"]
    open_tray()
    icon = item("trayFlyoutItem_test-0")
    assert icon["geometry"][0] > button_geometry[0] + button_geometry[2], icon
    assert state()["trayButton"]["geometry"] == button_geometry, "tray opening moved bar controls"

    for cycle in range(3):
        for index in range(2):
            target = item(f"trayFlyoutItem_test-{index}")
            session.run(["wlrctl", "pointer", "move", "10000", "10000"])
            time.sleep(0.15)
            before = session.root / f"tray-icon-{cycle}-{index}-before.png"
            session.run(["grim", str(before)])
            expected = tray_icon_pixels(before, target["geometry"], scale)
            assert expected > 0, "Transparent tray fixture did not render"
            x, y, width, height = target["geometry"]
            session.run(["wlrctl", "pointer", "move", "-10000", "-10000"])
            session.run(["wlrctl", "pointer", "move", str(round(x + width / 2)), str(round(y + height / 2))])
            for frame, delay in enumerate((0, 0.02, 0.1)):
                time.sleep(delay)
                screenshot = session.root / f"tray-icon-{cycle}-{index}-hover-{frame}.png"
                session.run(["grim", str(screenshot)])
                assert tray_icon_pixels(screenshot, target["geometry"], scale) == expected, (
                    f"Hover chrome obscured tray icon {index} in cycle {cycle}, frame {frame}")
    passed.append("transparent tray icons remain visible in first hover frames and repeated pointer transitions")
    session.run(["grim", str(session.root / "tray-grid.png")])
    click(state()["trayButton"])
    session.wait("tray reverse toggle", lambda: not state()["trayOpen"])
    time.sleep(0.6)
    open_tray()
    session.run(["wtype", "-k", "Escape"])
    session.wait("tray Escape dismissal", lambda: not state()["trayOpen"])
    time.sleep(0.6)
    open_tray()
    session.run(["wlrctl", "pointer", "move", "10000", "10000"])
    session.run(["wlrctl", "pointer", "click", "left"])
    session.wait("tray outside click dismissal", lambda: not state()["trayOpen"])
    time.sleep(0.6)
    open_tray()
    session.ipc(shell, "nonchalant", "run", "sound")
    session.wait("sound replaces tray", lambda: state()["controlMenu"] == "sound" and not state()["trayOpen"])
    session.ipc(shell, "nonchalant", "run", "sound")
    session.wait("sound closes", lambda: not state()["popupOpen"])
    time.sleep(0.6)
    passed.append("vertical tray flyout placement, stable bar, toggle, Escape, outside click and popup replacement")

    open_tray()
    click(item("trayFlyoutItem_test-0"))
    session.wait("tray activation reaches app", lambda: {"item": "test-0", "activate": True} in fixture_call("State")["events"])
    assert not state()["trayOpen"], "activation left tray open"
    time.sleep(0.6)
    open_tray()
    click(item("trayFlyoutItem_test-0"), "right")
    session.wait("tray app menu inside flyout", lambda: state()["trayOpen"] and state()["trayMenuItem"] == "test-0")
    session.wait("real DBusMenu entries", lambda: item("trayMenuAction_Open test app"))
    assert not item("trayMenuAction_Unavailable action")["enabled"]
    click(item("trayMenuAction_Unavailable action"))
    assert fixture_call("State")["events"] == [{"item": "test-0", "activate": True}]
    assert state()["trayOpen"]
    click(item("trayFlyoutBack"))
    session.wait("tray menu back navigation", lambda: state()["trayMenuItem"] == "" and item("trayFlyoutItem_test-1"))
    click(item("trayFlyoutItem_test-1"))
    session.wait("menu-only tray left click", lambda: state()["trayMenuItem"] == "test-1")
    session.wait("menu-only entries render", lambda: item("trayMenuAction_More actions"))
    click(item("trayMenuAction_More actions"))
    session.wait("tray submenu opens", lambda: item("trayMenuAction_Nested action"))
    session.run(["grim", str(session.root / "tray-submenu.png")])
    click(item("trayMenuAction_Nested action"))
    session.wait("nested menu action reaches app", lambda: {"item": "test-1", "menu": 3} in fixture_call("State")["events"])
    assert not state()["trayOpen"], "menu action left tray open"
    time.sleep(0.6)
    passed.append("real tray activation, right-click menu, disabled action, back navigation, menu-only item and submenu dispatch")

    open_tray()
    fixture_call("SetCount", 10)
    session.wait("tray grows live", lambda: state()["trayCount"] == 10 and item("trayFlyoutItem_test-9"))
    time.sleep(0.7)
    assert state()["trayButton"]["geometry"] == button_geometry, "tray growth resized bar"
    session.run(["grim", str(session.root / "tray-many-items.png")])
    click(item("trayFlyoutItem_test-1"))
    session.wait("selected menu before removal", lambda: state()["trayMenuItem"] == "test-1")
    fixture_call("SetCount", 1)
    session.wait("selected tray app disappears", lambda: state()["trayCount"] == 1 and state()["trayMenuItem"] == "" and item("trayFlyoutItem_test-0"))
    fixture_call("SetCount", 0)
    session.wait("empty tray closes and hides trigger", lambda: state()["trayCount"] == 0 and not state()["trayOpen"] and not state()["trayButton"]["visible"])
    fixture_call("SetCount", 2)
    session.wait("tray returns", lambda: state()["trayCount"] == 2 and state()["trayButton"]["visible"])
    passed.append("live tray growth, selected app removal, empty tray dismissal and trigger recovery")


def exercise(session, source, args, passed):
    private_source = session.root / "source"
    shutil.copytree(source, private_source, ignore=shutil.ignore_patterns(".git", "__pycache__"))
    fixture = Path(__file__).parent
    shutil.copy2(fixture / "probe.qml", private_source / "compositor-probe.qml")
    shutil.copy2(fixture / "client.qml", private_source / "compositor-client.qml")
    shutil.copy2(fixture / "RuntimeTestControl.qml", private_source / "RuntimeTestControl.qml")
    if args.compositor == "hyprland":
        native_file = private_source / "hyprland-native.qml"
        shutil.copy2(fixture / "hyprland-native.qml", native_file)
        native_probe = session.start("hyprland-native", [session.quickshell, "-p", str(native_file)])
        session.native_state = lambda: session.ipc(native_probe, "hyprland-native", "state")
        native_state = session.wait("native Quickshell Hyprland IPC", lambda:
            session.ipc(native_probe, "hyprland-native", "state"))
        (session.root / "quickshell-native-state.json").write_text(native_state)
    colors = Path(session.env["HOME"]) / ".cache/nonchalant"
    colors.mkdir(parents=True, exist_ok=True)
    shutil.copy2(private_source / "assets/colors/Catppuccin/dark.json", colors / "colors.json")
    shell_source = private_source / "shell.qml"
    shell_text = shell_source.read_text()
    final_brace = shell_text.rfind("}")
    shell_source.write_text(shell_text[:final_brace] + "    RuntimeTestControl {}\n" + shell_text[final_brace:])
    if args.baseline:
        shortcuts = private_source / "modules/services/GlobalShortcuts.qml"
        shortcuts.write_text(shortcuts.read_text().replace(
            'readonly property string ipcPipe: "/tmp/nonchalant_ipc.pipe"',
            'readonly property string ipcPipe: Quickshell.env("XDG_RUNTIME_DIR") + "/nonchalant_ipc.pipe"'))
    config = Path(session.env["XDG_CONFIG_HOME"]) / "nonchalant/config"
    config.mkdir(parents=True, exist_ok=True)
    (config / "bar.json").write_text(json.dumps({"style": args.style}))
    (config / "ai.json").write_text(json.dumps({"enabled": False}))
    if args.baseline:
        if not args.shell:
            raise RuntimeError("--baseline requires --shell")
    else:
        probe = session.start("probe", [session.quickshell, "-p", str(private_source / "compositor-probe.qml")])

        def state():
            return json.loads(session.ipc(probe, "compositor-test", "state"))

        session.state = state
        session.diagnostic = lambda: json.loads(session.ipc(probe, "compositor-test", "diagnostic"))

        session.wait("ready compositor service", lambda: state()["ready"])
    shell = None
    if args.shell:
        shell = session.start("shell", [session.quickshell, "-p", str(private_source)])
        session.wait("shell IPC", lambda: session.ipc(shell, "nonchalant", "run", "test-noop") or True)
        time.sleep(2)
        session.run(["grim", str(session.root / "empty-shell.png")])
        def shell_state():
            return json.loads(session.ipc(shell, "shell-test", "state"))
        session.shell_state = shell_state
        if args.style == "left":
            check_tray(session, shell, passed, args.scale)
        for command, field, island_mode in (("launcher", "launcherOpen", "apps"),
                ("dashboard", "dashboardOpen", "dashboard"), ("power", "powerOpen", "power")):
            session.ipc(shell, "nonchalant", "run", command)
            session.wait(f"{command} opens", lambda: (
                shell_state()["island"]["mode"] == island_mode
                if args.style == "island" else shell_state()[field]))
            time.sleep(0.7)
            session.run(["grim", str(session.root / f"{command}.png")])
            (session.root / f"{command}-state.json").write_text(json.dumps(shell_state(), indent=2))
            session.ipc(shell, "nonchalant", "run", command)
            session.wait(f"{command} dismisses", lambda: (
                not shell_state()["island"]["expanded"]
                if args.style == "island" else not shell_state()[field]))
            time.sleep(0.7)
            passed.append(f"{command} opens and reverse toggle dismisses")
    if shell and args.style == "default":
        session.ipc(shell, "nonchalant", "run", "wallpapers")
        session.wait("horizontal wallpaper tab", lambda:
            shell_state()["popupOpen"] and shell_state()["dashboardTab"] == 1)
        time.sleep(0.7)
        session.run(["grim", str(session.root / "wallpapers.png")])
        session.ipc(shell, "nonchalant", "run", "wallpapers")
        session.wait("horizontal wallpaper toggle dismisses", lambda: not shell_state()["popupOpen"])
        session.ipc(shell, "nonchalant", "run", "dashboard")
        session.wait("horizontal widgets tab", lambda:
            shell_state()["popupOpen"] and shell_state()["dashboardTab"] == 0)
        session.run(["wtype", "-M", "ctrl", "-k", "Tab", "-m", "ctrl"])
        session.wait("horizontal keyboard wallpaper tab", lambda: shell_state()["dashboardTab"] == 1)
        time.sleep(0.5)
        session.run(["wtype", "-M", "ctrl", "-M", "shift", "-k", "Tab", "-m", "shift", "-m", "ctrl"])
        session.wait("horizontal keyboard widgets tab", lambda: shell_state()["dashboardTab"] == 0)
        session.ipc(shell, "nonchalant", "run", "dashboard")
        session.wait("horizontal dashboard dismisses", lambda: not shell_state()["popupOpen"])
        passed.append("horizontal wallpaper tab, reverse toggle, and keyboard tab switching")
    if shell and args.style == "left":
        for mode in ("wifi", "sound", "mic", "bluetooth", "battery", "media"):
            session.ipc(shell, "nonchalant", "run", "dashboard")
            session.wait("dashboard before control menu", lambda: shell_state()["dashboardOpen"])
            session.ipc(shell, "nonchalant", "run", mode)
            session.wait(f"{mode} opens its own panel", lambda:
                shell_state()["controlMenu"] == mode)
            time.sleep(0.7)
            session.run(["grim", str(session.root / f"control-{mode}.png")])
            session.ipc(shell, "nonchalant", "run", mode)
            session.wait(f"{mode} reverse toggle dismisses", lambda: not shell_state()["popupOpen"])
        session.ipc(shell, "nonchalant", "run", "sound")
        session.wait("sound menu", lambda: shell_state()["controlMenu"] == "sound")
        time.sleep(0.7)
        audio_items = {item["name"]: item for item in shell_state()["dashboardItems"]}
        selector = audio_items["audioStatusSelector"]
        assert selector["visible"], "Audio selector track is hidden"
        x, y, width, height = audio_items["audioStatusTab-mic"]["geometry"]
        session.run(["wlrctl", "pointer", "move", "-10000", "-10000"])
        session.run(["wlrctl", "pointer", "move", str(round(x + width / 2)), str(round(y + height / 2))])
        session.run(["wlrctl", "pointer", "click", "left"])
        session.wait("mic tab replaces sound", lambda: shell_state()["controlMenu"] == "mic")
        time.sleep(0.7)
        current_selector = next(item for item in shell_state()["dashboardItems"]
                                if item["name"] == "audioStatusSelector")
        assert current_selector["geometry"] == selector["geometry"], "Tab switching moved the shared selector"
        session.run(["grim", str(session.root / "audio-mic-tab.png")])
        session.run(["wtype", "-k", "Left"])
        session.wait("left arrow selects volume", lambda: shell_state()["controlMenu"] == "sound")
        session.run(["wtype", "-k", "Right"])
        session.wait("right arrow selects microphone", lambda: shell_state()["controlMenu"] == "mic")
        session.run(["wtype", "-k", "Escape"])
        session.wait("Escape dismisses audio popup", lambda: not shell_state()["popupOpen"])
        passed.append("shared audio tabs switch by pointer and arrow keys, keep their track, and dismiss with Escape")
        passed.append("vertical control menus replace dashboard, switch, and reverse-toggle closed")
        session.ipc(shell, "nonchalant", "run", "dashboard")
        session.wait("dashboard notifications", lambda:
            shell_state()["popupOpen"] and shell_state()["dashboardSection"] == "notifications")
        time.sleep(0.7)

        def calendar_state():
            return next(item for item in shell_state()["dashboardItems"]
                        if item["name"] == "dashboardCalendar")

        calendar = calendar_state()
        pane = next(item for item in shell_state()["dashboardItems"]
                    if item["name"] == "dashboardSidePane")
        media = next(item for item in shell_state()["dashboardItems"]
                     if item["name"] == "dashboardMediaCard")
        for command, section in (("system-monitor", "stats"), ("wallpapers", "wallpapers")):
            session.ipc(shell, "nonchalant", "run", command)
            session.wait(f"dashboard right pane shows {section}", lambda:
                shell_state()["popupOpen"] and shell_state()["dashboardSection"] == section
                and shell_state()["controlMenu"] == "")
            session.wait("sampling follows selected section", lambda:
                shell_state()["systemMonitorOpen"] == (section == "stats"))
            time.sleep(0.7)
            assert calendar_state() == calendar, "pane switch moved or recreated the calendar"
            current_items = {item["name"]: item for item in shell_state()["dashboardItems"]}
            assert current_items["dashboardSidePane"]["geometry"][2] > pane["geometry"][2], "section did not receive extra width"
            assert current_items["dashboardMediaCard"] == media, "pane switch resized the media card"
            session.run(["grim", str(session.root / f"dashboard-{section}.png")])
        session.wait("wallpaper pane receives focus", lambda: any(
            item["name"] == "dashboardSidePane" and item["activeFocus"]
            for item in shell_state()["dashboardItems"]))
        for command in ("stats", "wallpapers", "stats", "wallpapers", "stats"):
            session.ipc(shell, "nonchalant", "run", command)
        session.wait("rapid switches settle on stats", lambda:
            shell_state()["dashboardSection"] == "stats" and shell_state()["systemMonitorOpen"])
        time.sleep(0.7)
        assert calendar_state() == calendar, "rapid pane switches changed the calendar"
        session.ipc(shell, "nonchalant", "run", "stats")
        session.wait("active pane toggles back to notifications", lambda:
            shell_state()["popupOpen"] and shell_state()["dashboardSection"] == "notifications"
            and not shell_state()["systemMonitorOpen"])
        session.ipc(shell, "nonchalant", "run", "stats")
        session.wait("stats before closing dashboard", lambda: shell_state()["systemMonitorOpen"])
        session.ipc(shell, "nonchalant", "run", "launcher")
        session.wait("dismissal releases sampling", lambda:
            not shell_state()["popupOpen"] and not shell_state()["systemMonitorOpen"])
        session.ipc(shell, "nonchalant", "run", "launcher")
        passed.append("dashboard panes preserve calendar, focus the active pane, survive rapid switches, restore notifications, and release sampling")
    client = session.start("client", [session.quickshell, "-p", str(private_source / "compositor-client.qml")])
    if args.baseline:
        time.sleep(2)
        session.run(["grim", str(session.root / "occupied-shell.png")])
        passed.append("baseline empty and occupied screenshots captured")
        return
    current = session.wait("two mapped clients", lambda: (
        value if len([w for w in value["windows"] if w["title"].startswith("Nonchalant Test ")
                      and w["output"] and w["workspaceId"]]) == 2
        else None) if (value := state()) else None)
    (session.root / "initial-state.json").write_text(json.dumps(current, indent=2))
    first = next(w for w in current["windows"] if w["title"] == "Nonchalant Test A")
    second = next(w for w in current["windows"] if w["title"] == "Nonchalant Test B")
    passed.append("actual clients appear in shared service")
    if shell:
        time.sleep(0.7)
        session.run(["grim", str(session.root / "occupied-shell.png")])
    if shell and args.style == "left" and args.compositor == "niri":
        original_position = session.shell_state()["barPosition"]
        session.ipc(probe, "compositor-test", "focusWindow", first["id"])
        session.wait("focused client before sidebar check", lambda: state()["focusedWindow"] == first["id"])
        session.run(["niri", "msg", "action", "maximize-column"])
        try:
            for position in ("top", "bottom"):
                session.ipc(shell, "shell-test", "assistant", "left", "true", "true", position, "true")
                session.wait("assistant sidebar is active", lambda: session.shell_state()["assistant"] is not None
                    and session.shell_state()["assistant"]["active"])
                sidebar = session.shell_state()["assistant"]
                assert sidebar["geometry"][1] == 0, "Left dock must not leave a horizontal bar gap"
                assert sidebar["geometry"][3] == session.shell_state()["panelSize"][1]
                session.wait("pinned sidebar reserves its full offset", lambda:
                    next(w for w in state()["windows"] if w["id"] == first["id"])["geometry"][2]
                    <= session.shell_state()["panelSize"][0] - session.shell_state()["assistant"]["geometry"][0] - sidebar["hitbox"][2])
            pinned_width = next(w for w in state()["windows"] if w["id"] == first["id"])["geometry"][2]
            session.run(["grim", str(session.root / "pinned-assistant.png")])
            session.ipc(shell, "shell-test", "assistant", "left", "false", "true", "top", "true")
            session.wait("unpinned sidebar releases its reservation", lambda:
                next(w for w in state()["windows"] if w["id"] == first["id"])["geometry"][2] > pinned_width)
            session.ipc(shell, "shell-test", "assistant", "right", "true", "true", "top", "true")
            session.wait("right sidebar reserves the opposite edge", lambda:
                next(w for w in state()["windows"] if w["id"] == first["id"])["geometry"][2]
                <= session.shell_state()["panelSize"][0] - 464)
            session.ipc(shell, "shell-test", "assistant", "left", "true", "true", "top", "false")
            session.wait("disabled bar removes the sidebar offset", lambda:
                session.shell_state()["assistant"]["geometry"][0] == 0
                and next(w for w in state()["windows"] if w["id"] == first["id"])["geometry"][2] > pinned_width)
        finally:
            session.ipc(shell, "shell-test", "assistant", "right", "false", "false", original_position, "true")
            session.run(["niri", "msg", "action", "maximize-column"])
        passed.append("pinned assistant reserves the dock offset, spans full height, and releases space when unpinned or the bar is disabled")
    session.ipc(probe, "compositor-test", "focusWindow", second["id"])
    session.wait("second client focus", lambda: state()["focusedWindow"] == second["id"])
    session.ipc(probe, "compositor-test", "focusWindow", first["id"])
    session.wait("targeted window focus", lambda: state()["focusedWindow"] == first["id"])
    passed.append("focus action reaches compositor")
    def window_badges():
        return [item for item in session.shell_state()["workspaceItems"]
                if "-window-" in item["name"] and item["visible"] and item["opacity"] > 0]

    def window_highlight():
        return next(item for item in session.shell_state()["workspaceItems"]
                    if item["name"].endswith("-highlight") and item["visible"] and item["opacity"] > 0)

    def window_highlight_aligned(window_id):
        badge = next(item for item in window_badges() if item["name"].endswith("-window-" + window_id))
        return all(abs(a - b) < 0.5 for a, b in zip(window_highlight()["geometry"], badge["geometry"]))

    def click_window_badge(window_id):
        badge = session.wait("visible workspace window icon", lambda: next((item
            for item in window_badges() if item["name"].endswith("-window-" + window_id)), None))
        axis = 1 if args.style == "left" else 0
        initial_geometry = window_highlight()["geometry"]
        initial_position = initial_geometry[axis] + initial_geometry[axis + 2] / 2
        target_position = badge["geometry"][axis] + badge["geometry"][axis + 2] / 2
        x, y, width, height = badge["geometry"]
        session.run(["wlrctl", "pointer", "move", "-10000", "-10000"])
        session.run(["wlrctl", "pointer", "move", str(round(x + width / 2)), str(round(y + height / 2))])
        session.run(["grim", "-c", str(session.root / "workspace-pointer.png")])
        (session.root / "workspace-click-state.json").write_text(json.dumps(session.shell_state(), indent=2))
        session.run(["wlrctl", "pointer", "click"])
        session.wait("window icon click focuses client", lambda: state()["focusedWindow"] == window_id)
        def window_highlight_in_transit():
            geometry = window_highlight()["geometry"]
            center = geometry[axis] + geometry[axis + 2] / 2
            return min(initial_position, target_position) < center < max(initial_position, target_position)
        session.wait("window highlight travels between icons", window_highlight_in_transit)
        session.run(["grim", str(session.root / "window-highlight-transition.png")])
        session.wait("window highlight settles on focused icon", lambda: window_highlight_aligned(window_id))

    def reveal_workspace_icons():
        if args.style == "island":
            session.run(["wlrctl", "pointer", "move", "-10000", "-10000"])
            session.run(["wlrctl", "pointer", "move", "640", "1"])
            time.sleep(0.7)

    if shell and args.style in ("left", "island"):
        reveal_workspace_icons()
        session.wait("both workspace window icons", lambda: len(window_badges()) == 2)
        session.wait("initial window highlight alignment", lambda: window_highlight_aligned(first["id"]))
        click_window_badge(second["id"])
        click_window_badge(first["id"])
        session.run(["wlrctl", "pointer", "move", "500", "300"])
        passed.append("workspace window icons focus both real clients and animate their shared highlight in both directions")
    def workspace_highlight():
        return next(item for item in session.shell_state()["workspaceItems"]
                    if item["name"] == "verticalWorkspaceHighlight")

    def workspace_button(workspace_id):
        return next(item for item in session.shell_state()["workspaceItems"]
                    if item["name"] == "verticalWorkspaceButton-" + workspace_id)

    def highlight_aligned(workspace_id):
        highlight = workspace_highlight()
        button = workspace_button(workspace_id)
        return highlight["opacity"] > 0 and all(
            abs(a - b) < 0.5 for a, b in zip(highlight["geometry"], button["geometry"]))

    if shell and args.style == "left":
        session.wait("workspace highlight at initial workspace", lambda: highlight_aligned(first["workspaceId"]))
        initial_highlight_y = workspace_highlight()["geometry"][1]
    session.ipc(probe, "compositor-test", "adjacent", first["output"], 1)
    current = session.wait("adjacent workspace", lambda: (
        value if value["focusedWorkspace"] != first["workspaceId"] else None)
        if (value := state()) else None)
    destination = current["focusedWorkspace"]
    if shell and args.style == "left":
        def highlight_in_transit():
            target_y = workspace_button(destination)["geometry"][1]
            indicator_y = workspace_highlight()["geometry"][1]
            return min(initial_highlight_y, target_y) < indicator_y < max(initial_highlight_y, target_y)
        session.wait("workspace highlight travels between buttons", highlight_in_transit)
        session.wait("workspace highlight settles on destination", lambda: highlight_aligned(destination))
        assert not window_badges(), "empty workspace still shows window icons"
        session.run(["grim", str(session.root / "workspace-highlight.png")])
    session.ipc(probe, "compositor-test", "focusWorkspace", first["workspaceId"])
    session.wait("original workspace focus", lambda: state()["focusedWorkspace"] == first["workspaceId"])
    if shell and args.style == "left":
        session.wait("workspace highlight returns to original", lambda: highlight_aligned(first["workspaceId"]))
        passed.append("vertical workspace highlight animates with real compositor focus and settles in both directions")
    session.ipc(probe, "compositor-test", "moveWindow", first["id"], destination)
    session.wait("window move", lambda: any(w["id"] == first["id"] and
        w["workspaceId"] == destination for w in state()["windows"]))
    assert state()["focusedWorkspace"] == first["workspaceId"], "move unexpectedly followed focus"
    passed.append("workspace scroll and targeted move reach compositor")
    if shell and args.style in ("left", "island"):
        reveal_workspace_icons()
        session.wait("moved window leaves active workspace icons", lambda:
            len(window_badges()) == 1 and window_badges()[0]["name"].endswith("-window-" + second["id"]))
        passed.append("workspace window icons update after moving a window")
    session.ipc(probe, "compositor-test", "focusWindow", first["id"])
    session.wait("moved client focus", lambda: state()["focusedWindow"] == first["id"])
    session.ipc(client, "test-client", "fullscreen", "true")
    session.wait("fullscreen output", lambda: first["output"] in state()["fullscreenOutputs"])
    passed.append("fullscreen is reported")
    session.run(["grim", str(session.root / "fullscreen.png")])
    session.ipc(client, "test-client", "fullscreen", "false")
    session.wait("fullscreen exit", lambda: first["output"] not in state()["fullscreenOutputs"])
    passed.append("fullscreen exit is reported")
    session.ipc(probe, "compositor-test", "closeWindow", "invalid-window-id")
    time.sleep(0.4)
    assert any(w["id"] == first["id"] for w in state()["windows"]), "invalid close killed focused client"
    passed.append("invalid close preserves focused client")
    session.ipc(probe, "compositor-test", "closeWindow", second["id"])
    session.wait("targeted close", lambda: not any(w["id"] == second["id"] for w in state()["windows"]))
    assert any(w["id"] == first["id"] for w in state()["windows"])
    passed.append("targeted close preserves other client")
    if shell:
        target_workspace = state()["focusedWorkspace"]
        target_output = state()["focusedMonitor"]
        session.ipc(shell, "nonchalant", "run", "settings")
        settings_window = session.wait("real settings window", lambda: next((w for w in state()["windows"]
            if "settings" in w["title"].lower() or "configuration" in w["title"].lower()), None))
        session.wait("settings placement and focus", lambda: any(w["id"] == settings_window["id"]
            and w["workspaceId"] == target_workspace and w["output"] == target_output
            for w in state()["windows"]) and state()["focusedWindow"] == settings_window["id"])
        time.sleep(1)
        session.run(["grim", str(session.root / "settings.png")])
        passed.append("full shell settings maps on requested workspace/output and receives focus")
    (session.root / "final-state.json").write_text(json.dumps(state(), indent=2))


def main():
    args = arguments()
    if args.inside_session is None:
        root = args.artifacts.resolve() if args.artifacts else Path(tempfile.mkdtemp(prefix="nonchalant-compositor-"))
        root.mkdir(mode=0o700, parents=True, exist_ok=True)
        env = private_environment(root)
        bus_config = root / "dbus.conf"
        bus_config.write_text('<busconfig><type>session</type><auth>EXTERNAL</auth>'
            f'<listen>unix:path={Path(env["XDG_RUNTIME_DIR"]) / "bus"}</listen>'
            '<policy context="default"><allow send_destination="*"/>'
            '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
        command = ["dbus-run-session", f"--config-file={bus_config}", "--", sys.executable, str(Path(__file__).resolve()),
                   "--inside-session", str(root), "--source", str(args.source.resolve()),
                   "--compositor", args.compositor, "--style", args.style,
                   "--quickshell", args.quickshell, "--scale", str(args.scale)]
        command.extend(flag for flag, enabled in (("--shell", args.shell),
            ("--baseline", args.baseline), ("--power-cycle", args.power_cycle),
            ("--text-rendering", args.text_rendering)) if enabled)
        runtime = Path(env["XDG_RUNTIME_DIR"])
        try:
            result = subprocess.run(command, env=env)
        finally:
            try:
                (root / "runtime").unlink()
                shutil.copytree(runtime, root / "runtime", ignore=lambda directory, names: [
                    name for name in names if (Path(directory) / name).is_socket()
                    or (Path(directory) / name).is_fifo()])
            finally:
                shutil.rmtree(runtime, ignore_errors=True)
        print(f"Artifacts: {root}")
        return result.returncode
    session = Session(args.inside_session, args.quickshell)
    result = {"compositor": args.compositor, "style": args.style,
              "source": str(args.source), "passed": []}
    exit_code = 1
    try:
        start_compositor(session, args.compositor)
        if args.compositor == "hyprland":
            if args.text_rendering or args.scale != 1:
                session.run(["hyprctl", "keyword", "monitor", f"TEST-1,1920x1200@60,0x0,{args.scale}"])
                session.wait("output scale", lambda: any(
                    monitor["name"] == "TEST-1" and abs(monitor["scale"] - args.scale) < 0.001
                    for monitor in json.loads(session.run(["hyprctl", "-j", "monitors"]))))
        elif args.scale != 1 or args.text_rendering:
            raise RuntimeError("--scale and --text-rendering currently require Hyprland")
        session.env["NONCHALANT_COMPOSITOR"] = args.compositor
        if args.compositor == "hyprland":
            session.env["QT_LOGGING_RULES"] = "quickshell.hyprland.ipc.debug=true;quickshell.io.socket.debug=true"
        result["quickshellVersion"] = session.run([session.quickshell, "--version"])
        if args.power_cycle:
            session.power_script = args.source / "scripts/compositor_power.py"
            session.run([sys.executable, str(session.power_script), "off"])
            session.run([sys.executable, str(session.power_script), "on"])
            result["passed"].append("standalone monitor power off/on reaches disposable compositor")
        if args.text_rendering:
            check_text_rendering(session, args.source, args.scale, result["passed"])
        if args.shell or not args.text_rendering:
            exercise(session, args.source, args, result["passed"])
        print(json.dumps(result, indent=2))
        exit_code = 0
    except (RuntimeError, AssertionError, subprocess.TimeoutExpired) as error:
        result["error"] = str(error)
        print(json.dumps(result, indent=2), file=sys.stderr)
        exit_code = 1
    except BaseException as error:
        result["error"] = f"{type(error).__name__}: {error}".rstrip(": ")
        raise
    finally:
        if hasattr(session, "power_script"):
            try:
                session.run([sys.executable, str(session.power_script), "on"])
            except RuntimeError as error:
                result["powerRestoreError"] = str(error)
        if hasattr(session, "native_state"):
            try:
                (session.root / "quickshell-native-final-state.json").write_text(session.native_state())
            except RuntimeError:
                pass
        if hasattr(session, "shell_state"):
            try:
                (session.root / "shell-state.json").write_text(json.dumps(session.shell_state(), indent=2))
                session.run(["grim", str(session.root / "final-shell.png")])
            except RuntimeError:
                pass
        if hasattr(session, "diagnostic"):
            try:
                (session.root / "backend-diagnostic.json").write_text(json.dumps(session.diagnostic(), indent=2))
            except (RuntimeError, ValueError):
                pass
        if session.state is not None:
            try:
                (session.root / "last-state.json").write_text(json.dumps(session.state(), indent=2))
            except (RuntimeError, ValueError):
                pass
        if hasattr(session, "shell_state"):
            try:
                (session.root / "last-shell-state.json").write_text(json.dumps(session.shell_state(), indent=2))
            except (RuntimeError, ValueError):
                pass
            try:
                session.run(["grim", str(session.root / "final-screen.png")])
            except RuntimeError:
                pass
        if args.compositor == "niri" and "NIRI_SOCKET" in session.env:
            try:
                (session.root / "native-focused-window.json").write_text(session.run(["niri", "msg", "--json", "focused-window"]))
            except RuntimeError:
                pass
        if args.compositor == "hyprland" and "HYPRLAND_INSTANCE_SIGNATURE" in session.env:
            for query in ("monitors", "clients", "workspaces"):
                try:
                    (session.root / f"native-{query}.json").write_text(session.run(["hyprctl", "-j", query]))
                except RuntimeError:
                    pass
        session.stop()
        result["runtimeDiagnosticCounts"] = {}
        for path in session.root.glob("*.log"):
            lines = path.read_text(errors="replace").splitlines()
            result["runtimeDiagnosticCounts"][path.name] = {
                "qmlErrors": sum("ERROR: qs:" in line for line in lines),
                "bindingOrTypeWarnings": sum(any(marker in line for marker in
                    ("Binding loop", "TypeError:", "ReferenceError:")) for line in lines),
                "missingTools": sum("Process failed to start" in line for line in lines)
            }
        broken = sum(counts["qmlErrors"] + counts["bindingOrTypeWarnings"]
                     for counts in result["runtimeDiagnosticCounts"].values())
        if broken:
            result["error"] = result.get("error") or (
                f"{broken} QML errors or binding failures in runtime logs")
            exit_code = 1
        (session.root / "result.json").write_text(json.dumps(result, indent=2))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
