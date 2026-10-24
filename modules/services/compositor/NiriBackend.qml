pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "NiriCodec.js" as NiriCodec

CompositorBackend {
    id: root

    supportsOverview: true
    property bool overviewOpen: false
    property bool receivedWindows: false
    property bool receivedWorkspaces: false
    property bool receivedOutputs: false
    property var rawWindows: []
    property var rawWorkspaces: []
    property var rawOutputs: ({})

    function workspaceById(id: string): var {
        return root.rawWorkspaces.find(workspace => String(workspace.id) === id) ?? null;
    }

    function rebuildState() {
        if (!receivedWindows || !receivedWorkspaces || !receivedOutputs)
            return;
        try {
            publish(NiriCodec.normalize(rawWindows, rawWorkspaces, rawOutputs, overviewOpen));
            root.ready = true;
        } catch (error) {
            root.clear();
            console.error("NiriBackend: invalid compositor state:", error);
        }
    }

    function focusWorkspace(id: string) {
        sendAction("FocusWorkspace", { reference: { Id: Number(id) } }, id);
    }

    function focusWindow(id: string) {
        sendAction("FocusWindow", { id: Number(id) }, id);
    }

    function closeWindow(id: string) {
        sendAction("CloseWindow", { id: Number(id) }, id);
    }

    function moveWindowToWorkspace(windowId: string, workspaceId: string, followFocus: bool) {
        sendAction("MoveWindowToWorkspace", { window_id: Number(windowId), reference: { Id: Number(workspaceId) }, focus: followFocus }, windowId);
    }

    function focusMonitor(name: string) {
        sendAction("FocusMonitor", { output: name }, name);
    }

    function focusAdjacentWorkspace(output: string, direction: int) {
        const list = state?.workspaces.filter(workspace => workspace.output === output) ?? [];
        const active = list.findIndex(workspace => workspace.active);
        const target = list[active + (direction > 0 ? 1 : -1)];
        if (active >= 0 && target)
            focusWorkspace(target.id);
    }

    function toggleOverview() {
        sendAction("ToggleOverview", {}, "");
    }

    function logout() {
        sendAction("Quit", { skip_confirmation: true }, "");
    }

    function setMonitorPower(enabled: bool) {
        sendAction(enabled ? "PowerOnMonitors" : "PowerOffMonitors", {}, "");
    }

    function sendAction(action: string, data, targetId: string) {
        if (!ready) {
            root.actionFailed(action, targetId, "Compositor is not ready");
            return;
        }
        const body = {};
        body[action] = data;
        const transaction = actionComponent.createObject(root, {
            request: JSON.stringify({ Action: body }) + "\n", action: action, targetId: targetId
        });
        transaction.start();
    }

    Component {
        id: actionComponent
        Item {
            id: transaction
            required property string request
            required property string action
            required property string targetId
            property bool finished: false

            function start() {
                timeout.start();
                socket.connected = true;
            }

            function finish(message: string) {
                if (finished)
                    return;
                finished = true;
                timeout.stop();
                if (message)
                    root.actionFailed(action, targetId, message);
                socket.connected = false;
                Qt.callLater(() => transaction.destroy());
            }

            Socket {
                id: socket
                path: Quickshell.env("NIRI_SOCKET")
                onConnectionStateChanged: {
                    if (connected) {
                        write(transaction.request);
                        flush();
                    }
                }
                onError: error => transaction.finish("Niri socket error " + error)
                parser: SplitParser {
                    onRead: data => {
                        try {
                            const reply = JSON.parse(data);
                            transaction.finish(reply.Err ?? "");
                        } catch (error) {
                            transaction.finish("Invalid Niri action reply");
                        }
                    }
                }
            }

            Timer {
                id: timeout
                interval: 3000
                onTriggered: transaction.finish("Niri action timed out")
            }
        }
    }

    function replaceWorkspace(id, mutate) {
        const numericId = Number(id);
        root.rawWorkspaces = root.rawWorkspaces.map(workspace => {
            if (Number(workspace.id) !== numericId)
                return workspace;
            const copy = Object.assign({}, workspace);
            mutate(copy);
            return copy;
        });
    }

    function replaceWindow(id, mutate) {
        const numericId = Number(id);
        root.rawWindows = root.rawWindows.map(window => {
            if (Number(window.id) !== numericId)
                return window;
            const copy = Object.assign({}, window);
            mutate(copy);
            return copy;
        });
    }

    function handleEvent(event) {
        if (!event)
            return;

        if (event.WorkspacesChanged) {
            root.rawWorkspaces = event.WorkspacesChanged.workspaces || [];
            root.receivedWorkspaces = true;
        }
        else if (event.WindowsChanged) {
            root.rawWindows = event.WindowsChanged.windows || [];
            root.receivedWindows = true;
        }
        else if (event.WorkspaceActivated) {
            const activated = event.WorkspaceActivated;
            const activatedWorkspace = workspaceById(String(activated.id));
            const output = activatedWorkspace ? activatedWorkspace.output : null;
            root.rawWorkspaces = root.rawWorkspaces.map(workspace => {
                const copy = Object.assign({}, workspace);
                if (output && workspace.output === output)
                    copy.is_active = Number(workspace.id) === Number(activated.id);
                if (activated.focused)
                    copy.is_focused = Number(workspace.id) === Number(activated.id);
                return copy;
            });
        } else if (event.WorkspaceUrgencyChanged) {
            const urgency = event.WorkspaceUrgencyChanged;
            replaceWorkspace(urgency.id, workspace => workspace.is_urgent = urgency.urgent);
        } else if (event.WorkspaceActiveWindowChanged) {
            const active = event.WorkspaceActiveWindowChanged;
            replaceWorkspace(active.workspace_id, workspace => workspace.active_window_id = active.active_window_id);
        } else if (event.WindowOpenedOrChanged) {
            const changed = event.WindowOpenedOrChanged.window;
            root.rawWindows = NiriCodec.updateWindow(root.rawWindows, changed);
        } else if (event.WindowUrgencyChanged) {
            const urgency = event.WindowUrgencyChanged;
            replaceWindow(urgency.id, window => window.is_urgent = urgency.urgent);
        } else if (event.WindowClosed) {
            const closedId = Number(event.WindowClosed.id);
            root.rawWindows = root.rawWindows.filter(window => Number(window.id) !== closedId);
        } else if (event.WindowFocusChanged) {
            const focusedId = event.WindowFocusChanged.id === null ? null : Number(event.WindowFocusChanged.id);
            root.rawWindows = root.rawWindows.map(window => {
                const copy = Object.assign({}, window);
                copy.is_focused = focusedId !== null && Number(window.id) === focusedId;
                return copy;
            });
        } else if (event.WindowLayoutsChanged) {
            const changes = event.WindowLayoutsChanged.changes || [];
            changes.forEach(change => {
                const id = Array.isArray(change) ? change[0] : change.id;
                const layout = Array.isArray(change) ? change[1] : change.layout;
                replaceWindow(id, window => window.layout = layout);
            });
        } else if (event.ConfigLoaded) {
            outputsProcess.running = true;
        } else if (event.OverviewOpenedOrClosed) {
            root.overviewOpen = event.OverviewOpenedOrClosed.is_open === true;
        }

        Qt.callLater(root.rebuildState);
    }

    Process {
        id: outputsProcess
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.rawOutputs = JSON.parse(text);
                    root.receivedOutputs = true;
                    Qt.callLater(root.rebuildState);
                } catch (error) {
                    console.error("NiriBackend: could not parse outputs:", error);
                }
            }
        }
    }

    Process {
        id: overviewStateProcess
        command: ["niri", "msg", "--json", "overview-state"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const state = JSON.parse(text);
                    root.overviewOpen = state.is_open === true;
                } catch (error) {
                    console.error("NiriBackend: could not parse overview state:", error);
                }
            }
        }
    }

    Process {
        id: eventStream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.handleEvent(JSON.parse(data));
                } catch (error) {
                    console.error("NiriBackend: could not parse event:", error);
                }
            }
        }
        onExited: exitCode => {
            console.warn("NiriBackend: event stream exited with code", exitCode);
            root.rawWindows = [];
            root.rawWorkspaces = [];
            root.rawOutputs = ({});
            root.overviewOpen = false;
            root.receivedWindows = false;
            root.receivedWorkspaces = false;
            root.receivedOutputs = false;
            root.clear();
        }
    }

    Timer {
        id: reconnectTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (eventStream.running)
                return;
            outputsProcess.running = true;
            overviewStateProcess.running = true;
            eventStream.running = true;
        }
    }

    Timer {
        interval: 2000
        running: eventStream.running
        repeat: true
        onTriggered: if (!outputsProcess.running) outputsProcess.running = true
    }

    Component.onCompleted: {
        outputsProcess.running = true;
        overviewStateProcess.running = true;
    }

    Component.onDestruction: {
        reconnectTimer.stop();
        eventStream.running = false;
    }
}
