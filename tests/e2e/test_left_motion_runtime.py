"""Frame-trace the left dock's bar-attached surfaces in a full private shell.

The shell runs on a disposable Niri nested in headless Weston with private
runtime, config, cache and session bus, and a missing system bus. A test-only
control samples every animation tick of the dashboard surface and the tray
flyout: body geometry, corner radii, content position and opacity. Nothing
here runs a power action or touches the user's compositor.
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
assert (ROOT / "shell.qml").is_file() and (ROOT / "modules/components/MorphSurface.qml").is_file(), ROOT
sys.path.insert(0, str(ROOT))

from tests.runtime.run_compositor import Session, private_environment, start_compositor

CONTROL = r'''
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.modules.services

Item {
    id: root

    function nodes(item) {
        const list = [];
        for (const child of item.children ?? [])
            list.push(child);
        // Popup windows live in `data`; walk into their scene too.
        for (const entry of item.data ?? [])
            if (entry && entry.anchor !== undefined && entry.contentItem)
                list.push(entry.contentItem);
        return list;
    }

    function find(item, name) {
        if (!item)
            return null;
        if (item.objectName === name)
            return item;
        for (const child of root.nodes(item)) {
            const found = root.find(child, name);
            if (found)
                return found;
        }
        return null;
    }

    function findWindow(item, name) {
        if (!item)
            return null;
        for (const entry of item.data ?? [])
            if (entry && entry.anchor !== undefined && entry.objectName === name)
                return entry;
        for (const child of root.nodes(item)) {
            const found = root.findWindow(child, name);
            if (found)
                return found;
        }
        return null;
    }

    function panel() {
        return Visibilities.getBarPanelForScreen(Quickshell.screens[0]?.name ?? "");
    }

    function clock() {
        return Visibilities.dashboardControllers[Quickshell.screens[0]?.name ?? ""] ?? null;
    }

    function tray() {
        return root.findWindow(root.panel()?.contentItem ?? null, "verticalTrayFlyout");
    }

    function dashSurface() {
        return root.find(root.panel()?.contentItem ?? null, "dashboardSurface");
    }

    function timeSurface() {
        const popup = root.findWindow(root.panel()?.contentItem ?? null, "clockTimePopup");
        return root.find(popup?.contentItem ?? null, "clockTimePopupSurface");
    }

    function traySurface() {
        return root.find(root.tray()?.contentItem ?? null, "verticalTrayFlyoutSurface");
    }

    function rect(item) {
        if (!item)
            return null;
        const p = item.mapToGlobal(0, 0);
        return [p.x, p.y, item.width, item.height];
    }

    function effectiveOpacity(item) {
        let value = 1;
        for (let current = item; current; current = current.parent)
            value *= current.visible ? current.opacity : 0;
        return value;
    }

    function sample(surface) {
        if (!surface)
            return null;
        const body = surface.body;
        if (!body.visible)
            return { visible: false, reveal: surface.reveal, moving: false };
        let chrome = null;
        let viewport = null;
        // A baseline checkout's body is the chrome and the clip at once.
        const legacy = body.contentInset !== undefined;
        if (legacy) {
            chrome = body;
            viewport = body;
        }
        let outgoing = null;
        for (const child of legacy ? [] : body.children) {
            if (child.contentInset !== undefined)
                chrome = child;
            else if (child.restX !== undefined && child.fragmentShader !== undefined)
                outgoing = child;
            else if (child.clip && child.layer)
                viewport = child;
        }
        let page = null;
        for (const child of viewport?.children ?? [])
            if (child.drift !== undefined)
                page = child;
        // Shallow path (page > host loader > control menu > panel loader):
        // a full tree walk on every tick would stall the thread it measures.
        let panel = null;
        for (const child of page?.children ?? [])
            for (const inner of child.item?.children ?? [])
                if (inner.objectName === "controlMenuPanel")
                    panel = inner;
        let pane = null;
        for (const child of chrome?.children ?? [])
            if (child.variant !== undefined && child.visible)
                pane = child;
        return {
            reveal: surface.reveal,
            shown: surface.shown,
            visible: body.visible,
            body: root.rect(body),
            radius: body.radius,
            chrome: legacy ? (body.variant === "transparent" ? 0 : 1) : (chrome && chrome.visible ? chrome.opacity : 0),
            chromeRadius: chrome ? chrome.radius : -1,
            pane: pane ? root.rect(pane) : null,
            paneRadius: pane ? pane.radius : -1,
            paneInset: pane ? pane.anchors.margins : -1,
            page: page ? root.rect(page) : null,
            pageOpacity: page ? root.effectiveOpacity(page) : 0,
            content: [surface.contentWidth, surface.contentHeight],
            rest: [surface.bodyWidth, surface.bodyHeight],
            restY: surface.restY ?? 0,
            moving: surface.moving ?? (!surface.fullyHidden && (surface.reveal !== 1
                || surface.bodyWidth !== surface.contentWidth || surface.bodyHeight !== surface.contentHeight)),
            masked: page?.layer.enabled ?? false,
            presented: surface.presentedKey ?? null,
            outgoing: outgoing && outgoing.visible ? root.rect(outgoing) : null,
            outgoingOpacity: outgoing && outgoing.visible ? outgoing.opacity : 0,
            handoffPending: surface.handoffPending ?? false,
            shownMode: panel?.parent?.shownMode ?? "",
            panelOpacity: panel ? root.effectiveOpacity(panel) : -1
        };
    }

    function screenSize() {
        const screen = Quickshell.screens[0];
        return [screen?.width ?? 0, screen?.height ?? 0];
    }

    // Pixel pass: pause a surface's own reveal animation once it passes a
    // threshold, so a mid-morph frame can be composited and screenshotted.
    property string freezeKey: ""
    property real freezeAt: 2
    function revealAnimations(surface) {
        const list = [];
        for (const entry of surface?.resources ?? [])
            if (entry && entry.property === "reveal" && entry.paused !== undefined)
                list.push(entry);
        return list;
    }
    function surfaceFor(key) {
        return key === "tray" ? root.traySurface() : root.dashSurface();
    }
    FrameAnimation {
        running: root.freezeKey !== ""
        onTriggered: {
            const surface = root.surfaceFor(root.freezeKey);
            if (!surface || surface.reveal < root.freezeAt)
                return;
            for (const animation of root.revealAnimations(surface))
                if (animation.running)
                    animation.paused = true;
            root.freezeKey = "";
        }
    }

    property bool tracing: false
    property var trace: []
    // Resolved once per trace; these surfaces live as long as the shell.
    property var surfaces: ({})
    FrameAnimation {
        id: tracer
        running: root.tracing
        onTriggered: {
            if (root.trace.length > 1500)
                return;
            const clock = root.surfaces.clock;
            const tray = root.surfaces.tray;
            root.trace.push({
                // The animation clock, which is what every animation reads;
                // wall time bunches ticks around a stalled frame.
                t: Math.round(tracer.elapsedTime * 1000),
                dash: root.sample(root.surfaces.dash),
                tray: root.sample(root.surfaces.traySurface),
                time: root.sample(root.surfaces.time),
                mode: clock?.controlMode ?? "",
                section: clock?.dashboardSection ?? "",
                trayMenu: tray?.menuItem?.id ?? "",
                trayWindow: tray ? [tray.anchor.rect.x, tray.anchor.rect.y, tray.width, tray.height] : null
            });
        }
    }

    TestCase {
        id: input
        name: "LeftMotionInput"
        when: false
    }

    IpcHandler {
        target: "motion-test"

        function trayGrid(): void {
            root.tray().menuItem = null;
        }

        function state(): string {
            const clock = root.clock();
            const tray = root.tray();
            const names = ["verticalTrayButton", "verticalAudioControl", "verticalDeviceStatusButton", "verticalMediaWidget",
                "verticalClockDroplet", "verticalMainPill", "trayFlyoutBack", "trayFlyoutMenu",
                "deviceStatusSelector", "audioStatusSelector"];
            const items = {};
            for (const name of names) {
                const item = root.find(root.panel()?.contentItem ?? null, name)
                    ?? root.find(tray?.contentItem ?? null, name);
                items[name] = item ? { geometry: root.rect(item), visible: item.visible,
                    opacity: root.effectiveOpacity(item) } : null;
            }
            const trayItems = [];
            for (const entry of SystemTray.items.values) {
                const item = root.find(tray?.contentItem ?? null, "trayFlyoutItem_" + entry.id);
                trayItems.push({ id: entry.id, geometry: item ? root.rect(item) : null });
            }
            return JSON.stringify({
                dashOpen: clock?.menuOpen ?? false,
                mode: clock?.controlMode ?? "",
                section: clock?.dashboardSection ?? "",
                trayOpen: tray?.isOpen ?? false,
                trayMenu: tray?.menuItem?.id ?? "",
                trayCount: SystemTray.items.values.length,
                trayItems: trayItems,
                dash: root.sample(root.dashSurface()),
                tray: root.sample(root.traySurface()),
                time: root.sample(root.timeSurface()),
                timeOpen: clock?.timeToolsOpen ?? false,
                screen: root.screenSize(),
                items: items
            });
        }

        function startTrace(): void {
            root.surfaces = {
                clock: root.clock(), tray: root.tray(), dash: root.dashSurface(),
                traySurface: root.traySurface(), time: root.timeSurface()
            };
            root.trace = [];
            root.tracing = true;
        }

        function stopTrace(): string {
            root.tracing = false;
            try {
                return JSON.stringify(root.trace);
            } catch (error) {
                return JSON.stringify({ error: String(error) });
            }
        }

        function click(name: string): void {
            const tray = root.tray();
            const item = root.find(root.panel()?.contentItem ?? null, name)
                ?? root.find(tray?.contentItem ?? null, name);
            input.mouseClick(item);
        }

        function rightClick(name: string): void {
            const item = root.find(root.tray()?.contentItem ?? null, name)
                ?? root.find(root.panel()?.contentItem ?? null, name);
            input.mouseClick(item, item.width / 2, item.height / 2, Qt.RightButton);
        }

        function clickAt(x: real, y: real): void {
            input.mouseClick(root.panel().contentItem, x, y);
        }

        function freeze(key: string, at: real): void {
            root.freezeAt = at;
            root.freezeKey = key;
        }

        function resume(key: string): void {
            root.freezeKey = "";
            for (const animation of root.revealAnimations(root.surfaceFor(key)))
                animation.paused = false;
        }

        function controlMenu(mode: string): void {
            root.clock()?.openControlMenu(mode);
        }

        function deviceTab(mode: string): void {
            root.clock()?.showControlMenu(mode);
        }
    }
}
'''

# Real StatusNotifierItems with DBusMenus on the private bus. Each process
# registers the item ids given on its command line.
TRAY_ITEMS = r'''
import dbus, dbus.service, os, sys
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
LABELS = ["Open test app", "Preferences", "Check for updates", "Quit test app"]


class Menu(dbus.service.Object):
    def layout(self, identifier):
        props = dbus.Dictionary({"enabled": True, "visible": True}, signature="sv")
        children = []
        if identifier == 0:
            children = [self.layout(i + 1) for i in range(len(LABELS))]
        else:
            props["label"] = LABELS[identifier - 1]
        return dbus.Struct((dbus.Int32(identifier), props,
            dbus.Array([dbus.Struct(c, variant_level=1) for c in children], signature="v")))

    @dbus.service.method("com.canonical.dbusmenu", in_signature="iias", out_signature="u(ia{sv}av)")
    def GetLayout(self, parent, depth, names):
        return dbus.UInt32(1), self.layout(parent)

    @dbus.service.method("com.canonical.dbusmenu", in_signature="aias", out_signature="a(ia{sv})")
    def GetGroupProperties(self, ids, names):
        return dbus.Array([dbus.Struct((dbus.Int32(i), self.layout(i)[1])) for i in ids], signature="(ia{sv})")

    @dbus.service.method("com.canonical.dbusmenu", in_signature="i", out_signature="b")
    def AboutToShow(self, identifier):
        return False

    @dbus.service.method("com.canonical.dbusmenu", in_signature="ai", out_signature="aiai")
    def AboutToShowGroup(self, ids):
        return dbus.Array([], signature="i"), dbus.Array([], signature="i")

    @dbus.service.method("com.canonical.dbusmenu", in_signature="isvu")
    def Event(self, identifier, event, data, timestamp):
        pass

    @dbus.service.method("com.canonical.dbusmenu", in_signature="a(isvu)", out_signature="ai")
    def EventGroup(self, events):
        return dbus.Array([], signature="i")

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        return self.GetAll(interface)[prop]

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return dbus.Dictionary({"Version": dbus.UInt32(4), "TextDirection": "ltr", "Status": "normal",
            "IconThemePath": dbus.Array([], signature="s")}, signature="sv")


class Item(dbus.service.Object):
    def __init__(self, conn, identifier):
        super().__init__(conn, "/StatusNotifierItem")
        self.props = {"Category": "ApplicationStatus", "Id": identifier, "Title": "Tray " + identifier,
            "Status": "Active", "IconName": "folder", "ItemIsMenu": False, "WindowId": dbus.UInt32(0),
            "Menu": dbus.ObjectPath("/Menu")}

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        return self.props[prop]

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return dbus.Dictionary(self.props, signature="sv")

    @dbus.service.method("org.kde.StatusNotifierItem", in_signature="ii")
    def Activate(self, x, y):
        pass

    @dbus.service.method("org.kde.StatusNotifierItem", in_signature="ii")
    def ContextMenu(self, x, y):
        pass


names = []
for index, identifier in enumerate(sys.argv[1:]):
    name = f"org.kde.StatusNotifierItem-{os.getpid()}-{index}"
    conn = dbus.service.BusName(name, bus)
    item_bus = dbus.bus.BusConnection(os.environ["DBUS_SESSION_BUS_ADDRESS"])
    item = Item(item_bus, identifier)
    Menu(item_bus, "/Menu")
    names.append(item_bus)


def register():
    try:
        watcher = bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher")
        for item_bus in names:
            item_bus.call_blocking("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
                "org.kde.StatusNotifierWatcher", "RegisterStatusNotifierItem", "s", ["/StatusNotifierItem"])
        return False
    except dbus.DBusException:
        return True


GLib.timeout_add(200, register)
GLib.MainLoop().run()
'''


# Files this test covers. LEFT_MOTION_BASELINE=<git ref> runs them from that
# revision instead, to record the traces the fix is compared against.
MOTION_FILES = ("modules/components/MorphSurface.qml", "modules/components/FloatingSurface.qml",
                "modules/components/BarPopup.qml", "modules/bar/systray/TrayFlyout.qml",
                "modules/bar/clock/Clock.qml", "modules/widgets/dashboard/VerticalControlMenu.qml")


# A playing MPRIS player, so the dock shows its media pill and the media
# menu centres on it. Lyrics are off in the private config: no network.
PLAYER = r'''
import dbus, dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
ROOT_IFACE, PLAYER_IFACE = "org.mpris.MediaPlayer2", "org.mpris.MediaPlayer2.Player"
PROPS = {
    ROOT_IFACE: {"Identity": "Motion test", "CanQuit": False, "CanRaise": False, "HasTrackList": False,
                 "SupportedUriSchemes": dbus.Array([], signature="s"),
                 "SupportedMimeTypes": dbus.Array([], signature="s")},
    PLAYER_IFACE: {"PlaybackStatus": "Playing", "LoopStatus": "None", "Rate": dbus.Double(1),
                   "Shuffle": False, "Volume": dbus.Double(1), "Position": dbus.Int64(30_000_000),
                   "MinimumRate": dbus.Double(1), "MaximumRate": dbus.Double(1),
                   "CanGoNext": True, "CanGoPrevious": True, "CanPlay": True, "CanPause": True,
                   "CanSeek": True, "CanControl": True,
                   "Metadata": dbus.Dictionary({
                       "mpris:trackid": dbus.ObjectPath("/org/mpris/MediaPlayer2/Track/1"),
                       "mpris:length": dbus.Int64(240_000_000),
                       "xesam:title": "Motion Test Track",
                       "xesam:artist": dbus.Array(["Fixture"], signature="s"),
                       "xesam:album": "Private Bus"}, signature="sv")},
}


class Player(dbus.service.Object):
    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        return PROPS[interface][prop]

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return dbus.Dictionary(PROPS.get(interface, {}), signature="sv")

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="ssv")
    def Set(self, interface, prop, value):
        pass

    @dbus.service.method(PLAYER_IFACE)
    def Play(self):
        pass

    @dbus.service.method(PLAYER_IFACE)
    def Pause(self):
        pass

    @dbus.service.method(PLAYER_IFACE)
    def PlayPause(self):
        pass


name = dbus.service.BusName("org.mpris.MediaPlayer2.motiontest", bus)
Player(bus, "/org/mpris/MediaPlayer2")
GLib.MainLoop().run()
'''


def private_shell(fixture):
    shell = fixture / "shell"
    shell.mkdir()
    baseline = os.environ.get("LEFT_MOTION_BASELINE")
    for source in ROOT.iterdir():
        if source.name in ("shell.qml", ".git", "tests") or (baseline and source.name == "modules"):
            continue
        (shell / source.name).symlink_to(source, target_is_directory=source.is_dir())
    if baseline:
        shutil.copytree(ROOT / "modules", shell / "modules")
        for name in MOTION_FILES:
            text = subprocess.run(["git", "-C", str(ROOT), "show", f"{baseline}:{name}"],
                                  capture_output=True, text=True, check=True).stdout
            # Probe names only; no behaviour change.
            text = text.replace("            id: dashboardSurface\n",
                                '            id: dashboardSurface\n            objectName: "dashboardSurface"\n', 1)
            text = text.replace("        id: timePopup\n",
                                '        id: timePopup\n        objectName: "clockTimePopup"\n', 1)
            text = text.replace("        id: surface\n",
                                '        id: surface\n        objectName: root.objectName ? root.objectName + "Surface" : ""\n', 1)
            (shell / name).write_text(text)
    shell_text = (ROOT / "shell.qml").read_text()
    final_brace = shell_text.rfind("}")
    (shell / "shell.qml").write_text(shell_text[:final_brace] + "    MotionTestControl {}\n" + shell_text[final_brace:])
    (shell / "MotionTestControl.qml").write_text(CONTROL)
    return shell


def exercise(fixture, artifacts, mode):
    session = Session(fixture, shutil.which("qs"))
    bin_dir = fixture / "bin"
    bin_dir.mkdir()
    for tool in ("systemctl", "loginctl"):
        stub = bin_dir / tool
        stub.write_text(f'#!/bin/sh\necho "{tool} $*" >> "{fixture}/blocked-commands.log"\n')
        stub.chmod(0o755)
    session.env["PATH"] = f"{bin_dir}:{session.env['PATH']}"
    results = {"mode": mode, "traces": {}, "checks": []}
    trays = []
    try:
        start_compositor(session, "niri")
        session.env["NONCHALANT_COMPOSITOR"] = "niri"
        config = Path(session.env["XDG_CONFIG_HOME"]) / "nonchalant/config"
        config.mkdir(parents=True, exist_ok=True)
        (config / "bar.json").write_text(json.dumps({"style": "left", "lyricsEnabled": False}))
        (config / "ai.json").write_text(json.dumps({"enabled": False}))
        colors = Path(session.env["HOME"]) / ".cache/nonchalant"
        colors.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "assets/colors/Catppuccin/dark.json", colors / "colors.json")
        (fixture / "tray_items.py").write_text(TRAY_ITEMS)
        (fixture / "player.py").write_text(PLAYER)
        session.start("player", [sys.executable, "-I", str(fixture / "player.py")])
        trays.append(session.start("tray-a", [sys.executable, "-I", str(fixture / "tray_items.py"), "alpha", "beta"]))
        if mode == "timing":
            # Scene graph render and shader/pipeline compilation timings.
            session.env["QT_LOGGING_RULES"] = "qt.scenegraph.time.renderloop=true"
        shell = session.start("shell", [session.quickshell, "-p", str(private_shell(fixture)), "--no-color"])

        def ipc(method, *args):
            try:
                return session.ipc(shell, "motion-test", method, *args)
            except subprocess.TimeoutExpired as error:
                # A loaded software renderer can stall one IPC round trip.
                raise RuntimeError(f"IPC {method} timed out") from error

        def state():
            return json.loads(ipc("state"))

        session.wait("shell IPC", lambda: state()["items"]["verticalMainPill"] is not None, timeout=30)
        session.wait("tray items", lambda: state()["trayCount"] == 2, timeout=15)
        session.wait("media pill", lambda: (state()["items"]["verticalMediaWidget"] or {}).get("visible"), timeout=15)
        time.sleep(1.5)
        rest_shot = artifacts / f"left-motion-{mode}-rest.png"
        session.run(["grim", str(rest_shot)])
        results["base"] = state()

        if mode == "pixels":
            failures = pixel_pass(session, ipc, state, artifacts, rest_shot, results)
        elif mode == "timing":
            failures = timing_pass(session, ipc, state, fixture, results)
        else:
            def add_items():
                trays.append(session.start("tray-b", [sys.executable, "-I", str(fixture / "tray_items.py"),
                                                      "gamma", "delta", "epsilon"]))

            def remove_items():
                tray = trays.pop()
                os.killpg(tray.pid, 15)
                tray.wait(timeout=5)

            for name, action, expected in scenarios(add_items, remove_items):
                ipc("startTrace")
                action(ipc)
                session.wait(f"{name} settles", lambda: settled(state(), expected), timeout=20)
                time.sleep(0.5)
                results["traces"][name] = json.loads(ipc("stopTrace"))
            failures = analyse(results)
        for check in results["checks"]:
            print("PASS:", check)
        for failure in failures:
            print("FAIL:", failure)
        log = (fixture / "shell.log").read_text()
        for line in log.splitlines():
            if any(name in line for name in ("MorphSurface", "BarPopup", "FloatingSurface", "TrayFlyout",
                                             "Clock.qml", "VerticalControlMenu", "MotionTestControl")):
                if "rror" in line or "is not a type" in line or "Binding loop" in line:
                    failures.append(f"QML diagnostic: {line}")
        assert not (fixture / "blocked-commands.log").exists()
        if failures:
            print("LEFT_MOTION_FAILED")
            return 1
        print("LEFT_MOTION_PASSED")
        return 0
    except Exception as error:
        print("LEFT_MOTION_FAILED", repr(error))
        try:
            print(json.dumps(state(), indent=1)[:3000])
        except Exception as state_error:
            print("no state", state_error)
        shell_log = fixture / "shell.log"
        if shell_log.exists():
            print(shell_log.read_text()[-4000:])
        return 1
    finally:
        (artifacts / f"traces-{mode}.json").write_text(json.dumps(results))
        shell_log = fixture / "shell.log"
        if shell_log.exists():
            (artifacts / f"shell-{mode}.log").write_text(shell_log.read_text())
        session.stop()


# Fastest legitimate content fade: OutQuad out over the shared fade-out
# duration starts at about 0.019 per ms.
SWAP_RATE = 0.025

SWITCHES = ("dashboard-to-stats", "stats-to-weather", "weather-to-notifications", "dashboard-to-wifi", "wifi-to-dashboard", "dashboard-back-to-wifi", "wifi-to-bluetooth", "bluetooth-to-dashboard", "dashboard-to-bluetooth", "bluetooth-to-battery", "battery-to-sound", "sound-to-mic",
            "mic-to-media", "media-to-dashboard", "tray-to-menu", "menu-to-tray", "tray-menu-reversal",
            "tray-grows", "tray-shrinks")
GAP = 8


def settled(state, expected):
    for key, value in expected.items():
        if state[key] != value:
            return False
    for key in ("dash", "tray", "time"):
        surface = state[key]
        if surface and surface["visible"] and surface["moving"]:
            return False
    return True


def scenarios(add_items, remove_items):
    def click(name):
        return lambda ipc: ipc("click", name)

    def control(mode):
        return lambda ipc: ipc("controlMenu", mode)

    def tab(mode):
        return lambda ipc: ipc("deviceTab", mode)

    def chain(*steps, pause=0.08):
        def run(ipc):
            for index, step in enumerate(steps):
                if index:
                    time.sleep(pause)
                step(ipc)
        return run

    def call(function):
        return lambda ipc: function()

    dash = {"dashOpen": True, "mode": ""}
    return [
        ("dashboard-open", click("verticalClockDroplet"), dash),
        ("dashboard-to-wifi", click("verticalDeviceStatusButton"), {"dashOpen": True, "mode": "wifi"}),
        ("wifi-to-dashboard", click("verticalClockDroplet"), dash),
        ("dashboard-back-to-wifi", click("verticalDeviceStatusButton"), {"dashOpen": True, "mode": "wifi"}),
        ("wifi-to-bluetooth", tab("bluetooth"), {"mode": "bluetooth"}),
        ("bluetooth-to-dashboard", click("verticalClockDroplet"), dash),
        ("dashboard-to-bluetooth", click("verticalDeviceStatusButton"), {"dashOpen": True, "mode": "bluetooth"}),
        ("dashboard-device-reversal", chain(click("verticalClockDroplet"), click("verticalDeviceStatusButton"),
                                             click("verticalClockDroplet")), dash),
        ("dashboard-to-bluetooth-again", click("verticalDeviceStatusButton"), {"dashOpen": True, "mode": "bluetooth"}),
        ("bluetooth-to-battery", tab("battery"), {"mode": "battery"}),
        ("battery-to-sound", control("sound"), {"mode": "sound"}),
        ("sound-to-mic", control("mic"), {"mode": "mic"}),
        ("mic-to-media", control("media"), {"mode": "media"}),
        ("media-to-dashboard", click("verticalClockDroplet"), dash),
        ("dashboard-to-stats", control("stats"), {"dashOpen": True, "section": "stats"}),
        ("stats-to-weather", control("weather"), {"dashOpen": True, "section": "weather"}),
        ("weather-to-notifications", control("weather"), {"dashOpen": True, "section": "notifications"}),
        ("dashboard-close", click("verticalClockDroplet"), {"dashOpen": False}),
        ("device-open", click("verticalDeviceStatusButton"), {"dashOpen": True, "mode": "battery"}),
        ("device-dashboard-reversal", chain(click("verticalClockDroplet"), click("verticalDeviceStatusButton")),
            {"dashOpen": True, "mode": "battery"}),
        ("device-to-tray", click("verticalTrayButton"), {"trayOpen": True, "dashOpen": False}),
        ("tray-to-menu", lambda ipc: ipc("rightClick", "trayFlyoutItem_alpha"), {"trayMenu": "alpha"}),
        ("menu-to-tray", click("trayFlyoutBack"), {"trayMenu": ""}),
        ("tray-menu-reversal", chain(lambda ipc: ipc("rightClick", "trayFlyoutItem_beta"),
            lambda ipc: ipc("trayGrid"), pause=0.06), {"trayMenu": ""}),
        ("tray-grows", call(add_items), {"trayCount": 5}),
        ("tray-shrinks", call(remove_items), {"trayCount": 2}),
        ("tray-to-dashboard", click("verticalClockDroplet"), {"trayOpen": False, "dashOpen": True, "mode": ""}),
        ("dashboard-close-reversal", chain(click("verticalClockDroplet"), click("verticalClockDroplet")), dash),
        ("dashboard-close-2", click("verticalClockDroplet"), {"dashOpen": False}),
        ("time-tools-open", lambda ipc: ipc("rightClick", "verticalClockDroplet"), {"timeOpen": True}),
        ("time-tools-to-dashboard", click("verticalClockDroplet"), {"timeOpen": False, "dashOpen": True}),
        ("dashboard-close-3", click("verticalClockDroplet"), {"dashOpen": False}),
    ]


# Steepest slope of the shared curves (OutBack open, InCubic close, OutCubic
# fades) is about 0.0125 per ms at the default animation duration. A step
# faster than that for the time that actually passed is a snap; a loaded
# software renderer only stretches the time between samples.
MAX_RATE = 0.016
STEP_SLACK = 0.05


FRAME = 16


def continuous(values, times, rate=None):
    """No change faster than `rate` per ms, measured from each sample to the
    first one at least a frame later: ticks a few ms apart only show when
    each animation happened to read the clock."""
    rate = MAX_RATE if rate is None else rate
    for i, (value, stamp) in enumerate(zip(values, times)):
        later = next((j for j in range(i + 1, len(times)) if times[j] - stamp >= FRAME), None)
        if later is not None and abs(values[later] - value) > rate * (times[later] - stamp) + STEP_SLACK:
            return False
    return True


def sprang(reveals, times):
    """Opening overshoots its rest. A stalled frame before the reveal settles
    can carry the animation clock past the overshoot unsampled; then only
    the settle is observable."""
    if max(reveals) > 1:
        return True
    settle = next((i for i, value in enumerate(reveals) if value == 1), None)
    return settle is not None and settle > 0 and max(b - a for a, b in zip(times[:settle + 1], times[1:settle + 1])) > 100


def identity(frame, key):
    """What the surface shows, and how opaque that content is on screen."""
    surface = frame[key]
    if key == "dash":
        kind = surface.get("presented")
        if kind is None:
            kind = "control" if frame["mode"] else "dashboard"
        mode = surface.get("shownMode") or (frame["mode"] if surface.get("presented") is None else "")
        if kind == "control" and surface.get("panelOpacity", -1) >= 0:
            return f"{kind}:{mode}", surface["panelOpacity"]
        return f"{kind}:{mode}" if kind == "control" else kind, surface["pageOpacity"]
    kind = surface.get("presented")
    return (kind if kind is not None else (("menu:" + frame["trayMenu"]) if frame["trayMenu"] else "grid"),
            surface["pageOpacity"])


def edges(surface):
    x, y, width, height = surface["body"]
    return x, y, x + width, y + height


def analyse(results):
    failures = []
    screen_height = results["base"]["screen"][1]
    clock = results["base"]["items"]["verticalClockDroplet"]["geometry"]
    # The dashboard grows out of the clock pill, which sits closer to the edge.
    lowest = max(screen_height - GAP, clock[1] + clock[3])
    pill = results["base"]["items"]["verticalMainPill"]["geometry"]
    dock_edge = pill[0] + pill[2]
    traces = results["traces"]

    def check(condition, message):
        if not condition:
            failures.append(message)
        return condition

    group = [0]

    def passed(label):
        # Report a group only when none of its checks failed.
        if len(failures) == group[0]:
            results["checks"].append(label)
        group[0] = len(failures)

    # Per-frame invariants on every surface, in every scenario.
    counts = {"frames": 0, "moving": 0}
    for name, frames in traces.items():
        for key in ("dash", "tray", "time"):
            previous = None
            previous_time = 0
            for frame in frames:
                surface = frame[key]
                if not surface or not surface["visible"]:
                    previous = None
                    continue
                counts["frames"] += 1
                left, top, right, bottom = edges(surface)
                visible_content = surface["pageOpacity"] > 0
                if surface["moving"]:
                    counts["moving"] += 1
                    check(surface["masked"] or not visible_content,
                          f"{name}/{key}: content clipped by square bounds while morphing {surface['body']}")
                if surface["pane"]:
                    check(abs(surface["paneRadius"] - max(0, surface["radius"] - surface["paneInset"])) < 0.01,
                          f"{name}/{key}: inner pane radius {surface['paneRadius']} not concentric with {surface['radius']}")
                check(abs(surface["chromeRadius"] - surface["radius"]) < 0.01,
                      f"{name}/{key}: chrome radius differs from the clip radius")
                check(top >= GAP - 0.5 and bottom <= (lowest if surface["reveal"] < 1 else screen_height - GAP) + 0.5,
                      f"{name}/{key}: body leaves the screen gap {surface['body']}")
                if not surface["moving"] and surface["reveal"] == 1:
                    check(abs(left - (dock_edge + GAP)) < 0.5, f"{name}/{key}: resting gap from dock is {left - dock_edge}")
                # Content, and the frozen copy of outgoing content, stay at
                # their resting positions while the frame moves over them.
                if name in SWITCHES and previous and previous["reveal"] == 1 and surface["reveal"] == 1:
                    same_content = previous["content"] == surface["content"] and previous["restY"] == surface["restY"]
                    if same_content and previous["page"] and surface["page"]:
                        check(all(abs(a - b) < 0.5 for a, b in zip(previous["page"], surface["page"])),
                              f"{name}/{key}: content lost its anchor {previous['page']} -> {surface['page']}")
                    if previous.get("outgoing") and surface.get("outgoing") and not surface["handoffPending"]:
                        check(all(abs(a - b) < 0.5 for a, b in zip(previous["outgoing"], surface["outgoing"])),
                              f"{name}/{key}: outgoing copy moved {previous['outgoing']} -> {surface['outgoing']}")
                previous = surface
                previous_time = frame["t"]
        for key in ("dash", "tray", "time"):
            reveals = [frame[key]["reveal"] for frame in frames if frame[key] and frame[key]["visible"]]
            stamps = [frame["t"] for frame in frames if frame[key] and frame[key]["visible"]]
            check(continuous(reveals, stamps), f"{name}/{key}: reveal jumped {[round(r, 2) for r in reveals]}")
    check(counts["moving"] > 50, f"too few moving frames sampled: {counts}")
    passed(f"{counts['frames']} visible frames ({counts['moving']} moving): rounded mask on every "
                             "moving frame, concentric pane, 8 px screen gaps, 8 px dock gap at rest, stable "
                             "content anchors during switches, continuous reveal")

    def visible(frames, key):
        return [frame[key] for frame in frames if frame[key] and frame[key]["visible"]]

    def times(frames, key):
        return [frame["t"] for frame in frames if frame[key] and frame[key]["visible"]]

    # Opening springs past its rest; closing never swells.
    for name in ("dashboard-open", "device-open"):
        reveals = [s["reveal"] for s in visible(traces[name], "dash")]
        check(sprang(reveals, times(traces[name], "dash")) and any(0 < r < 1 for r in reveals),
              f"{name}: no spring {reveals}")
    for name in ("dashboard-close", "dashboard-close-2"):
        reveals = [s["reveal"] for s in visible(traces[name], "dash")]
        check(max(reveals) <= 1 and all(b <= a for a, b in zip(reveals, reveals[1:])),
              f"{name}: close is not monotonic {reveals}")
    passed("open springs past rest, close is monotonic")

    # Dashboard <-> control menu fade through: the outgoing content stays
    # where it rested and clears before the incoming content rises, so two
    # layouts never overlap, and the gap between them stays brief.
    handoffs = ("dashboard-to-wifi", "wifi-to-dashboard", "dashboard-back-to-wifi", "bluetooth-to-dashboard",
                "dashboard-to-bluetooth", "dashboard-to-bluetooth-again", "media-to-dashboard")
    for name in handoffs + ("dashboard-device-reversal",):
        frames = [f for f in traces[name] if f["dash"] and f["dash"]["visible"] and f["dash"]["reveal"] == 1]
        check(len(frames) > 3, f"{name}: too few frames")
        blank = []
        for frame in frames:
            surface = frame["dash"]
            if surface["handoffPending"]:
                continue
            check(surface["presented"] == ("control" if frame["mode"] else "dashboard"),
                  f"{name}: presented content lags the requested mode at {frame['t']} ms")
            if name in handoffs:
                check(min(surface["pageOpacity"], surface["outgoingOpacity"]) < 0.2,
                      f"{name}: outgoing and incoming content overlap at {frame['t']} ms: "
                      f"{surface['outgoingOpacity']:.2f} / {surface['pageOpacity']:.2f}")
                if surface["pageOpacity"] + surface["outgoingOpacity"] < 0.1:
                    blank.append(frame["t"])
        if name in handoffs:
            swapped = [f["dash"] for f in frames if not f["dash"]["handoffPending"] and f["dash"]["outgoing"]]
            outs = [s["outgoingOpacity"] for s in swapped]
            ins = [s["pageOpacity"] for s in swapped]
            check(len(swapped) > 2 and all(b <= a + 1e-3 for a, b in zip(outs, outs[1:])),
                  f"{name}: outgoing fade not monotonic {outs}")
            check(all(b >= a - 1e-3 for a, b in zip(ins, ins[1:])), f"{name}: incoming fade not monotonic {ins}")
            gap = blank[-1] - blank[0] if blank else 0
            check(gap <= 120, f"{name}: content blank for {gap} ms")
            check(frames[-1]["dash"]["pageOpacity"] > 0.99 and not frames[-1]["dash"]["outgoing"],
                  f"{name}: fade-through did not settle")
    # Device and audio tabs swap their panel in place, without a fade.
    for name in ("wifi-to-bluetooth", "bluetooth-to-battery", "battery-to-sound", "sound-to-mic"):
        frames = [f for f in traces[name] if f["dash"] and f["dash"]["visible"] and f["dash"]["reveal"] == 1]
        check(len(frames) > 3, f"{name}: too few frames")
        for frame in frames:
            surface = frame["dash"]
            check(surface["pageOpacity"] > 0.99 and surface["panelOpacity"] > 0.99,
                  f"{name}: control panel faded out at {frame['t']} ms: {surface['pageOpacity']} {surface['panelOpacity']}")
    passed("dashboard <-> menu switches fade through anchored content without overlap or a long blank; "
           "device/audio tabs swap in place")

    # The tray retains its outgoing/incoming fade during menu navigation.
    swaps = 0
    for name in SWITCHES:
        for key in ("tray",):
            rows = [(frame["t"],) + identity(frame, key) for frame in traces[name]
                    if frame[key] and frame[key]["visible"] and frame[key]["reveal"] == 1]
            check(continuous([row[2] for row in rows], [row[0] for row in rows], SWAP_RATE),
                  f"{name}/{key}: content opacity jumped {[round(row[2], 2) for row in rows]}")
            for (t0, before, out), (t1, after, into) in zip(rows, rows[1:]):
                if before != after:
                    swaps += 1
                    # Both fades fit between the two samples: the old content
                    # had to leave and the new one had to rise from zero.
                    check(out + into <= SWAP_RATE * (t1 - t0) + STEP_SLACK,
                          f"{name}/{key}: {before} -> {after} swapped at opacity {out:.2f} -> {into:.2f} "
                          f"in {t1 - t0} ms")
    check(swaps >= 2, f"too few tray content swaps observed: {swaps}")
    passed(f"{swaps} tray swaps: outgoing content fades out fully before the incoming content fades in")

    # Switching menus while open keeps the bottom edge on the screen gap.
    for name in ("dashboard-to-wifi", "wifi-to-dashboard", "dashboard-back-to-wifi", "wifi-to-bluetooth", "bluetooth-to-dashboard", "dashboard-to-bluetooth", "bluetooth-to-battery", "battery-to-sound",
                 "sound-to-mic", "dashboard-to-stats", "stats-to-weather", "weather-to-notifications"):
        surfaces = [s for s in visible(traces[name], "dash") if s["reveal"] == 1]
        bottoms = {round(edges(s)[3], 1) for s in surfaces}
        check(len(surfaces) > 3 and all(abs(b - (screen_height - GAP)) < 1 for b in bottoms),
              f"{name}: bottom edge left the gap {sorted(bottoms)}")
        resized = surfaces[0]["content"] != surfaces[-1]["content"]
        if resized:
            stamps = [frame["t"] for frame in traces[name] if frame["dash"] and frame["dash"]["visible"]
                      and frame["dash"]["reveal"] == 1]
            axis = max((0, 1), key=lambda i: abs(surfaces[-1]["rest"][i] - surfaces[0]["rest"][i]))
            progress = [(s["rest"][axis] - surfaces[0]["rest"][axis])
                        / (surfaces[-1]["rest"][axis] - surfaces[0]["rest"][axis]) for s in surfaces]
            check(any(0 < v < 1 for v in progress) and continuous(progress, stamps),
                  f"{name}: body snapped to the new size {progress}")
            tops = [edges(s)[1] for s in surfaces]
            direction = [b - a for a, b in zip(tops, tops[1:]) if abs(b - a) > 0.01]
            check(all(d > 0 for d in direction) or all(d < 0 for d in direction),
                  f"{name}: top edge moved backwards {tops}")
    passed("dashboard sections and dashboard <-> Wi-Fi/Bluetooth/battery/sound/mic switches keep the bottom edge "
                             "fixed on the gap and move the top edge monotonically")

    # The media menu centres on the media pill and glides there and back.
    media = results["base"]["items"]["verticalMediaWidget"]["geometry"]
    media_centre = media[1] + media[3] / 2
    for name, settle in (("mic-to-media", "media"), ("media-to-dashboard", "gap")):
        surfaces = [s for s in visible(traces[name], "dash") if s["reveal"] == 1]
        rest = surfaces[-1]
        height = edges(rest)[3] - edges(rest)[1]
        if settle == "media":
            expected = max(GAP, min(screen_height - GAP - height, media_centre - height / 2))
            check(abs(edges(rest)[1] - expected) < 1, f"{name}: media menu not centred on the pill "
                  f"({media_centre}): {rest['body']}")
        else:
            check(abs(edges(rest)[3] - (screen_height - GAP)) < 1, f"{name}: dashboard not back on the gap {rest['body']}")
        for index, label in ((1, "top"), (3, "bottom")):
            values = [edges(s)[index] for s in surfaces]
            steps = [b - a for a, b in zip(values, values[1:]) if abs(b - a) > 0.01]
            check(steps and (all(d > 0 for d in steps) or all(d < 0 for d in steps)),
                  f"{name}: {label} edge did not glide monotonically {values}")
    passed("media menu glides to centre on the media pill and back to the bottom gap with monotonic edges")

    # Chrome fades between the frameless dashboard and framed menus.
    chrome_in = [s["chrome"] for s in visible(traces["dashboard-to-wifi"], "dash")]
    chrome_out = [s["chrome"] for s in visible(traces["media-to-dashboard"], "dash")]
    check(chrome_in[0] == 0 and chrome_in[-1] == 1 and any(0 < c < 1 for c in chrome_in)
          and continuous(chrome_in, times(traces["dashboard-to-wifi"], "dash"))
          and all(b >= a for a, b in zip(chrome_in, chrome_in[1:])), f"chrome fade in {chrome_in}")
    check(chrome_out[0] == 1 and chrome_out[-1] == 0 and any(0 < c < 1 for c in chrome_out)
          and continuous(chrome_out, times(traces["media-to-dashboard"], "dash"))
          and all(b <= a for a, b in zip(chrome_out, chrome_out[1:])), f"chrome fade out {chrome_out}")
    passed("frame chrome fades in and out monotonically across dashboard <-> menu switches")

    # Tray grid <-> app menu and live item changes stay centred on the trigger.
    button = results["base"]["items"]["verticalTrayButton"]["geometry"]
    centre = button[1] + button[3] / 2
    for name in ("tray-to-menu", "menu-to-tray", "tray-menu-reversal", "tray-grows", "tray-shrinks"):
        surfaces = [s for s in visible(traces[name], "tray") if s["reveal"] == 1]
        centres = {round((edges(s)[1] + edges(s)[3]) / 2, 1) for s in surfaces}
        check(len(surfaces) > 3 and all(abs(c - centre) < 1 for c in centres),
              f"{name}: tray body left its trigger's centre {centre}: {sorted(centres)}")
        if name == "tray-menu-reversal":
            check(surfaces[-1]["presented"] == "grid", "Cancelled tray navigation must return to the grid")
        else:
            check(any(s["rest"] != s["content"] for s in surfaces), f"{name}: tray body did not morph")
    passed("tray grid -> app menu -> back, fast reversal and async item growth/shrink morph "
                             "around the trigger's centre without moving the window")
    windows = {tuple(frame["trayWindow"]) for name in ("tray-to-menu", "menu-to-tray", "tray-menu-reversal")
               for frame in traces[name] if frame["trayWindow"]}
    check(len(windows) == 1, f"tray window moved or resized during navigation: {windows}")
    passed("tray popup window keeps one geometry through grid/menu navigation")

    # The clock's time tools open beside the clock, inside the screen gap.
    surfaces = [s for s in visible(traces["time-tools-open"], "time")]
    reveals = [s["reveal"] for s in surfaces]
    # Its spring is the shared surface's, asserted on the dashboard above.
    check(surfaces and reveals[-1] == 1 and abs(edges(surfaces[-1])[0] - (dock_edge + GAP)) < 0.5,
          f"time tools did not open beside the dock: {reveals[-3:]} {surfaces[-1]['body'] if surfaces else None}")
    rest = surfaces[-1] if surfaces else None
    if rest:
        centre = clock[1] + clock[3] / 2
        expected = min(screen_height - GAP - rest["content"][1], centre - rest["content"][1] / 2)
        check(abs(edges(rest)[1] - max(GAP, expected)) < 1, f"time tools not centred/clamped on the clock: {rest['body']}")
    passed("clock time tools open beside the dock, centred on the clock and clamped to the screen gap")
    return failures


def timing_pass(session, ipc, state, fixture, results):
    """First and second opens of each dock surface: animation tick gaps and
    the scene graph log lines emitted while each one ran."""
    log = fixture / "shell.log"
    for cycle in (1, 2):
        for name, trigger, key in (("dashboard", "verticalClockDroplet", "dash"),
                                   ("device", "verticalDeviceStatusButton", "dash"),
                                   ("tray", "verticalTrayButton", "tray")):
            for phase in ("open", "close"):
                offset = log.stat().st_size
                ipc("startTrace")
                ipc("click", trigger)
                # No polling while it animates: the probe's tree walk would
                # stall the GUI thread it measures.
                time.sleep(2.0)
                frames = json.loads(ipc("stopTrace"))
                now = state()[key] or {}
                if now.get("visible", False) != (phase == "open") or now.get("moving", False):
                    raise RuntimeError(f"{name} did not settle after {phase}: {now}")
                stamps = [frame["t"] for frame in frames if frame[key] and frame[key]["visible"]]
                gaps = [b - a for a, b in zip(stamps, stamps[1:])]
                with log.open() as handle:
                    handle.seek(offset)
                    renders = [int(line.split("frame rendered in ")[1].split("ms")[0]) for line in handle
                               if "frame rendered in " in line]
                entry = {"max_gap": max(gaps, default=0), "gaps": gaps, "renders": renders}
                results["traces"][f"{name}-{phase}-{cycle}"] = entry
                print(f"TIMING {name} {phase} #{cycle}: render max {max(renders, default=0)} ms "
                      f"median {sorted(renders)[len(renders) // 2] if renders else 0} ms over {len(renders)} frames; "
                      f"tick gap max {entry['max_gap']} ms")
    return []


def corner_pixels(path, rect, rest):
    """Pixels just inside each corner of the body that differ from the empty screen."""
    from PIL import Image
    x, y, width, height = rect
    inset = 2
    points = [(x + inset, y + inset), (x + width - 1 - inset, y + inset),
              (x + inset, y + height - 1 - inset), (x + width - 1 - inset, y + height - 1 - inset)]
    with Image.open(path) as image, Image.open(rest) as empty:
        shot, base = image.convert("RGB"), empty.convert("RGB")
        return [point for point in points
                if max(abs(a - b) for a, b in zip(shot.getpixel(point), base.getpixel(point))) > 24]


def pixel_pass(session, ipc, state, artifacts, rest_shot, results):
    """Real composited frames frozen mid-morph: nothing but the empty screen
    shows just inside the body's rounded corners."""
    failures = []
    checked = []
    for name, trigger, key in (("dashboard", "verticalClockDroplet", "dash"),
                               ("device", "verticalDeviceStatusButton", "dash"),
                               ("tray", "verticalTrayButton", "tray")):
        frames = 0
        for at in (0.5, 0.7, 0.85):
            ipc("freeze", key, at)
            ipc("click", trigger)
            session.wait(f"{name} freezes at {at}", lambda: (state()[key] or {}).get("reveal", 0) >= at)
            frozen = state()[key]
            # The content keeps fading in while the body holds still.
            time.sleep(1.0)
            surface = state()[key]
            path = artifacts / f"left-motion-pixels-{name}-{at}.png"
            session.run(["grim", str(path)])
            after = state()[key]
            if frozen["reveal"] >= 1:
                pass  # A slow frame carried the spring past the threshold; try the next one.
            elif after["body"] != frozen["body"]:
                failures.append(f"{name} at {at}: surface did not hold still {frozen['body']} -> {after['body']}")
            elif surface["pageOpacity"] < 0.5:
                failures.append(f"{name} at {at}: content not visible ({surface['pageOpacity']:.2f})")
            else:
                corners = corner_pixels(path, [round(v) for v in after["body"]], rest_shot)
                checked.append(f"{name}@{after['reveal']:.2f}")
                frames += 1
                if corners:
                    failures.append(f"{name} frozen at reveal {after['reveal']:.2f}: content painted in rounded "
                                    f"corners at {corners}, body {after['body']}")
            ipc("resume", key)
            session.wait(f"{name} opens", lambda: not (state()[key] or {}).get("moving", True), timeout=10)
            ipc("click", trigger)
            session.wait(f"{name} closes", lambda: not (state()[key] or {}).get("visible", False), timeout=10)
            time.sleep(0.3)
        if frames < 2:
            failures.append(f"{name}: only {frames} frames frozen mid-morph")
    if not failures:
        results["checks"].append(f"{len(checked)} composited frames frozen mid-morph keep all four rounded corners "
                                 "clear with content at full opacity: " + ", ".join(checked))
    return failures


