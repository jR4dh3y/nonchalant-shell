"""Exercise placement, monitor demand, and drag cancellation in isolated Quickshell."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]

QML = r"""
import QtQuick
import QtTest
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services

ShellRoot {
    FloatingWindow {
        visible: true
        implicitWidth: 800
        implicitHeight: 600
        TestCase {
            name: "DesktopRuntime"
            when: Config.initialLoadComplete

            function test_placement() {
                const svc = DesktopWidgetService
                const name = svc.fallbackOutput
                svc.boards = ({[name]: {width: 426, height: 426}})
                svc.widgets = [
                    {key: "media-a", id: "media", screen: name, family: "4x4", col: 0, row: 0},
                    {key: "media-b", id: "media", screen: name, family: "4x4", col: 0, row: 0}
                ]
                const a = svc.geometry(svc.widgets[0], 426, 426)
                const b = svc.geometry(svc.widgets[1], 426, 426)
                verify(a.valid !== b.valid, "A cramped board must not draw overlapping widgets")
                compare(svc.widgets.length, 2, "Overflow widgets must remain saved")
                compare(svc.firstFree(name, "4x4"), null)
                svc.boards = ({[name]: {width: 850, height: 426}})
                const expandedA = svc.geometry(svc.widgets[0], 850, 426)
                const expandedB = svc.geometry(svc.widgets[1], 850, 426)
                verify(expandedA.valid && expandedB.valid)
                verify(expandedA.x + expandedA.width <= expandedB.x
                    || expandedB.x + expandedB.width <= expandedA.x)
                compare(svc.nearestFree(name, 0, 0, "4x4", "media-a").col, 0)
                compare(svc.nearestFree(name, 0, 0, "4x4"), null)
                console.log("PLACEMENT_RUNTIME_PASSED")
            }

            function test_resource_demand_survives_restart_and_start_failure() {
                const monitor = SystemResources
                verify(!GlobalStates.systemMonitorOpen)
                GlobalStates.islandStatsOpen = false
                monitor.subscribe()
                tryVerify(() => monitor.monitorProcess.processId > 0, 5000)
                monitor.updateInterval += 1
                monitor.release()
                tryVerify(() => !monitor.restartPending && monitor.monitorProcess.processId === null, 5000)
                wait(100)
                verify(!monitor.monitorProcess.running, "Released demand must not restart the monitor")
                monitor.subscribe()
                tryVerify(() => monitor.monitorProcess.processId > 0, 5000)
                monitor.release()
                tryVerify(() => monitor.monitorProcess.processId === null, 5000)
                console.log("MONITOR_RUNTIME_PASSED")
                const command = Array.from(monitor.monitorProcess.command)
                monitor.monitorProcess.command = ["nonexistent-nonchalant-private-monitor"]
                monitor.subscribe()
                monitor.updateInterval += 1
                tryVerify(() => !monitor.restartPending && !monitor.monitorProcess.running, 5000,
                    "A failed start must not wedge a requested restart")
                monitor.release()
                monitor.monitorProcess.command = command
                monitor.subscribe()
                tryVerify(() => monitor.monitorProcess.processId > 0, 5000)
                monitor.release()
                tryVerify(() => monitor.monitorProcess.processId === null, 5000)
                console.log("MONITOR_FAILED_START_RECOVERY_PASSED")
                Qt.quit()
            }
        }
    }
    Timer {
        interval: 20000
        running: true
        onTriggered: { console.error("DESKTOP_RUNTIME_TIMEOUT"); Qt.quit() }
    }
}
"""

EDGE_QML = r"""
import QtQuick
import QtTest
import Quickshell
import qs.config
import qs.modules.services
import qs.modules.widgets.desktop
import qs.modules.widgets.desktop.edges
import qs.modules.services.desktop as Domain
import qs.modules.widgets.desktop.impasto.services as Impasto

