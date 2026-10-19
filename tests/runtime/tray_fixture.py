"""Private StatusNotifierItem and DBusMenu services for tray integration checks."""

import asyncio
import json
import os
from pathlib import Path
import signal
import sys

from dbus_next import Message, MessageType, Variant
from dbus_next.aio import MessageBus
from dbus_next.constants import PropertyAccess
from dbus_next.service import ServiceInterface, dbus_property, method


class Menu(ServiceInterface):
    def __init__(self, owner):
        super().__init__("com.canonical.dbusmenu")
        self.owner = owner

    @dbus_property(access=PropertyAccess.READ)
    def Version(self) -> "u":
        return 4

    @dbus_property(access=PropertyAccess.READ)
    def TextDirection(self) -> "s":
        return "ltr"

    @dbus_property(access=PropertyAccess.READ)
    def Status(self) -> "s":
        return "normal"

    @dbus_property(access=PropertyAccess.READ)
    def IconThemePath(self) -> "as":
        return []

    def layout(self, identifier):
        properties = {"enabled": Variant("b", True), "visible": Variant("b", True)}
        children = []
        if identifier == 0:
            children = [self.layout(i) for i in (1, 2, 4)]
        elif identifier == 1:
            properties["label"] = Variant("s", "Open test app")
        elif identifier == 2:
            properties.update({"label": Variant("s", "More actions"),
                               "children-display": Variant("s", "submenu")})
            children = [self.layout(3)]
        elif identifier == 3:
            properties["label"] = Variant("s", "Nested action")
        elif identifier == 4:
            properties.update({"label": Variant("s", "Unavailable action"), "enabled": Variant("b", False)})
        return [identifier, properties, [Variant("(ia{sv}av)", child) for child in children]]

    @method()
    def GetLayout(self, parent: "i", depth: "i", names: "as") -> "u(ia{sv}av)":
        return [1, self.layout(parent)]

    @method()
    def GetGroupProperties(self, identifiers: "ai", names: "as") -> "a(ia{sv})":
        return [[identifier, self.layout(identifier)[1]] for identifier in identifiers]

    @method()
    def AboutToShow(self, identifier: "i") -> "b":
        return False

    @method()
    def AboutToShowGroup(self, identifiers: "ai") -> "aiai":
        return [[], []]

    @method()
    def Event(self, identifier: "i", event: "s", data: "v", timestamp: "u"):
        if event == "clicked":
            self.owner.events.append({"item": self.owner.identifier, "menu": identifier})

    @method()
    def EventGroup(self, events: "a(isvu)") -> "ai":
        for identifier, event, data, timestamp in events:
            self.Event(identifier, event, data, timestamp)
        return []


