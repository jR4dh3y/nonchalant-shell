import QtQuick
import qs.config
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.dashboard.metrics

ToggleButton {
    id: root

    required property var bar
    readonly property bool popupOpen: monitorPopup.isOpen

    buttonIcon: Icons.circuitry
    tooltipText: "System Monitor"
    onToggle: function () { root.togglePopup(); }

    function togglePopup() {
        if (monitorPopup.isOpen) {
            monitorPopup.close();
        } else {
            Visibilities.setActiveModule("");
            metricsLoader.active = true;
            Qt.callLater(() => monitorPopup.open());
        }
    }

    // Match app launcher / project picker content inset.
    readonly property int contentPadding: Math.max(Styling.radius(3), 12)

    BarPopup {
        id: monitorPopup
        anchorItem: root
        bar: root.bar
        variant: "transparent"
        popupPadding: 0

        contentWidth: monitorWrapper.width
        contentHeight: monitorWrapper.height

        onIsOpenChanged: {
            const screenName = root.bar?.screen?.name ?? "";
            if (isOpen) {
                GlobalStates.systemMonitorPopupScreen = screenName;
            } else if (GlobalStates.systemMonitorPopupScreen === screenName) {
                GlobalStates.systemMonitorPopupScreen = "";
            }
        }

        StyledRect {
            id: monitorWrapper
            variant: "popup"
            radius: Styling.radius(8)
            enableShadow: false
            width: metricsLoader.item ? metricsLoader.item.implicitWidth + root.contentPadding * 2 : 0
            height: metricsLoader.item ? metricsLoader.item.implicitHeight + root.contentPadding * 2 : 0

            Loader {
                id: metricsLoader
                active: false
                anchors.fill: parent
                anchors.margins: root.contentPadding

                sourceComponent: Component {
                    MetricsTab {
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                monitorPopup.close();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onDestruction: {
        const screenName = root.bar?.screen?.name ?? "";
        if (screenName)
            Visibilities.unregisterSystemMonitorButton(screenName, root);
        if (GlobalStates.systemMonitorPopupScreen === screenName)
            GlobalStates.systemMonitorPopupScreen = "";
    }

    Component.onCompleted: {
        const screenName = root.bar?.screen?.name ?? "";
        if (screenName)
            Visibilities.registerSystemMonitorButton(screenName, root);
    }
}
