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
    readonly property bool open: screenVisibilities ? screenVisibilities.launcher : false
    readonly property Item hitbox: menuShown ? cardReveal : null
    property PanelWindow barPanel: Visibilities.getBarPanelForScreen(screen.name)
    readonly property int contentPadding: 8
    readonly property int edgeGap: 8
    readonly property bool bottomEdge: (Config.bar?.position ?? "top") === "bottom"
    readonly property real barClearance: {
        if (!barPanel || !barPanel.barEnabled)
            return edgeGap;
        return (barPanel.totalBarHeight > 0 ? barPanel.totalBarHeight : (barPanel.barTargetHeight + barPanel.barOuterMargin)) + edgeGap;
    }

    // Keep the card mounted while its edge clip closes.
    property bool menuShown: false
    property real revealProgress: 0

    Behavior on revealProgress {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: root.open ? Easing.OutCubic : Easing.InCubic
        }
    }

    onOpenChanged: {
        if (open) {
            closeTimer.stop();
            menuShown = true;
            GlobalStates.clearLauncherState();
            GlobalStates.clearProjectPickerState();
            // Next frame so the window has a size before we animate in.
            Qt.callLater(() => {
                if (!root.open)
                    return;
                revealProgress = 1;
                if (launcherLoader.item)
                    launcherLoader.item.forceActiveFocus();
            });
        } else if (menuShown) {
            revealProgress = 0;
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: Config.animDuration > 0 ? Config.animDuration + 40 : 40
        onTriggered: {
            if (!root.open)
                root.menuShown = false;
        }
    }

    Item {
        id: edgeRegion

        x: 0
        y: root.bottomEdge ? 0 : root.barClearance
        width: root.width
        height: Math.max(0, root.height - root.barClearance)
        clip: true

        Item {
            id: cardReveal

            visible: root.menuShown
            width: launcherLoader.item ? launcherLoader.item.implicitWidth + root.contentPadding * 2 : 0
            height: (launcherLoader.item
                ? launcherLoader.item.implicitHeight + root.contentPadding * 2
                : 0) * root.revealProgress
            x: Math.round((edgeRegion.width - width) / 2)
            y: root.bottomEdge ? edgeRegion.height - height : 0
            clip: true

            StyledRect {
                id: menuCard

                variant: "popup"
                enableShadow: false
                radius: Styling.radius(8)
                width: cardReveal.width
                height: launcherLoader.item
                    ? launcherLoader.item.implicitHeight + root.contentPadding * 2
                    : 0
                y: root.bottomEdge ? cardReveal.height - height : 0

                Loader {
                    id: launcherLoader
                    anchors.fill: parent
                    anchors.margins: root.contentPadding
                    // Keep loaded so open/close does not hitch on first paint.
                    active: true
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
}
