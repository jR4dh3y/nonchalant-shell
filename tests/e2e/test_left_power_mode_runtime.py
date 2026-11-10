"""Drive the left dock's power mode in a full private shell.

The shell runs on a disposable Niri nested in headless Weston, with private
runtime, config, cache, session bus and a missing system bus. Power actions are
replaced by a logging stub in a private copy of the power menu module, and
`systemctl`/`loginctl` on PATH only log, so nothing can lock, suspend or power
off the machine.
"""

from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tests.runtime.run_compositor import Session, private_environment, start_compositor

CONTROL = r'''
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.services

Item {
    id: root

    function find(item, name) {
        if (!item)
            return null;
        if (item.objectName === name)
            return item;
        for (const child of item.children) {
            const found = root.find(child, name);
            if (found)
                return found;
        }
        return null;
    }

    function enabledInTree(item) {
        for (let current = item; current; current = current.parent)
            if (!current.enabled)
                return false;
        return true;
    }

    function effectiveOpacity(item) {
        let value = 1;
        for (let current = item; current; current = current.parent)
            value *= current.visible ? current.opacity : 0;
        return value;
    }

    function panel() {
        return Visibilities.getBarPanelForScreen(Quickshell.screens[0]?.name ?? "");
    }

    function describe(name) {
        const item = root.find(root.panel()?.contentItem ?? null, name);
        if (!item)
            return null;
        const position = item.mapToItem(null, 0, 0);
        return {
            geometry: [position.x, position.y, item.width, item.height],
            enabled: root.enabledInTree(item),
            opacity: root.effectiveOpacity(item),
            activeFocus: item.activeFocus,
            accessible: item.Accessible.name ?? ""
        };
    }

    // Every reveal value, so fast animations can be checked between IPC polls.
    property list<real> trace: []
    property bool reverseOpening: false
    property real reversalBefore: 0
    property real reversalAfter: 0
    Connections {
        target: Visibilities.powerMenuButtons[Quickshell.screens[0]?.name ?? ""]?.dockMode ?? null
        function onRevealChanged() {
            root.trace.push(target.reveal);
            if (root.reverseOpening && target.open && target.reveal > 0 && target.reveal < 1) {
                root.reverseOpening = false;
                root.reversalBefore = target.reveal;
                Visibilities.powerMenuButtons[Quickshell.screens[0].name].togglePopup();
                root.reversalAfter = target.reveal;
            }
        }
    }

    // Synthetic clicks through Qt's real delivery inside the panel window.
    TestCase {
        id: input
        name: "LeftPowerInput"
        when: false
    }

    IpcHandler {
        target: "power-test"

        function reverseNextOpen(): void {
            root.reverseOpening = true;
        }

        function state(): string {
            const host = Visibilities.powerMenuButtons[Quickshell.screens[0]?.name ?? ""] ?? null;
            const mode = host?.dockMode ?? null;
            const names = ["verticalMainPill", "verticalTrayButton", "verticalAudioControl",
                "verticalBrightnessDroplet", "verticalDeviceStatusButton", "verticalClockDroplet",
                "leftPowerSession", "leftPowerHighlight", "leftPowerKeys", "verticalWorkspaceButton-1",
                "leftPower-lock", "leftPower-suspend", "leftPower-hibernate",
                "leftPower-logout", "leftPower-reboot", "leftPower-poweroff", "powerMenuMorph"];
            const items = {};
            for (const name of names)
                items[name] = root.describe(name);
            const panel = root.panel();
            return JSON.stringify({
                open: host?.menuOpen ?? false,
                inDock: host?.inDock ?? false,
                popupWindow: root.find(host, "powerMenuMorph")?.visible ?? false,
                reveal: mode?.reveal ?? -1,
                currentIndex: mode?.currentIndex ?? -1,
                armed: mode?.armedAction ?? "",
                trace: root.trace,
                reversalBefore: root.reversalBefore,
                reversalAfter: root.reversalAfter,
                fullScreenInput: panel?.needsFullScreenInput ?? false,
                exclusiveKeyboard: (panel?.WlrLayershell.keyboardFocus ?? 0) !== 0,
                items: items
            });
        }

        function resetTrace(): void {
            root.trace = [];
        }

        function click(name: string): void {
            const item = root.find(root.panel()?.contentItem ?? null, name);
            input.mouseClick(item);
        }

        function clickAt(x: real, y: real): void {
            input.mouseClick(root.panel().contentItem, x, y);
        }
    }
}
'''

