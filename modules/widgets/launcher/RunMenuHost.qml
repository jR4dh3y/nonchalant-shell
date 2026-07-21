pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    required property ShellScreen screen

    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool open: screenVisibilities ? screenVisibilities.launcher : false
    readonly property Item hitbox: menuShown ? menuCard : null
    readonly property string barPosition: Config.bar?.position ?? "top"
    readonly property var barPanel: Visibilities.getBarPanelForScreen(screen.name)
    readonly property int contentPadding: Styling.radius(3)
    readonly property int edgeGap: Styling.radius(2)
    readonly property real barClearance: {
        if (!barPanel)
            return Styling.radius(4);
        const vertical = barPosition === "left" || barPosition === "right";
        const size = vertical ? barPanel.barTargetWidth : barPanel.barTargetHeight;
        return size + barPanel.barOuterMargin + edgeGap;
    }

    // Keep the card mounted through the close animation so opacity/scale can play.
    property bool menuShown: false
    property real menuOpacity: 0
    property real menuScale: 0.96

    onOpenChanged: {
        if (open) {
            closeTimer.stop();
            menuShown = true;
            // Next frame so the window has a size before we animate in.
            Qt.callLater(() => {
                if (!root.open)
                    return;
                menuOpacity = 1;
                menuScale = 1;
                if (launcherLoader.item)
                    launcherLoader.item.forceActiveFocus();
            });
        } else if (menuShown) {
            menuOpacity = 0;
            menuScale = 0.96;
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
        enableShadow: true
        radius: Styling.radius(8)
        visible: root.menuShown
        opacity: root.menuOpacity
        scale: root.menuScale
        width: launcherLoader.item ? launcherLoader.item.implicitWidth + root.contentPadding * 2 : 0
        height: launcherLoader.item ? launcherLoader.item.implicitHeight + root.contentPadding * 2 : 0
        x: {
            if (root.barPosition === "left")
                return root.barClearance;
            if (root.barPosition === "right")
                return root.width - width - root.barClearance;
            return Math.round((root.width - width) / 2);
        }
        y: {
            if (root.barPosition === "top")
                return root.barClearance;
            if (root.barPosition === "bottom")
                return root.height - height - root.barClearance;
            return Math.round((root.height - height) / 2);
        }
        transformOrigin: {
            if (root.barPosition === "top")
                return Item.Top;
            if (root.barPosition === "bottom")
                return Item.Bottom;
            if (root.barPosition === "left")
                return Item.Left;
            if (root.barPosition === "right")
                return Item.Right;
            return Item.Center;
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutCubic
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
