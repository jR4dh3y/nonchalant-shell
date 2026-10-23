pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services.compositor
import "compositor/SessionSelection.js" as SessionSelection

Singleton {
    id: root

    readonly property string compositor: SessionSelection.select(
        Quickshell.env("NONCHALANT_COMPOSITOR"), Quickshell.env("NIRI_SOCKET"),
        Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"), Quickshell.env("XDG_CURRENT_DESKTOP"))
    readonly property CompositorBackend backend: backendLoader.item
    readonly property bool ready: backend?.ready ?? false
    readonly property bool supportsOverview: backend?.supportsOverview ?? false
    readonly property CompositorState state: backend?.state ?? null
    readonly property list<CompositorWindow> windows: state?.windows ?? []
    readonly property list<CompositorWorkspace> workspaces: state?.workspaces ?? []
    readonly property list<CompositorOutput> monitors: state?.outputs ?? []
    readonly property CompositorWorkspace focusedWorkspace: workspaces.find(workspace => workspace.focused) ?? null
    readonly property CompositorOutput focusedMonitor: monitors.find(monitor => monitor.focused) ?? null
    readonly property CompositorWindow focusedClient: windows.find(window => window.is_focused) ?? null
    readonly property bool overviewOpen: state?.overviewOpen ?? false
    readonly property list<string> fullscreenOutputs: state?.fullscreenOutputs ?? []

    signal actionFailed(string action, string targetId, string message)

    Loader {
        id: backendLoader
        active: root.compositor === "niri" || root.compositor === "hyprland"
        source: root.compositor === "niri" ? "compositor/NiriBackend.qml" : "compositor/hyprland/HyprlandBackend.qml"
    }

    Connections {
        target: root.backend
        function onActionFailed(action: string, targetId: string, message: string) {
            console.warn("CompositorService:", action, targetId, message);
            root.actionFailed(action, targetId, message);
        }
    }

    function workspaceById(id: string): CompositorWorkspace {
        return workspaces.find(workspace => workspace.id === id) ?? null;
    }

    function windowById(id: string): CompositorWindow {
        return windows.find(window => window.id === id) ?? null;
    }

    function monitorFor(name: string): CompositorOutput {
        return monitors.find(monitor => monitor.name === name) ?? null;
    }

    function windowsForWorkspace(id: string): list<CompositorWindow> {
        return windows.filter(window => window.workspaceId === id);
    }

    function workspacesForOutput(name: string): list<CompositorWorkspace> {
        return workspaces.filter(workspace => workspace.output === name && !workspace.special
            && (workspace.isNamed || workspace.active || workspace.windows > 0)).sort((left, right) => left.idx - right.idx);
    }

    function activeWorkspaceForOutput(name: string): CompositorWorkspace {
        return workspaces.find(workspace => workspace.output === name && workspace.active && workspace.special)
            ?? workspaces.find(workspace => workspace.output === name && workspace.active) ?? null;
    }

    function activeWindowForOutput(name: string): CompositorWindow {
        if (focusedClient?.output === name)
            return focusedClient;
        return windowById(activeWorkspaceForOutput(name)?.activeWindowId ?? "");
    }

    function hasWindowAtTop(name: string, threshold: real): bool {
        const activeIds = workspaces.filter(workspace => workspace.output === name && workspace.active).map(workspace => workspace.id);
        return windows.some(window => activeIds.includes(window.workspaceId)
            && (window.tiledAtTop || (window.geometryKnown && window.geometry.y <= threshold
                && window.geometry.y + window.geometry.height > 0)));
    }

    function submit(action: string, targetId: string, args): bool {
        if (!ready) {
            root.actionFailed(action, targetId, "Compositor is not ready");
            return false;
        }
        if (typeof backend[action] !== "function") {
            root.actionFailed(action, targetId, "Unknown compositor action");
            return false;
        }
        backend[action].apply(backend, args);
        return true;
    }

    function focusWorkspace(id: string): bool {
        if (workspaceById(id) === null) {
        root.actionFailed("focusWorkspace", id, "Workspace no longer exists");
        return false;
    }
    return submit("focusWorkspace", id, [id]);
    }

    function focusWindow(id: string): bool {
        if (windowById(id) === null) {
        root.actionFailed("focusWindow", id, "Window no longer exists");
        return false;
    }
    return submit("focusWindow", id, [id]);
    }

    function closeWindow(id: string): bool {
        if (windowById(id) === null) {
        root.actionFailed("closeWindow", id, "Window no longer exists");
        return false;
    }
    return submit("closeWindow", id, [id]);
    }

    function moveWindowToWorkspace(windowId: string, workspaceId: string, followFocus: bool): bool {
        if (windowById(windowId) === null) {
            root.actionFailed("moveWindowToWorkspace", windowId, "Window no longer exists");
            return false;
        }
        if (workspaceById(workspaceId) === null) {
            root.actionFailed("moveWindowToWorkspace", windowId, "Workspace no longer exists");
            return false;
        }
        return submit("moveWindowToWorkspace", windowId, [windowId, workspaceId, followFocus]);
    }

    function focusMonitor(name: string): bool {
        if (monitorFor(name) === null) {
        root.actionFailed("focusMonitor", name, "Output no longer exists");
        return false;
    }
    return submit("focusMonitor", name, [name]);
    }

    function focusAdjacentWorkspace(output: string, direction: int): bool {
        if (direction === 0 || monitorFor(output) === null) {
            root.actionFailed("focusAdjacentWorkspace", output, "Output no longer exists");
            return false;
        }
        return submit("focusAdjacentWorkspace", output, [output, direction]);
    }

    function toggleOverview(): bool {
        if (!supportsOverview) {
            root.actionFailed("toggleOverview", "", "Overview is not supported by this compositor");
            return false;
        }
        return submit("toggleOverview", "", []);
    }

    function logout(): bool {
        return submit("logout", "", []);
    }

    function setMonitorPower(enabled: bool): bool {
        return submit("setMonitorPower", "", [enabled]);
    }

    IpcHandler {
        target: "compositor"
        function outputs(): string { return root.monitors.map(monitor => monitor.name).join("\n"); }
        function power(enabled: bool): bool { return root.setMonitorPower(enabled); }
    }

    Component.onCompleted: {
        if (compositor === "ambiguous" || compositor === "unsupported")
            console.warn("CompositorService: could not select a compositor; set NONCHALANT_COMPOSITOR=niri or hyprland");
    }
}
