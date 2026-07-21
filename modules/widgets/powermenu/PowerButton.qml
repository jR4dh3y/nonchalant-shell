import QtQuick
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

    BarPopup {
        id: powerPopup
        anchorItem: powerButton
        bar: powerButton.bar
        variant: "transparent"
        popupPadding: 0
        shadowMargin: 0
        anchor.rect.x: {
            if (powerPopup.barVertical) {
                if (powerPopup.barAtLeft)
                    return powerButton.width + powerPopup.visualMargin + powerPopup.effectiveFrameOffset;
                return -powerPopup.totalWidth - powerPopup.visualMargin - powerPopup.effectiveFrameOffset;
            }
            return powerButton.width - powerPopup.totalWidth;
        }

        contentWidth: powerMenuWrapper.width
        contentHeight: powerMenuWrapper.height

        StyledRect {
            id: powerMenuWrapper
            variant: "popup"
            radius: Styling.radius(8)
            enableShadow: false
            width: powerMenuView.implicitWidth + 12
            height: powerMenuView.implicitHeight + 12

            PowerMenuView {
                id: powerMenuView
                anchors.centerIn: parent
                popupMode: true
                onCloseRequested: powerPopup.close()
            }
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