class TrayItem(ServiceInterface):
    def __init__(self, identifier, events, menu_only=False):
        super().__init__("org.kde.StatusNotifierItem")
        self.identifier = identifier
        self.events = events
        self.menu_only = menu_only

    @dbus_property(access=PropertyAccess.READ)
    def Category(self) -> "s":
        return "ApplicationStatus"

    @dbus_property(access=PropertyAccess.READ)
    def Id(self) -> "s":
        return self.identifier

    @dbus_property(access=PropertyAccess.READ)
    def Title(self) -> "s":
        return "Tray " + self.identifier

    @dbus_property(access=PropertyAccess.READ)
    def Status(self) -> "s":
        return "Active"

    @dbus_property(access=PropertyAccess.READ)
    def WindowId(self) -> "u":
        return 0

    @dbus_property(access=PropertyAccess.READ)
    def IconName(self) -> "s":
        return ""

    @dbus_property(access=PropertyAccess.READ)
    def IconPixmap(self) -> "a(iiay)":
        pixels = bytes(channel for y in range(16) for x in range(16)
                       for channel in ([255, 70, 140, 210] if abs(x - 7.5) + abs(y - 7.5) < 7
                                       else [0, 0, 0, 0]))
        return [[16, 16, pixels]]

    @dbus_property(access=PropertyAccess.READ)
    def AttentionIconName(self) -> "s":
        return ""

    @dbus_property(access=PropertyAccess.READ)
    def AttentionIconPixmap(self) -> "a(iiay)":
        return []

    @dbus_property(access=PropertyAccess.READ)
    def OverlayIconName(self) -> "s":
        return ""

    @dbus_property(access=PropertyAccess.READ)
    def OverlayIconPixmap(self) -> "a(iiay)":
        return []

    @dbus_property(access=PropertyAccess.READ)
    def ToolTip(self) -> "(sa(iiay)ss)":
        return ["", [], self.Title, "Private tray integration fixture"]

    @dbus_property(access=PropertyAccess.READ)
    def ItemIsMenu(self) -> "b":
        return self.menu_only

    @dbus_property(access=PropertyAccess.READ)
    def Menu(self) -> "o":
        return "/Menu"

    @method()
    def Activate(self, x: "i", y: "i"):
        self.events.append({"item": self.identifier, "activate": True})

    @method()
    def SecondaryActivate(self, x: "i", y: "i"):
        self.events.append({"item": self.identifier, "secondary": True})

    @method()
    def ContextMenu(self, x: "i", y: "i"):
        pass

    @method()
    def Scroll(self, delta: "i", direction: "s"):
        pass


class Control(ServiceInterface):
    def __init__(self):
        super().__init__("org.nonchalant.TrayFixture")
        self.items = []
        self.events = []

    @method()
    def State(self) -> "s":
        return json.dumps({"items": len(self.items), "events": self.events})

    @method()
    async def SetCount(self, count: "i"):
        await self.set_count(count)

    async def set_count(self, count):
        while len(self.items) > count:
            bus = self.items.pop()
            bus.disconnect()
        while len(self.items) < count:
            index = len(self.items)
            bus = await MessageBus().connect()
            item = TrayItem("test-" + str(index), self.events, menu_only=index == 1)
            bus.export("/StatusNotifierItem", item)
            bus.export("/Menu", Menu(item))
            self.items.append(bus)
            reply = await bus.call(Message(destination="org.kde.StatusNotifierWatcher",
                path="/StatusNotifierWatcher", interface="org.kde.StatusNotifierWatcher",
                member="RegisterStatusNotifierItem", signature="s", body=["/StatusNotifierItem"]))
            if reply.message_type == MessageType.ERROR:
                raise RuntimeError(reply.body)


async def main():
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS", "").startswith("unix:path=" + str(runtime / "bus")):
        raise RuntimeError("The tray fixture requires the test's private session bus")
    bus = await MessageBus().connect()
    if len(sys.argv) > 1:
        member = sys.argv[1]
        reply = await bus.call(Message(destination="org.nonchalant.TrayFixture",
            path="/TrayTest", interface="org.nonchalant.TrayFixture", member=member,
            signature="i" if member == "SetCount" else "",
            body=[int(sys.argv[2])] if member == "SetCount" else []))
        bus.disconnect()
        if reply.message_type == MessageType.ERROR:
            raise RuntimeError(reply.body)
        if reply.body:
            print(reply.body[0])
        return
    control = Control()
    bus.export("/TrayTest", control)
    await bus.request_name("org.nonchalant.TrayFixture")
    ready = False
    for _ in range(200):
        reply = await bus.call(Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
            interface="org.freedesktop.DBus", member="NameHasOwner", signature="s",
            body=["org.kde.StatusNotifierWatcher"]))
        if reply.body == [True]:
            ready = True
            break
        await asyncio.sleep(0.05)
    if not ready:
        raise RuntimeError("No StatusNotifierWatcher on the private bus")
    await control.set_count(2)
    done = asyncio.Event()
    loop = asyncio.get_running_loop()
    loop.add_signal_handler(signal.SIGTERM, done.set)
    await done.wait()
    for item in control.items:
        item.disconnect()
    bus.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
