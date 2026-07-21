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
    readonly property Item hitbox: open ? menuCard : null
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

    onOpenChanged: {
        if (open && launcherLoader.item)
            Qt.callLater(() => launcherLoader.item.forceActiveFocus());
    }

    StyledRect {
        id: menuCard

        variant: "popup"
        enableShadow: true
        radius: Styling.radius(8)
        visible: root.open && launcherLoader.item !== null
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.96
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
            active: root.open
            sourceComponent: Component {
                LauncherView {}
            }

            onLoaded: Qt.callLater(() => item.forceActiveFocus())
        }
    }
}
