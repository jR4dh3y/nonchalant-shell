import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Io
import qs.modules.services
import qs.modules.globals
import qs.config

Item {
    id: root

    function dashboardItems(item: Item): list<var> {
        if (!item)
            return [];
        let items = [];
        const trayItem = item.objectName.startsWith("trayFlyout") || item.objectName.startsWith("trayMenuAction") || item.objectName === "verticalTrayButton";
        if (trayItem || item.objectName.startsWith("audioStatus") || item.objectName.startsWith("dashboard") || item.objectName.startsWith("verticalWorkspace") || item.objectName.startsWith("workspaceWindows")) {
            const position = trayItem ? item.mapToGlobal(0, 0) : item.mapToItem(null, 0, 0);
            items.push({
                name: item.objectName,
                geometry: [position.x, position.y, item.width, item.height],
                visible: item.visible,
                enabled: item.enabled,
                opacity: item.opacity,
                activeFocus: item.activeFocus,
                monthShift: item.objectName === "dashboardCalendar" ? item.monthShift : null
            });
        }
        for (const child of item.children)
            items = items.concat(root.dashboardItems(child));
        return items;
    }

    IpcHandler {
        target: "shell-test"
        function assistant(position: string, pinned: bool, visible: bool, barPosition: string, barEnabled: bool): void {
            Config.ai.enabled = visible;
            Config.ai.sidebarEnabled = true;
            Config.bar.position = barPosition;
            Config.bar.screenList = barEnabled ? [] : ["not-a-test-output"];
            GlobalStates.assistantPosition = position;
            GlobalStates.assistantPinned = pinned;
            GlobalStates.assistantWidth = 400;
            GlobalStates.assistantScreenName = Quickshell.screens[0]?.name ?? "";
            GlobalStates.assistantVisible = visible;
        }

        function state(): string {
            const island = Visibilities.getIslandForActive();
            const outputName = Quickshell.screens[0]?.name ?? "";
            const controller = Visibilities.getDashboardControllerForActive();
            const panel = Visibilities.getBarPanelForScreen(outputName);
            const sidebar = panel?.assistantSidebar;
            const hitbox = sidebar?.hitbox;
            const hitboxPosition = hitbox?.mapToItem(null, 0, 0);
            return JSON.stringify({
                activeModule: Visibilities.currentActiveModule,
                activeScreen: Visibilities.getForActive()?.screenName ?? "",
                activeLauncher: Visibilities.getForActive()?.launcher ?? false,
                screenLaunchers: Object.keys(Visibilities.screens).map(name => ({
                    name: name, launcher: Visibilities.screens[name].launcher
                })),
                launcherOpen: GlobalStates.launcherOpen,
                dashboardOpen: GlobalStates.dashboardOpen,
                popupOpen: Visibilities.activeBarPopup?.isOpen ?? false,
                trayCount: SystemTray.items.values.length,
                trayOpen: Visibilities.activeBarPopup?.objectName === "verticalTrayFlyout"
                    && Visibilities.activeBarPopup.isOpen,
                trayMenuItem: Visibilities.activeBarPopup?.menuItem?.id ?? "",
                trayItems: Visibilities.activeBarPopup?.objectName === "verticalTrayFlyout"
                    ? root.dashboardItems(Visibilities.activeBarPopup.contentItem) : [],
                trayButton: root.dashboardItems(controller?.bar ?? null)
                    .find(item => item.name === "verticalTrayButton") ?? null,
                systemMonitorOpen: GlobalStates.systemMonitorOpen,
                controlMenu: Visibilities.activeBarPopup?.menuMode ?? "",
                dashboardSection: controller?.dashboardSection ?? "",
                dashboardTab: GlobalStates.dashboardCurrentTab,
                dashboardItems: root.dashboardItems(controller?.dashboardHitbox ?? null),
                workspaceItems: root.dashboardItems(island ?? controller?.bar ?? null)
                    .filter(item => item.name.startsWith("verticalWorkspace") || item.name.startsWith("workspaceWindows")),
                powerOpen: Visibilities.powerMenuButtons[outputName]?.popupOpen ?? false,
                hasActiveGrab: FocusGrabManager.hasActiveGrab,
                settingsVisible: GlobalStates.settingsWindowVisible,
                panelSize: [panel?.width ?? 0, panel?.height ?? 0],
                barPosition: panel?.barPosition ?? "",
                assistant: sidebar ? {
                    geometry: [sidebar.x, sidebar.y, sidebar.width, sidebar.height],
                    hitbox: [hitboxPosition?.x ?? 0, hitboxPosition?.y ?? 0, hitbox?.width ?? 0, hitbox?.height ?? 0],
                    active: sidebar.active
                } : null,
                island: island ? {
                    mode: island.currentMode,
                    expanded: island.isExpanded,
                    retracting: island.retractingToHidden,
                    geometry: [island.x, island.y, island.width, island.height]
                } : null
            });
        }
    }
}