ShellRoot {
    Variants {
        model: Quickshell.screens
        Item {
            id: edgeHost
            required property ShellScreen modelData
            EdgeWidgets {
                screen: edgeHost.modelData
            }
        }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 700
        Item {
            id: testBoard
            property string tasksWidgetKey: ""
            property string notesWidgetKey: ""
            property list<string> nativeDeckNotes: []
            anchors.fill: parent
            DesktopWidget {
                id: card
                board: testBoard
                screenName: DesktopWidgetService.fallbackOutput
                key: "cancel-spectrum"
            }
            DesktopWidget {
                id: tasksCard
                board: testBoard
                screenName: DesktopWidgetService.fallbackOutput
                key: testBoard.tasksWidgetKey
            }
            DesktopWidget {
                id: notesCard
                board: testBoard
                screenName: DesktopWidgetService.fallbackOutput
                key: testBoard.notesWidgetKey
            }
            TestCase {
                name: "DesktopEditorRuntime"
                when: Config.initialLoadComplete
                function taskRowIn(item, key) {
                    if (item.task?.key === key && typeof item.opened === "function")
                        return item
                    for (const child of item.children ?? []) {
                        const row = taskRowIn(child, key)
                        if (row)
                            return row
                    }
                    return null
                }
                function test_editor_cancellation_and_pending_save() {
                    wait(500)
                    const svc = DesktopWidgetService
                    const name = svc.fallbackOutput
                    verify(svc.screenExists(name))
                    svc.setBoard(name, testBoard.width, testBoard.height)
                    svc.widgets = [{
                        key: "cancel-spectrum", id: "spectrum", screen: name,
                        family: "4x2", col: 0, row: 0
                    }]
                    svc.editingScreen = name
                    svc.galleryScreen = name
                    svc.editing = true
                    wait(100)
                    mousePress(card, 100, 60)
                    mouseMove(testBoard, 4, 120, 100)
                    verify(svc.inHand, "The gesture must start the actual DragHandler")
                    svc.closeEditor()
                    mouseRelease(testBoard, 4, 120)
                    wait(50)
                    const row = svc.entryOf("cancel-spectrum")
                    verify(!row.edge, "Cancelling near an edge must not convert the widget")
                    compare(row.col, 0)
                    compare(row.row, 0)
                    compare(row.family, "4x2")
                    compare(svc.dragging, "")
                    console.log("EDGE_CANCELLATION_PASSED")
                    const key = svc.add("clock", name, 2, 1)
                    verify(key !== "")
                    Config.desktop.widgetShadow = !Config.desktop.widgetShadow
                    tryVerify(() => Config.desktop.widgets.some(widget => widget.key === key), 3000)
                    wait(200)
                    verify(svc.entryOf(key) !== null,
                        "A settings reload must not discard an unsaved new widget")
                    svc.setCaption(key, "Committed caption")
                    svc.closeEditor()
                    compare(Config.desktop.widgets.find(widget => widget.key === key).caption,
                        "Committed caption", "Closing the editor must publish committed edits")
                    const detailKey = svc.add("notes", name, 0, 3)
                    verify(detailKey !== "")
                    verify(svc.openDetail("notes", svc.entryOf(detailKey)))
                    verify(FocusGrabManager.hasActiveGrab)

                    svc.update(key, {col: 3})
                    svc.selected = key
                    Config.desktop.widgets = [{
                        key: "external-clock", id: "clock", screen: name,
                        family: "2x2", col: 4, row: 2
                    }]
                    wait(200)
                    compare(svc.entryOf(key), null,
                        "A genuinely changed external layout must remain authoritative")
                    compare(svc.entryOf("external-clock").col, 4)
                    compare(Config.desktop.widgets[0].key, "external-clock")
                    compare(svc.selected, "", "External removal must clear the inspector selection")
                    compare(svc.detailModuleId, "", "External removal must close the detail view")
                    compare(svc.detailKey, "")
                    compare(svc.detailRow, null)
                    compare(svc.detailGrabId, "")
                    verify(!FocusGrabManager.hasActiveGrab,
                        "Removing the open detail widget must release its focus grab")
                    verify(!card.visible, "A removed widget must not leave a blank card")
                    console.log("PENDING_WIDGET_SAVE_PASSED")

                    const taskKey = Domain.TasksService.add("Keep the selected task", Domain.TasksService.todayKey)
                    testBoard.tasksWidgetKey = svc.add("tasks", name, 0, 0)
                    verify(testBoard.tasksWidgetKey !== "")
                    svc.setTheme(testBoard.tasksWidgetKey, "modern")
                    svc.setFamily(testBoard.tasksWidgetKey, "4x4")
                    tryVerify(() => taskRowIn(tasksCard, taskKey) !== null, 3000)
                    let taskRow = taskRowIn(tasksCard, taskKey)
                    tryVerify(() => {
                        const box = svc.geometry(svc.entryOf(testBoard.tasksWidgetKey),
                            testBoard.width, testBoard.height)
                        return tasksCard.x === box.x && tasksCard.y === box.y
                            && tasksCard.width === box.width && tasksCard.height === box.height
                    }, 1000, "The task widget must finish its geometry animation before input")
                    wait(17)
                    taskRow = taskRowIn(tasksCard, taskKey)
                    mouseClick(taskRow, 13, taskRow.height / 2)
                    const checkboxState = Domain.TasksService.entry(taskKey).state
                    if (checkboxState !== "done")
                        console.error(`TASK_CHECKBOX_DID_NOT_TOGGLE: ${taskKey} remained ${checkboxState}`)
                    compare(checkboxState, "done", "Clicking the real task checkbox must complete its task")
                    compare(svc.detailModuleId, "", "The tick must not also open the task")
                    tryVerify(() => taskRowIn(tasksCard, taskKey) === null, 3000)
                    Domain.TasksService.toggle(taskKey)
                    tryVerify(() => taskRowIn(tasksCard, taskKey) !== null, 3000)
                    taskRow = taskRowIn(tasksCard, taskKey)
                    mouseClick(taskRow, 60, taskRow.height / 2)
                    compare(svc.detailModuleId, "tasks")
                    compare(svc.detailRow.task, taskKey)
                    compare(svc.detailKey, testBoard.tasksWidgetKey)
                    const taskGrab = svc.detailGrabId
                    verify(taskGrab !== "")
                    Impasto.ModuleService.requestPanel("board", svc.entryOf(testBoard.tasksWidgetKey))
                    Impasto.ModuleService.requestPanel("tasks", svc.entryOf(testBoard.tasksWidgetKey))
                    compare(svc.detailGrabId, taskGrab, "Repeated source panel actions must not replace the grab")
                    compare(svc.detailRow.task, taskKey, "Repeated source panel actions must preserve the selected task")
                    svc.closeDetail()

                    const noteKey = Domain.NotesService.add("Source note", "Open exactly this note")
                    testBoard.notesWidgetKey = svc.add("notes", name, 5, 0)
                    verify(testBoard.notesWidgetKey !== "")
                    svc.update(testBoard.notesWidgetKey, {note: noteKey})
                    tryVerify(() => {
                        const box = svc.geometry(svc.entryOf(testBoard.notesWidgetKey),
                            testBoard.width, testBoard.height)
                        return notesCard.visible && notesCard.x === box.x && notesCard.y === box.y
                            && notesCard.width === box.width && notesCard.height === box.height
                    }, 1000, "The note widget must finish its geometry animation before input")
                    wait(17)
                    mouseClick(notesCard, notesCard.width / 2, notesCard.height / 2)
                    compare(svc.detailModuleId, "notes")
                    compare(svc.detailRow.note, noteKey)
                    compare(svc.detailKey, testBoard.notesWidgetKey)
                    const noteGrab = svc.detailGrabId
                    Impasto.ModuleService.requestPanel("notes", svc.entryOf(testBoard.notesWidgetKey))
                    compare(svc.detailGrabId, noteGrab)
                    compare(svc.detailRow.note, noteKey)
                    svc.remove(testBoard.notesWidgetKey)
                    compare(svc.detailModuleId, "")
                    verify(!FocusGrabManager.hasActiveGrab)
                    const petService = Domain.PetService
                    compare(petService.watchers, 0, "No pet face should be watching yet")
                    svc.update(testBoard.tasksWidgetKey, {id: "pet", family: "2x2", opacity: 100})
                    tryVerify(() => tasksCard.visible && tasksCard.faceActive
                        && tasksCard.width > 0 && tasksCard.height > 0
                        && tasksCard.solidity === 1 && petService.watchers === 1,
                        1000, "A visible opaque pet widget must own one pet-service watch")

                    svc.update(testBoard.tasksWidgetKey, {opacity: 0})
                    tryVerify(() => tasksCard.visible && !tasksCard.faceActive
                        && tasksCard.width > 0 && tasksCard.height > 0
                        && tasksCard.solidity === 0 && petService.watchers === 0,
                        1000, "A transparent pet widget must release its pet-service watch")

                    svc.update(testBoard.tasksWidgetKey, {opacity: 100})
                    tryVerify(() => tasksCard.visible && tasksCard.faceActive
                        && tasksCard.width > 0 && tasksCard.height > 0
                        && tasksCard.solidity === 1 && petService.watchers === 1,
                        1000, "Restoring pet opacity must reacquire one pet-service watch")

                    Config.desktop.hidden = true
                    tryVerify(() => !tasksCard.visible && !tasksCard.faceActive
                        && petService.watchers === 0,
                        1000, "Hiding the desktop must release its pet-service watch")
                    Config.desktop.hidden = false
                    tryVerify(() => tasksCard.visible && tasksCard.faceActive
                        && tasksCard.width > 0 && tasksCard.height > 0
                        && tasksCard.solidity === 1 && petService.watchers === 1,
                        1000, "Showing the pet widget again must reacquire one watch")

                    svc.remove(testBoard.tasksWidgetKey)
                    tryVerify(() => !tasksCard.visible && petService.watchers === 0,
                        1000, "Unloading the pet widget must release its watch")
                    console.log("PET_WIDGET_DEMAND_PASSED")

                    testBoard.nativeDeckNotes = [noteKey]
                    const deckKey = svc.newKey("notes")
                    svc.write([{
                        key: deckKey, id: "notes", edge: "right",
                        notes: testBoard.nativeDeckNotes, along: 0, screen: name
                    }])
                    tryVerify(() => {
                        const row = svc.entryOf(deckKey)
                        const deck = Domain.DeckService.decksOn(name)[0]
                        const surface = Domain.DeckService.surfaces[name]
                        return Domain.DeckService.isDeck(row)
                            && Domain.DeckService.count === 1
                            && deck?.key === deckKey && deck?.notes.length === 1
                            && deck.notes[0].key === noteKey
                            && surface !== undefined && surface !== null
                            && surface.decks.length === 1
                            && Domain.DeckService.windows.some(window => window === surface)
                    }, 1000, "The native note sequence must be recognized and mounted")
                    tryVerify(() => Config.desktop.widgets.some(widget =>
                        widget.key === deckKey && widget.notes.length === 1
                            && widget.notes[0] === noteKey),
                        1000, "The recognized deck must persist through desktop settings")

                    Domain.NotesService.remove(noteKey)
                    tryVerify(() => Domain.NotesService.entry(noteKey) === null
                        && svc.entryOf(deckKey) === null && Domain.DeckService.count === 0
                        && Domain.DeckService.decksOn(name).length === 0
                        && Domain.DeckService.surfaces[name].decks.length === 0,
                        1000, "Removing the final note must remove its actual deck")
                    tryVerify(() => !Config.desktop.widgets.some(widget => widget.key === deckKey),
                        1000, "Removing the final note must persist deck removal")
                    console.log("DESKTOP_DECK_SEQUENCE_PASSED")


                    console.log("SOURCE_NESTED_ACTIONS_PASSED")
                    Qt.quit()
                }
            }
        }
    }
    Timer {
        interval: 15000
        running: true
        onTriggered: { console.error("EDGE_CANCELLATION_TIMEOUT"); Qt.quit() }
    }
}
"""


def _fixture(directory, qml):
    fixture = Path(directory)
    for name in ("modules", "config", "assets", "scripts", "version"):
        (fixture / name).symlink_to(ROOT / name, target_is_directory=(ROOT / name).is_dir())
    (fixture / "shell.qml").write_text(qml)
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
        "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(runtime / "no-session-bus"),
        "QT_QPA_PLATFORM": "offscreen",
        "QT_QUICK_BACKEND": "software",
        "NIRI_SOCKET": str(fixture / "no-compositor.sock"),
    }
    env.pop("WAYLAND_DISPLAY", None)
    return fixture, env


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for runtime checks")
class DesktopRuntimeTests(unittest.TestCase):
    def test_placement_and_monitor_lifecycle(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-desktop-test-") as directory:
            fixture, env = _fixture(directory, QML)
            result = subprocess.run(
                ["qs", "-p", str(fixture), "--no-duplicate", "--no-color"],
                env=env, capture_output=True, text=True, timeout=30,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("PLACEMENT_RUNTIME_PASSED", output, output)
            self.assertIn("MONITOR_RUNTIME_PASSED", output, output)
            self.assertIn("MONITOR_FAILED_START_RECOVERY_PASSED", output, output)
            self.assertNotIn("DESKTOP_RUNTIME_TIMEOUT", output, output)

    @unittest.skipUnless(shutil.which("weston"), "Headless Weston is required for drag checks")
    def test_editor_cancellation_and_pending_configuration(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-desktop-drag-") as directory:
            fixture, env = _fixture(directory, EDGE_QML)
            socket = fixture / "runtime" / "desktop-test"
            with (fixture / "weston.log").open("w+") as log:
                compositor = subprocess.Popen(
                    ["weston", "--backend=headless", "--socket=desktop-test",
                     "--width=1920", "--height=1080", "--idle-time=0"],
                    env=env, stdout=log, stderr=subprocess.STDOUT,
                )
                try:
                    deadline = time.monotonic() + 10
                    while not socket.exists() and compositor.poll() is None and time.monotonic() < deadline:
                        time.sleep(0.02)
                    log.seek(0)
                    self.assertTrue(socket.exists(), log.read())
                    env["QT_QPA_PLATFORM"] = "wayland"
                    env["WAYLAND_DISPLAY"] = "desktop-test"
                    env.pop("QT_QUICK_BACKEND")
                    result = subprocess.run(
                        ["qs", "-p", str(fixture), "--no-duplicate", "--no-color"],
                        env=env, capture_output=True, text=True, timeout=25,
                    )
                    output = result.stdout + result.stderr
                    self.assertEqual(result.returncode, 0, output)
                    self.assertIn("EDGE_CANCELLATION_PASSED", output, output)
                    self.assertIn("PENDING_WIDGET_SAVE_PASSED", output, output)
                    self.assertIn("PET_WIDGET_DEMAND_PASSED", output, output)
                    self.assertIn("SOURCE_NESTED_ACTIONS_PASSED", output, output)
                    self.assertIn("DESKTOP_DECK_SEQUENCE_PASSED", output, output)
                    self.assertNotIn("EDGE_CANCELLATION_TIMEOUT", output, output)
                finally:
                    compositor.terminate()
                    try:
                        compositor.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        compositor.kill()
                        compositor.wait(timeout=3)


if __name__ == "__main__":
    unittest.main()
