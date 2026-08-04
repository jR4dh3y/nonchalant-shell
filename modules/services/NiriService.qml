pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var focusedMonitor: null
    property var focusedWorkspace: null
    property var focusedClient: null

    // Niri compositor overview (Mod+Tab). The bar should hide while this is open.
    property bool overviewOpen: false

    // Outputs whose active workspace shows a fullscreen window. Niri only
    // auto-hides layer surfaces below Overlay, so the bar hides itself.
    property var fullscreenOutputs: []

    property var rawWindows: []
    property var rawWorkspaces: []
    property var rawOutputs: ({})

    property QtObject clients: QtObject {
        property var values: []
    }

    property QtObject monitors: QtObject {
        property var values: []
    }

    property QtObject workspaces: QtObject {
        property var values: []
    }

    signal rawEvent(var event)

    function workspaceById(id) {
        const numericId = Number(id);
        return root.rawWorkspaces.find(workspace => Number(workspace.id) === numericId) ?? null;
    }

    function workspaceReference(id) {
        const workspace = workspaceById(id);
        if (!workspace)
            return String(id);
        return workspace.name || String(workspace.idx);
    }

    function monitorFor(screen) {
        if (!screen)
            return null;
        const name = typeof screen === "string" ? screen : screen.name;
        return root.monitors.values.find(monitor => monitor.name === name) ?? null;
    }

    function focusWorkspace(id) {
        runNiriAction(["focus-workspace", workspaceReference(id)]);
    }

    function focusWindow(id) {
        runNiriAction(["focus-window", "--id", String(id)]);
    }

    function closeWindow(id) {
        const focus = createProcess(["niri", "msg", "action", "focus-window", "--id", String(id)]);
        focus.exited.connect(() => {
            runNiriAction(["close-window"]);
            focus.destroy();
        });
        focus.running = true;
    }

    function moveWindowToWorkspace(windowId, workspaceId, followFocus = false) {
        runNiriAction([
            "move-window-to-workspace",
            "--window-id", String(windowId),
            "--focus", followFocus ? "true" : "false",
            workspaceReference(workspaceId)
        ]);
    }

    function focusMonitor(name) {
        runNiriAction(["focus-monitor", String(name)]);
    }

    function runNiriAction(args) {
        const process = createProcess(["niri", "msg", "action"].concat(args));
        process.exited.connect(() => process.destroy());
        process.running = true;
    }

    function createProcess(command) {
        return processComponent.createObject(root, { "command": command });
    }

    function dispatch(command) {
        if (!command)
            return;

        const firstSpace = command.indexOf(" ");
        const action = firstSpace === -1 ? command : command.slice(0, firstSpace);
        const rawArgs = firstSpace === -1 ? "" : command.slice(firstSpace + 1).trim();
        const addressMatch = rawArgs.match(/address:([^\s,]+)/);
        const windowId = addressMatch ? addressMatch[1] : rawArgs;

        switch (action) {
        case "workspace":
            if (rawArgs === "r+1")
                runNiriAction(["focus-workspace-down"]);
            else if (rawArgs === "r-1")
                runNiriAction(["focus-workspace-up"]);
            else
                focusWorkspace(rawArgs);
            break;
        case "focuswindow":
            focusWindow(windowId);
            break;
        case "closewindow":
            closeWindow(windowId);
            break;
        case "movetoworkspacesilent": {
            const parts = rawArgs.split(",");
            const workspaceId = parts[0].trim();
            const idMatch = rawArgs.match(/address:([^\s,]+)/);
            if (idMatch)
                moveWindowToWorkspace(idMatch[1], workspaceId, false);
            break;
        }
        case "focusmonitor":
            focusMonitor(rawArgs);
            break;
        case "togglespecialworkspace":
            console.warn("NiriService: special workspaces are not available on Niri");
            break;
        case "movewindowpixel":
            // Niri owns placement inside the scrolling layout. The overview can still
            // move windows between workspaces, but arbitrary pixel placement is ignored.
            break;
        default:
            console.warn("NiriService: unsupported compositor action:", command);
        }
    }

    function rebuildState() {
        const workspaceMap = {};
        const workspaceValues = root.rawWorkspaces.map(workspace => {
            const normalized = {
                id: Number(workspace.id),
                idx: Number(workspace.idx),
                name: workspace.name || String(workspace.idx),
                isNamed: typeof workspace.name === "string" && workspace.name.trim().length > 0,
                output: workspace.output || "",
                monitor: workspace.output || "",
                active: workspace.is_active === true,
                focused: workspace.is_focused === true,
                is_urgent: workspace.is_urgent === true,
                activeWindowId: workspace.active_window_id ?? null,
                windows: 0
            };
            workspaceMap[normalized.id] = normalized;
            return normalized;
        }).sort((a, b) => a.idx - b.idx);

        const clientValues = root.rawWindows.map(window => {
            const workspace = workspaceMap[Number(window.workspace_id)] ?? null;
            const layout = window.layout || {};
            const scrollingPosition = layout.pos_in_scrolling_layout || [0, 0];
            const tilePosition = layout.tile_pos_in_workspace_view || [0, 0];
            const tileSize = layout.tile_size || layout.window_size || [100, 100];
            const timestamp = window.focus_timestamp || { secs: 0, nanos: 0 };

            if (workspace)
                workspace.windows += 1;

            return {
                address: Number(window.id),
                id: Number(window.id),
                class: window.app_id || "",
                appId: window.app_id || "",
                title: window.title || "",
                workspace: {
                    id: workspace ? workspace.id : Number(window.workspace_id || 0),
                    name: workspace ? workspace.name : ""
                },
                monitor: workspace ? workspace.output : "",
                output: workspace ? workspace.output : "",
                floating: window.is_floating === true,
                fullscreen: false,
                hidden: false,
                mapped: true,
                urgent: window.is_urgent === true,
                at: tilePosition,
                size: tileSize,
                scrollingPosition: scrollingPosition,
                xwayland: false,
                is_focused: window.is_focused === true,
                focusHistoryID: -(Number(timestamp.secs || 0) * 1000 + Number(timestamp.nanos || 0) / 1000000)
            };
        }).sort((a, b) => {
            const workspaceA = workspaceMap[a.workspace.id];
            const workspaceB = workspaceMap[b.workspace.id];
            const workspaceOrder = (workspaceA ? workspaceA.idx : 0) - (workspaceB ? workspaceB.idx : 0);
            if (workspaceOrder !== 0)
                return workspaceOrder;
            const columnOrder = Number(a.scrollingPosition[0] || 0) - Number(b.scrollingPosition[0] || 0);
            if (columnOrder !== 0)
                return columnOrder;
            const tileOrder = Number(a.scrollingPosition[1] || 0) - Number(b.scrollingPosition[1] || 0);
            return tileOrder !== 0 ? tileOrder : a.id - b.id;
        });

        const monitorValues = Object.keys(root.rawOutputs).map(name => {
            const output = root.rawOutputs[name] || {};
            const logical = output.logical || {};
            const activeWorkspace = workspaceValues.find(workspace => workspace.output === name && workspace.active) ?? null;
            const currentMode = output.modes && output.current_mode !== null ? output.modes[output.current_mode] : null;
            return {
                id: name,
                name: name,
                focused: activeWorkspace ? activeWorkspace.focused : false,
                width: Number(logical.width || (currentMode ? currentMode.width : 0)),
                height: Number(logical.height || (currentMode ? currentMode.height : 0)),
                refreshRate: currentMode ? Number(currentMode.refresh_rate || 0) / 1000 : 0,
                scale: Number(logical.scale || 1),
                x: Number(logical.x || 0),
                y: Number(logical.y || 0),
                activeWorkspace: activeWorkspace ? { id: activeWorkspace.id, name: activeWorkspace.name } : null
            };
        });

        const clientMap = {};
        clientValues.forEach(client => clientMap[client.id] = client);

        // Niri 26.04 does not expose a fullscreen boolean through IPC. A real
        // fullscreen window occupies the complete logical output as a tile.
        // Unlike fullscreen, maximize-to-edges still leaves the bar's
        // exclusive zone available, so tile geometry distinguishes the two.
        // Check only the tile: fixed-size fullscreen clients can keep a
        // smaller window geometry centered over Niri's black backdrop.
        const fullscreenOutputs = workspaceValues
            .filter(workspace => {
                if (!workspace.active || !workspace.output || workspace.activeWindowId === null)
                    return false;

                const client = clientMap[Number(workspace.activeWindowId)] ?? null;
                const monitor = monitorValues.find(value => value.name === workspace.output) ?? null;
                if (!client || !monitor || monitor.width <= 0 || monitor.height <= 0)
                    return false;

                const epsilon = 0.5;
                const fillsOutput = Math.abs(Number(client.size[0]) - monitor.width) <= epsilon
                    && Math.abs(Number(client.size[1]) - monitor.height) <= epsilon;
                client.fullscreen = fillsOutput;
                return fillsOutput;
            })
            .map(workspace => workspace.output);

        root.workspaces.values = workspaceValues;
        root.clients.values = clientValues;
        root.monitors.values = monitorValues;
        root.focusedWorkspace = workspaceValues.find(workspace => workspace.focused) ?? workspaceValues.find(workspace => workspace.active) ?? null;
        root.focusedMonitor = monitorValues.find(monitor => monitor.focused) ?? (root.focusedWorkspace ? monitorFor(root.focusedWorkspace.output) : null);
        root.focusedClient = clientValues.find(client => client.is_focused) ?? null;

        root.fullscreenOutputs = fullscreenOutputs;
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

        if (event.WorkspacesChanged)
            root.rawWorkspaces = event.WorkspacesChanged.workspaces || [];
        else if (event.WindowsChanged)
            root.rawWindows = event.WindowsChanged.windows || [];
        else if (event.WorkspaceActivated) {
            const activated = event.WorkspaceActivated;
            const activatedWorkspace = workspaceById(activated.id);
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
            const exists = root.rawWindows.some(window => Number(window.id) === Number(changed.id));
            root.rawWindows = exists
                ? root.rawWindows.map(window => Number(window.id) === Number(changed.id) ? changed : window)
                : root.rawWindows.concat([changed]);
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

        rebuildState();
        root.rawEvent(event);
    }

    Component {
        id: processComponent
        Process {}
    }

    Process {
        id: outputsProcess
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.rawOutputs = JSON.parse(text);
                    root.rebuildState();
                } catch (error) {
                    console.error("NiriService: could not parse outputs:", error);
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
                    console.error("NiriService: could not parse overview state:", error);
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
                    console.error("NiriService: could not parse event:", error);
                }
            }
        }
        onExited: exitCode => {
            console.warn("NiriService: event stream exited with code", exitCode);
            reconnectTimer.restart();
        }
    }

    Timer {
        id: reconnectTimer
        interval: 1000
        onTriggered: eventStream.running = true
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
