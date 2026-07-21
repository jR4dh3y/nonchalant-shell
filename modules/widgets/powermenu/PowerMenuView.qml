import QtQuick
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    implicitWidth: powerMenu.implicitWidth
    implicitHeight: powerMenu.implicitHeight
    property bool popupMode: false
    property bool expanded: true
    focus: true

    signal closeRequested()

    function focusMenu() {
        powerMenu.currentIndex = 0;
        powerMenu.forceActiveFocus();
    }

    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    PowerMenu {
        id: powerMenu
        anchors.fill: parent

        onItemSelected: {
            if (root.popupMode)
                root.closeRequested();
            else
                Visibilities.setActiveModule("");
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && root.popupMode) {
            root.closeRequested();
            event.accepted = true;
        }
    }

    onExpandedChanged: {
        if (expanded)
            Qt.callLater(() => root.focusMenu());
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => root.focusMenu());
    }

    Component.onCompleted: {
        if (visible)
            Qt.callLater(() => root.focusMenu());
    }
}