# One StatusNotifierItem, so the dock shows its tray droplet as on the desktop.
TRAY_ITEM = r'''
import dbus, dbus.service, os
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = f"org.kde.StatusNotifierItem-{os.getpid()}-1"
PROPS = {"Category": "ApplicationStatus", "Id": "left-power-test", "Title": "Test item",
         "Status": "Active", "IconName": "folder", "ItemIsMenu": False,
         "Menu": dbus.ObjectPath("/NO_DBUSMENU")}

class Item(dbus.service.Object):
    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        return PROPS[prop]

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return PROPS

    @dbus.service.method("org.kde.StatusNotifierItem", in_signature="ii")
    def Activate(self, x, y):
        pass

Item(dbus.service.BusName(name, bus), "/StatusNotifierItem")

def register():
    try:
        bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher").RegisterStatusNotifierItem(
            name, dbus_interface="org.kde.StatusNotifierWatcher")
        return False
    except dbus.DBusException:
        return True

GLib.timeout_add(200, register)
GLib.MainLoop().run()
'''

STUB = '''    function run(action: string): void {
        closeMenu();
        console.log("POWER_ACTION_STUB " + action);
    }
'''


def private_shell(fixture):
    shell = fixture / "shell"
    shell.mkdir()
    for source in ROOT.iterdir():
        if source.name in ("modules", "shell.qml", ".git", "tests"):
            continue
        (shell / source.name).symlink_to(source, target_is_directory=source.is_dir())
    modules = shell / "modules"
    modules.mkdir()
    for source in (ROOT / "modules").iterdir():
        if source.name != "widgets":
            (modules / source.name).symlink_to(source, target_is_directory=source.is_dir())
    widgets = modules / "widgets"
    widgets.mkdir()
    for source in (ROOT / "modules/widgets").iterdir():
        if source.name != "powermenu":
            (widgets / source.name).symlink_to(source, target_is_directory=source.is_dir())
    powermenu = shutil.copytree(ROOT / "modules/widgets/powermenu", widgets / "powermenu")
    host = powermenu / "PowerMenuHost.qml"
    text = host.read_text()
    start = text.index("    function run(action: string): void {")
    end = text.index("    }\n", text.index("Quickshell.execDetached", start)) + len("    }\n")
    host.write_text(text[:start] + STUB + text[end:])
    assert "execDetached" not in host.read_text() and "LockscreenService.lock" not in host.read_text()
    shell_text = (ROOT / "shell.qml").read_text()
    final_brace = shell_text.rfind("}")
    (shell / "shell.qml").write_text(shell_text[:final_brace] + "    PowerTestControl {}\n" + shell_text[final_brace:])
    (shell / "PowerTestControl.qml").write_text(CONTROL)
    return shell


