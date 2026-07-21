import QtQuick
import qs.config
import qs.modules.components
import qs.modules.theme
import qs.modules.services

ToggleButton {
    id: powerButton

    required property var bar
    readonly property bool popupOpen: powerPopup.isOpen

    buttonIcon: Icons.shutdown
    tooltipText: "Power Menu"
    onToggle: function () { powerButton.togglePopup(); }

    function togglePopup() {
        if (powerPopup.isOpen) {
            powerPopup.close();
        } else {
            Visibilities.setActiveModule("");
            powerPopup.open();
        }
    }

    // Soft open-state wash on the bar pill.
    Rectangle {
        anchors.fill: parent
        z: 1
        radius: parent.height / 2
        color: Styling.srItem("overprimary")
        opacity: powerButton.popupOpen ? 0.22 : 0
        enabled: false
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    BarPopup {
        id: powerPopup
        anchorItem: powerButton
        bar: powerButton.bar
        variant: "transparent"
        popupPadding: 0
        shadowMargin: 8
        visualMargin: 10

        anchor.rect.x: {
            if (powerPopup.barVertical) {
                if (powerPopup.barAtLeft)
                    return powerButton.width + powerPopup.visualMargin + powerPopup.effectiveFrameOffset;
                return -powerPopup.totalWidth - powerPopup.visualMargin - powerPopup.effectiveFrameOffset;
            }
            return (powerButton.width - powerPopup.totalWidth) / 2;
        }

        contentWidth: powerMenuView.implicitWidth
        contentHeight: powerMenuView.implicitHeight

        PowerMenuView {
            id: powerMenuView
            anchors.fill: parent
            popupMode: true
            expanded: powerPopup.isOpen
            onCloseRequested: powerPopup.close()
        }
    }

    Component.onCompleted: {
        const screenName = powerButton.bar?.screen?.name ?? "";
        if (screenName)
            Visibilities.registerPowerMenuButton(screenName, powerButton);
    }

    Component.onDestruction: {
        const screenName = powerButton.bar?.screen?.name ?? "";
        if (screenName)
            Visibilities.unregisterPowerMenuButton(screenName, powerButton);
    }
}
