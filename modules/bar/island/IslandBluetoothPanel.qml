pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.widgets.dashboard.controls
import qs.config

Item {
    id: root

    implicitWidth: 400
    implicitHeight: 340

    signal backRequested()

    Component.onCompleted: {
        BluetoothService.updateStatus();
        initialUpdateTimer.start();
    }

    Timer {
        id: initialUpdateTimer
        interval: 300
        repeat: false
        onTriggered: BluetoothService.updateDevices()
    }

    Component.onDestruction: {
        BluetoothService.stopDiscovery();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Header: Back button + Title + Actions (Settings, Rescan, Switch)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Back button
            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: backMouse.containsMouse ? "focus" : "common"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowLeft
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: Colors.overBackground
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }

                StyledToolTip {
                    show: backMouse.containsMouse
                    tooltipText: "Back to dashboard"
                }
            }

            // Title
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Bluetooth"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
                elide: Text.ElideRight
            }

            // Scanning status
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                visible: BluetoothService.discovering
                text: "Scanning..."
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Styling.srItem("overprimary")
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            // Action 1: Open Blueman Manager (popOpen / ↗)
            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: settingsMouse.containsMouse ? "focus" : "common"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.popOpen
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: Colors.overBackground
                }

                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["blueman-manager"])
                }

                StyledToolTip {
                    show: settingsMouse.containsMouse
                    tooltipText: "Open Blueman"
                }
            }

            // Action 2: Rescan / Scan for devices (arrowsClockwise / 🔄)
            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: rescanMouse.containsMouse ? "focus" : "common"
                enabled: BluetoothService.enabled

                Text {
                    id: rescanIcon
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowsClockwise
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: (BluetoothService.discovering || BluetoothService.isUpdating) ? Styling.srItem("overprimary") : (BluetoothService.enabled ? Colors.overBackground : Colors.outline)

                    RotationAnimation on rotation {
                        running: BluetoothService.discovering || BluetoothService.isUpdating
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }

                MouseArea {
                    id: rescanMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: BluetoothService.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (BluetoothService.enabled) {
                            BluetoothService.startDiscovery();
                        }
                    }
                }

                StyledToolTip {
                    show: rescanMouse.containsMouse
                    tooltipText: "Scan for devices"
                }
            }

            // Action 3: Capsule Toggle Switch
            Item {
                id: toggleSwitch
                implicitWidth: 40
                implicitHeight: 22

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: BluetoothService.enabled ? Styling.srItem("overprimary") : Colors.surfaceBright
                    border.color: BluetoothService.enabled ? Styling.srItem("overprimary") : Colors.outline
                    border.width: 1

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation { duration: 150 }
                    }

                    Rectangle {
                        x: BluetoothService.enabled ? parent.width - width - 2 : 2
                        y: 2
                        width: parent.height - 4
                        height: width
                        radius: width / 2
                        color: BluetoothService.enabled ? Colors.background : Colors.overSurfaceVariant

                        Behavior on x {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const newState = !BluetoothService.enabled;
                        BluetoothService.setEnabled(newState);
                        if (newState) {
                            BluetoothService.startDiscovery();
                        }
                    }
                }
            }
        }

        // Bluetooth device list
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: deviceList
                anchors.fill: parent
                clip: true
                spacing: 6
                model: BluetoothService.friendlyDeviceList

                delegate: Item {
                    id: delegateRoot
                    required property var modelData
                    width: deviceList.width
                    height: deviceItem.implicitHeight

                    BluetoothDeviceItem {
                        id: deviceItem
                        width: parent.width
                        baseVariant: "internalbg"
                        device: delegateRoot.modelData
                    }
                }
            }

            // Empty state: no devices found or disabled
            Text {
                anchors.centerIn: parent
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                visible: deviceList.count === 0 && !BluetoothService.discovering
                text: BluetoothService.enabled ? "No devices found" : "Bluetooth is disabled"
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                color: Colors.overSurfaceVariant
            }

            // Scanning indicator when list is empty
            RowLayout {
                anchors.centerIn: parent
                visible: deviceList.count === 0 && BluetoothService.discovering
                spacing: 8

                Text {
                    text: Icons.arrowsClockwise
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: Styling.srItem("overprimary")

                    RotationAnimation on rotation {
                        running: BluetoothService.discovering
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }

                Text {
                    text: "Scanning for devices..."
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    color: Colors.overSurfaceVariant
                }
            }
        }
    }
}
