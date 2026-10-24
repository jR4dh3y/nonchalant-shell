pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services

// Focus changes hand keyboard ownership back to the desktop in every Deck entry.
Singleton {
    function focusWindow(id: string): void {
        Visibilities.closeActiveBarPopup();
        CompositorService.focusWindow(id);
    }
    function focusWorkspace(id: string): void {
        Visibilities.closeActiveBarPopup();
        CompositorService.focusWorkspace(id);
    }
    function adjacentWorkspace(output: string, direction: int): void {
        Visibilities.closeActiveBarPopup();
        CompositorService.focusAdjacentWorkspace(output, direction);
    }
}
