import QtQuick
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    implicitWidth: powerMenu.implicitWidth
    implicitHeight: powerMenu.implicitHeight
    property bool popupMode: false

    signal closeRequested()

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
