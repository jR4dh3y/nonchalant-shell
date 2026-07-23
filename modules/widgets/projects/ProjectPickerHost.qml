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
    readonly property bool open: screenVisibilities ? screenVisibilities.projects : false
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

    property bool menuShown: false
    property real menuOpacity: 0

    onOpenChanged: {
        if (open) {
            closeTimer.stop();
            menuShown = true;
            ProjectPickerService.refresh();
            Qt.callLater(() => {
                if (!root.open)
                    return;
                menuOpacity = 1;
                if (pickerLoader.item)
                    pickerLoader.item.forceActiveFocus();
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
        width: pickerLoader.item ? pickerLoader.item.implicitWidth + root.contentPadding * 2 : 0
        height: pickerLoader.item ? pickerLoader.item.implicitHeight + root.contentPadding * 2 : 0
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

        Loader {
            id: pickerLoader
            anchors.fill: parent
            anchors.margins: root.contentPadding
            active: true
            sourceComponent: Component {
                ProjectPickerView {}
            }

            onLoaded: {
                if (root.open)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }
    }
}
