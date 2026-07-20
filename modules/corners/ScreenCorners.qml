import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.services
import qs.config
import qs.modules.bar.workspaces // For CompositorData

PanelWindow {
    id: screenCorners

    property var monitor: null
    property bool activeWindowFullscreen: false

    function updateFullscreen() {
        const mon = NiriService.monitorFor(screen);
        if (mon) {
            monitor = mon;
        }

        if (!monitor) {
            activeWindowFullscreen = false;
            return;
        }

        const activeWorkspaceId = monitor.activeWorkspace.id;
        const monId = monitor.id;

        // Check active toplevel first (fast path)
        const toplevel = ToplevelManager.activeToplevel;
        if (toplevel && toplevel.fullscreen && NiriService.focusedMonitor && NiriService.focusedMonitor.id === monId) {
            activeWindowFullscreen = true;
            return;
        }

        // Check all windows on this monitor (robust path)
        const wins = CompositorData.windowList;
        for (let i = 0; i < wins.length; i++) {
            if (wins[i].monitor === monId && wins[i].fullscreen && wins[i].workspace.id === activeWorkspaceId) {
                activeWindowFullscreen = true;
                return;
            }
        }
        activeWindowFullscreen = false;
    }

    Connections {
        target: NiriService.monitors
        function onValuesChanged() { screenCorners.updateFullscreen(); }
    }

    Connections {
        target: CompositorData
        function onWindowListChanged() { screenCorners.updateFullscreen(); }
    }

    Connections {
        target: NiriService
        function onFocusedMonitorChanged() { screenCorners.updateFullscreen(); }
    }

    Component.onCompleted: updateFullscreen()

    visible: Config.theme.enableCorners && Config.roundness > 0 && !activeWindowFullscreen

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nonchalant:screenCorners"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {
        item: null
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    ScreenCornersContent {
        id: cornersContent
        anchors.fill: parent
        hasFullscreenWindow: screenCorners.activeWindowFullscreen
    }
}