def run_mode(test, mode, timeout):
    artifacts = Path(os.environ.get("LEFT_MOTION_ARTIFACTS") or tempfile.mkdtemp(prefix="nonchalant-left-motion-shots-"))
    artifacts.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="nonchalant-left-motion-") as directory:
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
                sys.executable, __file__, "--exercise", mode, str(fixture), str(artifacts)],
                env=env, capture_output=True, text=True, timeout=timeout)
            (artifacts / f"exercise-{mode}.log").write_text(result.stdout + result.stderr)
            test.assertEqual(result.returncode, 0, f"see {artifacts / f'exercise-{mode}.log'}\n" + result.stdout[-3000:])
            print(result.stdout[-3000:])
        finally:
            shutil.rmtree(env["XDG_RUNTIME_DIR"])


@unittest.skipUnless(all(shutil.which(tool) for tool in ("qs", "weston", "niri", "dbus-run-session", "grim")),
                     "Quickshell, Weston, Niri, D-Bus and grim are required")
class LeftMotionRuntimeTests(unittest.TestCase):
    def test_frame_traces(self):
        run_mode(self, "trace", 300)

    def test_rounded_corners_in_composited_frames(self):
        run_mode(self, "pixels", 300)


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "--exercise":
        raise SystemExit(exercise(Path(sys.argv[3]), Path(sys.argv[4]), sys.argv[2]))
    unittest.main()
