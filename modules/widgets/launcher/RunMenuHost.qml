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
    readonly property Item hitbox: menuShown ? menuCard : null
    readonly property var barPanel: Visibilities.getBarPanelForScreen(screen.name)
    readonly property int contentPadding: Styling.radius(3)
    readonly property int edgeGap: Styling.radius(2)
    readonly property real barClearance: {
        if (!barPanel || !barPanel.barEnabled)
            return Styling.radius(4);
        return barPanel.barTargetHeight + barPanel.barOuterMargin + edgeGap;
    }

    // Keep the card mounted through the fade-out animation. Scaling this card
    // would resample every label and input inside it.
    property bool menuShown: false
    property real menuOpacity: 0

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
                menuOpacity = 1;
                if (launcherLoader.item)
                    launcherLoader.item.forceActiveFocus();
            });
        } else if (menuShown) {
            menuOpacity = 0;
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: Config.animDuration > 0 ? Math.max(Config.animDuration / 2, 80) + 40 : 40
        onTriggered: {
            if (!root.open)
                root.menuShown = false;
        }
    }

    StyledRect {
        id: menuCard

        variant: "popup"
        enableShadow: false
        radius: Styling.radius(8)
        visible: root.menuShown
        opacity: root.menuOpacity
        width: launcherLoader.item ? launcherLoader.item.implicitWidth + root.contentPadding * 2 : 0
        height: launcherLoader.item ? launcherLoader.item.implicitHeight + root.contentPadding * 2 : 0
        x: Math.round((root.width - width) / 2)
        y: root.barClearance

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuad
            }
        }

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
