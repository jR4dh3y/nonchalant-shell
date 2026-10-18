import QtQuick
import qs.config
import qs.modules.globals
import qs.modules.widgets.dashboard
import qs.modules.services

Item {
    id: root

    implicitWidth: Config.bar?.style === "left" ? dashboardItem.implicitWidth : 900
    implicitHeight: Config.bar?.style === "left" ? dashboardItem.implicitHeight : 56 + 48 * 6
    property string screenName: ""
    property bool popupMode: false

    signal closeRequested()

    function focusCurrentTab() {
        dashboardItem.focusCurrentTab();
    }

    Timer {
        id: focusTimer
        interval: 0
        onTriggered: {
            if (root.visible)
                dashboardItem.focusCurrentTab();
        }
    }

    Dashboard {
        id: dashboardItem
        anchors.fill: parent
        screenName: root.screenName
        forceVisible: root.popupMode

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.popupMode) {
                    root.closeRequested();
                } else {
                    Visibilities.setActiveModule("");
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Space) {
                event.accepted = false;
            }
        }

        Component.onCompleted: focusTimer.restart()

        Connections {
            target: GlobalStates

            function onDashboardCurrentTabChanged() {
                if (!root.popupMode)
                    return;

                focusTimer.restart();
            }
        }
    }
}
