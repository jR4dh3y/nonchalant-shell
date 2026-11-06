pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    // Hosts may keep this panel loaded while hidden; refresh the device list
    // each time it is shown. BluetoothDeviceList owns discovery.
    onVisibleChanged: {
        if (visible)
            updateTimer.restart();
        else
            updateTimer.stop();
    }
    Component.onCompleted: {
        if (visible)
            updateTimer.restart();
    }

    Timer {
        id: updateTimer
        interval: Motion.expandDuration
        onTriggered: {
            if (BluetoothService.enabled)
                BluetoothService.updateDevices();
        }
    }

    // Device list - fills entire width for scroll/drag
    BluetoothDeviceList {
        id: deviceList
        anchors.fill: parent
        itemWidth: root.contentWidth

        header: Item {
            width: deviceList.width
            height: titlebar.height + 8

            PanelTitlebar {
                id: titlebar
                width: root.contentWidth
                anchors.horizontalCenter: parent.horizontalCenter
                title: "Bluetooth"
                showToggle: true
                toggleChecked: BluetoothService.enabled

                actions: [
                    {
                        icon: Icons.popOpen,
                        tooltip: "Open Blueman",
                        onClicked: function () {
                            Quickshell.execDetached(["blueman-manager"]);
                        }
                    },
                    {
                        icon: Icons.sync,
                        tooltip: "Scan for devices",
                        enabled: BluetoothService.enabled,
                        loading: BluetoothService.discovering || BluetoothService.isUpdating,
                        onClicked: function () {
                            BluetoothService.startDiscovery();
                        }
                    }
                ]

                onToggleChanged: checked => {
                    BluetoothService.setEnabled(checked);
                    if (checked) {
                        BluetoothService.startDiscovery();
                    }
                }
            }
        }
    }
}
