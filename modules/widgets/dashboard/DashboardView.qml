import QtQuick
import qs.modules.widgets.dashboard
import qs.modules.services

Item {
    id: root

    implicitWidth: 900
    implicitHeight: 56 + 48 * 6
    property string screenName: ""
    property bool popupMode: false

    signal closeRequested()

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

        Component.onCompleted: {
            Qt.callLater(() => {
                forceActiveFocus();
            });
        }
    }
}
