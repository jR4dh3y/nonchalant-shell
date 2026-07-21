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

    signal closeRequested()

    // Height tracks action count; keep transitions short so open feels instant.
    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutCubic
        }
    }

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutCubic
        }
    }

    PowerMenu {
        id: powerMenu
        anchors.fill: parent
        expanded: root.expanded
        
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
    
    // Forzar foco cuando aparece la vista en el StackView
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => {
                powerMenu.forceActiveFocus();
            });
        }
    }
    
    Component.onCompleted: {
        if (visible) {
            Qt.callLater(() => {
                powerMenu.forceActiveFocus();
            });
        }
    }
}
