pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.modules.bar.deck
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    required property ShellScreen screen

    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool isIslandLike: (Config.bar?.style === "island" || Config.bar?.style === "pills")
    readonly property bool open: !isIslandLike && (screenVisibilities ? screenVisibilities.launcher : false)
    // Deck brings its own launcher, anchored under the bar's launcher button.
    readonly property bool isDeck: (Config.bar?.style ?? "default") === "deck"
    readonly property Item hitbox: isDeck ? (deckLoader.item?.hitbox ?? null)
        : menuSurface.fullyHidden ? null : menuSurface.body
    property PanelWindow barPanel: Visibilities.getBarPanelForScreen(screen.name)
    readonly property int edgeGap: 8
    readonly property bool bottomEdge: !leftEdge && (Config.bar?.position ?? "top") === "bottom"
    readonly property bool leftEdge: (Config.bar?.style ?? "default") === "left"
    readonly property real barClearance: {
        if (!barPanel || !barPanel.barEnabled)
            return edgeGap;
        return (barPanel.totalBarHeight > 0 ? barPanel.totalBarHeight : (barPanel.barTargetHeight + barPanel.barOuterMargin)) + edgeGap;
    }
    // Keep the launcher mounted until the surface has fully retracted.
    readonly property bool menuShown: (open && !isDeck) || !menuSurface.fullyHidden

    onOpenChanged: {
        if (!open)
            return;
        GlobalStates.clearLauncherState();
        GlobalStates.clearProjectPickerState();
        if (root.isDeck)
            return;
        Qt.callLater(() => {
            if (root.open && launcherLoader.item)
                launcherLoader.item.forceActiveFocus();
        });
    }

    Item {
        id: edgeRegion

        x: root.leftEdge ? root.barClearance : 0
        y: root.leftEdge ? 0 : (root.bottomEdge ? 0 : root.barClearance)
        width: root.leftEdge ? Math.max(0, root.width - root.barClearance) : root.width
        height: root.leftEdge ? root.height : Math.max(0, root.height - root.barClearance)
        clip: true

        MorphSurface {
            id: menuSurface

            shown: root.open && !root.isDeck
            contentWidth: launcherLoader.item
                ? (root.leftEdge ? Math.round(launcherLoader.item.implicitWidth * 0.9)
                    : launcherLoader.item.implicitWidth) + padding * 2 : 0
            contentHeight: launcherLoader.item ? launcherLoader.item.implicitHeight + padding * 2 : 0
            fromBottom: root.bottomEdge
            fromLeft: root.leftEdge
            x: root.leftEdge ? 0 : Math.round((edgeRegion.width - width) / 2)
            y: root.leftEdge ? root.edgeGap : (root.bottomEdge ? edgeRegion.height - height : 0)

            Loader {
                id: launcherLoader
                anchors.fill: parent
                // Keep loaded so open/close does not hitch on first paint.
                // The island/pills hosts its own launcher, so skip this copy there
                // (but finish a closing animation after a style switch).
                active: (!root.isIslandLike && !root.isDeck) || root.menuShown
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

    Loader {
        id: deckLoader
        anchors.fill: parent
        active: root.isDeck
        sourceComponent: Component {
            DeckLauncher {
                open: root.open
                barClearance: root.barClearance
                bottomEdge: root.bottomEdge
            }
        }
    }
}
