pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    required property ShellScreen screen

    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool open: (Config.bar?.style !== "island") && (screenVisibilities ? screenVisibilities.launcher : false)
    readonly property Item hitbox: menuSurface.fullyHidden ? null : menuSurface.body
    property PanelWindow barPanel: Visibilities.getBarPanelForScreen(screen.name)
    readonly property int edgeGap: 8
    readonly property bool bottomEdge: (Config.bar?.position ?? "top") === "bottom"
    readonly property real barClearance: {
        if (!barPanel || !barPanel.barEnabled)
            return edgeGap;
        return (barPanel.totalBarHeight > 0 ? barPanel.totalBarHeight : (barPanel.barTargetHeight + barPanel.barOuterMargin)) + edgeGap;
    }
    // Keep the launcher mounted until the surface has fully retracted.
    readonly property bool menuShown: open || !menuSurface.fullyHidden

    onOpenChanged: {
        if (!open)
            return;
        GlobalStates.clearLauncherState();
        GlobalStates.clearProjectPickerState();
        Qt.callLater(() => {
            if (root.open && launcherLoader.item)
                launcherLoader.item.forceActiveFocus();
        });
    }

    Item {
        id: edgeRegion

        x: 0
        y: root.bottomEdge ? 0 : root.barClearance
        width: root.width
        height: Math.max(0, root.height - root.barClearance)
        clip: true

        MorphSurface {
            id: menuSurface

            shown: root.open
            contentWidth: launcherLoader.item ? launcherLoader.item.implicitWidth + padding * 2 : 0
            contentHeight: launcherLoader.item ? launcherLoader.item.implicitHeight + padding * 2 : 0
            fromBottom: root.bottomEdge
            x: Math.round((edgeRegion.width - width) / 2)
            y: root.bottomEdge ? edgeRegion.height - height : 0

            Loader {
                id: launcherLoader
                anchors.fill: parent
                // Keep loaded so open/close does not hitch on first paint.
                // The island hosts its own launcher, so skip this copy there
                // (but finish a closing animation after a style switch).
                active: Config.bar?.style !== "island" || root.menuShown
                sourceComponent: Component {
                    LauncherView {}
                }

                onLoaded: {
                    if (root.open)
                        Qt.callLater(() => item.forceActiveFocus());
                }
            }
        }
    }
}