def exercise(fixture, artifacts):
    session = Session(fixture, shutil.which("qs"))
    bin_dir = fixture / "bin"
    bin_dir.mkdir()
    for tool in ("systemctl", "loginctl"):
        stub = bin_dir / tool
        stub.write_text(f'#!/bin/sh\necho "{tool} $*" >> "{fixture}/blocked-commands.log"\n')
        stub.chmod(0o755)
    # Keep the host's real backlight and DDC monitors out of the dock: a late
    # brightness read would otherwise change the dock under the test.
    for tool in ("brightnessctl", "ddcutil"):
        stub = bin_dir / tool
        stub.write_text("#!/bin/sh\nexit 1\n")
        stub.chmod(0o755)
    session.env["PATH"] = f"{bin_dir}:{session.env['PATH']}"
    checks = []
    try:
        start_compositor(session, "niri")
        session.env["NONCHALANT_COMPOSITOR"] = "niri"
        config = Path(session.env["XDG_CONFIG_HOME"]) / "nonchalant/config"
        config.mkdir(parents=True, exist_ok=True)
        (config / "bar.json").write_text(json.dumps({"style": "left"}))
        (config / "ai.json").write_text(json.dumps({"enabled": False}))
        colors = Path(session.env["HOME"]) / ".cache/nonchalant"
        colors.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "assets/colors/Catppuccin/dark.json", colors / "colors.json")
        (fixture / "tray_item.py").write_text(TRAY_ITEM)
        session.start("tray-fixture", [sys.executable, "-I", str(fixture / "tray_item.py")])
        shell = session.start("shell", [session.quickshell, "-p", str(private_shell(fixture)), "--no-color"])

        def state():
            return json.loads(session.ipc(shell, "power-test", "state"))

        def item(name):
            return state()["items"][name]

        def shot(name):
            path = artifacts / f"left-power-{name}.png"
            session.run(["grim", str(path)])
            return path

        def trace():
            session.ipc(shell, "power-test", "resetTrace")

        def traced():
            values = state()["trace"]
            jumps = max((abs(b - a) for a, b in zip(values, values[1:])), default=0)
            return values, jumps

        def toggle():
            # The Mod+X binding spawns exactly this IPC call.
            session.ipc(shell, "nonchalant", "run", "powermenu")

        def keys(*names):
            for name in names:
                session.run(["wtype", "-k", name])
                time.sleep(0.08)

        session.wait("shell IPC", lambda: state()["items"]["verticalMainPill"] is not None, timeout=30)
        session.wait("tray droplet", lambda: (item("verticalTrayButton") or {}).get("opacity", 0) == 1, timeout=15)
        # Startup meters (brightness, battery) ease in after the dock appears;
        # the baseline must be the settled dock, not a frame of that easing.
        from PIL import Image, ImageChops
        settle_deadline = time.monotonic() + 15
        previous = None
        while True:
            time.sleep(0.5)
            with Image.open(shot("normal")) as frame:
                current = frame.convert("RGB")
            if previous is not None and ImageChops.difference(previous, current).getbbox() is None:
                break
            assert time.monotonic() < settle_deadline, "Dock never settled before the baseline shot"
            previous = current
        normal = state()["items"]

        trace()
        toggle()
        session.wait("dock power mode opens", lambda: state()["open"] and state()["inDock"])
        session.wait("power mode settled", lambda: state()["reveal"] == 1)
        values, jumps = traced()
        assert sum(0 < v < 1 for v in values) >= 3 and max(values) > 1, ("Spring reveal with overshoot", values)
        time.sleep(0.2)
        opened = state()
        items = opened["items"]
        assert not opened["popupWindow"], "Left dock must not use the popup surface"
        assert opened["fullScreenInput"] and opened["exclusiveKeyboard"], opened
        session.wait("power keys focus", lambda: item("leftPowerKeys")["activeFocus"])
        for name in ("verticalAudioControl", "verticalBrightnessDroplet", "verticalDeviceStatusButton",
                     "verticalTrayButton", "verticalClockDroplet", "verticalWorkspaceButton-1"):
            assert not items[name]["enabled"], f"{name} still takes input in power mode"
        for name in ("verticalAudioControl", "verticalBrightnessDroplet", "verticalDeviceStatusButton",
                     "verticalTrayButton", "verticalWorkspaceButton-1"):
            assert items[name]["opacity"] < 0.01, f"{name} still shows in power mode"
        assert items["verticalClockDroplet"]["opacity"] == 1, "The clock keeps the time"
        for action, droplet in (("logout", "verticalAudioControl"), ("reboot", "verticalBrightnessDroplet"),
                                ("poweroff", "verticalDeviceStatusButton")):
            assert items[f"leftPower-{action}"]["geometry"] == normal[droplet]["geometry"], (
                f"{action} must take the {droplet} slot", items[f"leftPower-{action}"], normal[droplet])
            assert items[f"leftPower-{action}"]["enabled"], action
        pill, old_pill = items["verticalMainPill"]["geometry"], normal["verticalMainPill"]["geometry"]
        assert pill[1] + pill[3] > old_pill[1] + old_pill[3], "The capsule absorbs the folded tray droplet"
        assert pill[1] > old_pill[1] and pill[3] < old_pill[3], "The capsule shrinks onto the session actions"
        session_box = items["leftPowerSession"]["geometry"]
        padding = 8  # LeftBar.contentPadding
        assert abs(session_box[1] - pill[1] - padding) < 1 and abs(pill[1] + pill[3] - session_box[1] - session_box[3] - padding) < 1, (
            "The capsule wraps exactly the session actions", pill, session_box)
        hibernate = items["leftPower-hibernate"]["geometry"]
        assert hibernate[1] + hibernate[3] < pill[1] + pill[3] and hibernate[1] > pill[1] + pill[3] / 2, (
            "Session actions sit at the capsule's bottom", hibernate, pill)
        assert items["leftPowerHighlight"]["geometry"] == items["leftPower-lock"]["geometry"]
        assert opened["currentIndex"] == 0
        checks.append("Mod+X IPC path turns the real dock into power mode: capsule + three droplet slots, "
                      "normal controls disabled and hidden, clock inert, focus and full-screen input")
        shot("open")

        keys("Down", "Down", "Down", "Down", "Down")
        session.wait("keyboard selection reaches Shut down", lambda: state()["currentIndex"] == 5)
        rest = item("leftPower-poweroff")["geometry"]
        keys("Return")
        session.wait("Shut down arms", lambda: state()["armed"] == "poweroff")
        session.wait("armed droplet stretches", lambda: item("leftPower-poweroff")["geometry"][2] > rest[2] * 2)
        assert item("leftPower-poweroff")["accessible"] == "Confirm shut down"
        time.sleep(0.4)
        shot("armed")
        keys("Escape")
        session.wait("Escape cancels arming", lambda: state()["armed"] == "")
        assert state()["open"], "First Escape only disarms"
        session.wait("armed droplet returns", lambda: item("leftPower-poweroff")["geometry"] == rest)
        session.run(["wtype", "-P", "Return"])
        time.sleep(1.4)
        session.run(["wtype", "-p", "Return"])
        assert state()["armed"] == "poweroff" and state()["open"], "Held Enter must arm once and never confirm"
        keys("Up")
        session.wait("moving away disarms", lambda: state()["armed"] == "" and state()["currentIndex"] == 4)
        time.sleep(0.4)
        shot("selected")
        keys("Return")
        session.wait("Restart arms", lambda: state()["armed"] == "reboot")
        session.wait("confirmation timeout", lambda: state()["armed"] == "", timeout=7)
        assert state()["open"]
        checks.append("keyboard selection, arm stretch + accessible confirm name, Escape disarm, held-Enter "
                      "no-repeat, move-away disarm and 5 s timeout")

        session.ipc(shell, "power-test", "click", "leftPower-suspend")
        session.wait("hover/click selects Sleep", lambda: not state()["open"])
        session.wait("restored after action", lambda: state()["reveal"] == 0)
        time.sleep(0.3)
        assert "POWER_ACTION_STUB suspend" in (fixture / "shell.log").read_text()
        toggle()
        session.wait("reopen", lambda: state()["reveal"] == 1)
        assert state()["currentIndex"] == 0 and state()["armed"] == ""
        session.ipc(shell, "power-test", "click", "leftPower-reboot")
        session.wait("click arms Restart", lambda: state()["armed"] == "reboot")
        session.ipc(shell, "power-test", "click", "leftPower-reboot")
        session.wait("second click confirms into the stub", lambda: not state()["open"])
        assert "POWER_ACTION_STUB reboot" in (fixture / "shell.log").read_text()
        checks.append("clicks dispatch Sleep directly and Restart only on the second click (logging stub)")
        session.wait("restored", lambda: state()["reveal"] == 0)

        toggle()
        session.wait("reopen for outside click", lambda: state()["reveal"] == 1)
        session.ipc(shell, "power-test", "clickAt", 700, 360)
        session.wait("outside click dismisses", lambda: not state()["open"])
        session.wait("restored", lambda: state()["reveal"] == 0)
        toggle()
        session.wait("reopen for clock click", lambda: state()["reveal"] == 1)
        session.ipc(shell, "power-test", "click", "verticalClockDroplet")
        session.wait("inert clock click dismisses", lambda: not state()["open"])
        session.wait("restored", lambda: state()["reveal"] == 0)
        toggle()
        session.wait("reopen for Escape", lambda: state()["reveal"] == 1)
        trace()
        keys("Escape")
        session.wait("unarmed Escape closes", lambda: not state()["open"])
        session.wait("restored after Escape", lambda: state()["reveal"] == 0)
        values, jumps = traced()
        assert sum(0 < v < 1 for v in values) >= 3 and max(values) <= 1, ("Monotonic collapse", values)
        assert all(b <= a for a, b in zip(values, values[1:])), ("Collapse never swells", values)
        time.sleep(0.5)
        restored = state()
        assert not restored["fullScreenInput"] and not restored["exclusiveKeyboard"], restored
        for name, value in normal.items():
            if name.startswith("vertical"):
                now = restored["items"][name]
                assert now["geometry"] == value["geometry"] and now["enabled"] == value["enabled"], (name, now, value)
                assert abs(now["opacity"] - value["opacity"]) < 0.01, (name, now, value)
        assert restored["items"]["leftPower-poweroff"]["opacity"] == 0
        assert not restored["items"]["leftPower-poweroff"]["enabled"], "No residual power hitboxes"
        from PIL import Image, ImageChops
        clock_top = round(normal["verticalClockDroplet"]["geometry"][1])
        with Image.open(artifacts / "left-power-normal.png") as before, Image.open(shot("restored")) as after:
            # Above the clock, whose minutes may have moved on.
            box = (0, 0, before.width, clock_top)
            assert ImageChops.difference(before.convert("RGB").crop(box), after.convert("RGB").crop(box)).getbbox() is None, (
                "Restored dock differs from the normal dock")
        checks.append("outside click, inert clock click and unarmed Escape dismiss; dock geometry, opacity, "
                      "input and keyboard fully restore")

        trace()
        # Reverse from an actual animation tick, independent of IPC latency.
        session.ipc(shell, "power-test", "reverseNextOpen")
        toggle()
        session.wait("reversal settles closed", lambda: not state()["open"] and state()["reveal"] == 0)
        values, jumps = traced()
        reversal = state()
        assert 0 < reversal["reversalBefore"] < 1, reversal
        assert reversal["reversalBefore"] == reversal["reversalAfter"], ("Reversal must preserve its starting value", reversal)
        peak = max(values)
        assert 0 < peak < 1, ("Reversal must start before the open settles", values)
        assert jumps < 0.3, ("Reversal continues from the current reveal", values)
        for _ in range(3):
            toggle()
            session.wait("repeat open", lambda: state()["open"])
            toggle()
            session.wait("repeat close", lambda: not state()["open"])
        session.wait("repeat settles", lambda: state()["reveal"] == 0)
        checks.append("repeated Mod+X toggling and mid-animation reversal continue from the current reveal")

        session.ipc(shell, "nonchalant", "run", "launcher")
        session.wait("launcher opens", lambda: state()["fullScreenInput"])
        toggle()
        session.wait("power replaces launcher", lambda: state()["open"])
        session.ipc(shell, "nonchalant", "run", "launcher")
        session.wait("launcher replaces power", lambda: not state()["open"])
        session.ipc(shell, "nonchalant", "run", "launcher")
        checks.append("run menu and power mode replace each other")

        log = (fixture / "shell.log").read_text()
        blocked = fixture / "blocked-commands.log"
        assert not blocked.exists(), blocked.read_text()
        actions = [line for line in log.splitlines() if "POWER_ACTION_STUB" in line]
        assert len(actions) == 2, actions
        for line in log.splitlines():
            if "LeftPower" in line or "LeftBar" in line or "PowerMenuHost" in line:
                assert "rror" not in line and "is not a type" not in line, line
        print("LEFT_POWER_MODE_PASSED")
        for check in checks:
            print("PASS:", check)
        return 0
    except Exception as error:
        print("LEFT_POWER_MODE_FAILED", error)
        try:
            print(json.dumps(state(), indent=1)[:4000])
        except Exception as state_error:
            print("no state", state_error)
        tray_log = fixture / "tray-fixture.log"
        if tray_log.exists():
            print(tray_log.read_text()[-2000:])
        shell_log = fixture / "shell.log"
        if shell_log.exists():
            print(shell_log.read_text()[-6000:])
        return 1
    finally:
        session.stop()


@unittest.skipUnless(all(shutil.which(tool) for tool in ("qs", "weston", "niri", "dbus-run-session", "grim", "wtype")),
                     "Quickshell, Weston, Niri, D-Bus, grim and wtype are required")
class LeftPowerModeRuntimeTests(unittest.TestCase):
    def test_dock_turns_into_power_mode(self):
        artifacts = Path(os.environ.get("LEFT_POWER_ARTIFACTS") or tempfile.mkdtemp(prefix="nonchalant-left-power-shots-"))
        artifacts.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="nonchalant-left-power-") as directory:
            fixture = Path(directory)
            env = private_environment(fixture)
            env["DBUS_SYSTEM_BUS_ADDRESS"] = "unix:path=" + str(fixture / "no-system-bus")
            bus_config = fixture / "dbus.conf"
            bus_config.write_text('<busconfig><type>session</type><auth>EXTERNAL</auth>'
                f'<listen>unix:path={Path(env["XDG_RUNTIME_DIR"]) / "bus"}</listen>'
                '<policy context="default"><allow send_destination="*"/>'
                '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
            try:
                result = subprocess.run(["dbus-run-session", f"--config-file={bus_config}", "--",
                    sys.executable, __file__, "--exercise", str(fixture), str(artifacts)],
                    env=env, capture_output=True, text=True, timeout=150)
                (artifacts / "exercise.log").write_text(result.stdout + result.stderr)
                self.assertEqual(result.returncode, 0, f"see {artifacts / 'exercise.log'}")
                print(result.stdout[-2000:])
            finally:
                shutil.rmtree(env["XDG_RUNTIME_DIR"])


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--exercise":
        raise SystemExit(exercise(Path(sys.argv[2]), Path(sys.argv[3])))
    unittest.main()
