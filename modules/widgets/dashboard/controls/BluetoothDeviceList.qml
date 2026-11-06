pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Bluetooth device list shared by the dashboard and island panels.
// "My devices" lists paired devices; "Available devices" lists what discovery
// found nearby, ready to pair. The list scans while it is shown and stops the
// scan when hidden, so every surface that opens it can pair new devices.
ListView {
    id: root

    // Width of each row; rows are centered when narrower than the list.
    property int itemWidth: width
    property string itemVariant: "common"

    readonly property bool hasPaired: BluetoothService.pairedDeviceList.length > 0
    readonly property bool hasAvailable: BluetoothService.availableDeviceList.length > 0

    function scanIfShown(): void {
        if (root.visible && BluetoothService.enabled)
            scanDelay.restart();
    }

    clip: true
    spacing: 4
    cacheBuffer: 1000
    model: BluetoothService.friendlyDeviceList

    onVisibleChanged: {
        if (visible) {
            root.scanIfShown();
        } else {
            scanDelay.stop();
            BluetoothService.stopDiscovery();
        }
    }
    Component.onCompleted: root.scanIfShown()
    Component.onDestruction: BluetoothService.stopDiscovery()

    Connections {
        target: BluetoothService
        function onEnabledChanged() {
            root.scanIfShown();
        }
    }

    // Let the host's reveal animation settle before bluetoothctl starts.
    Timer {
        id: scanDelay
        interval: Motion.expandDuration
        onTriggered: {
            if (root.visible && BluetoothService.enabled && !BluetoothService.discovering)
                BluetoothService.startDiscovery();
        }
    }

    component SectionLabel: StyledText {
        text: ""
        font.pixelSize: Styling.fontSize(-2)
        font.weight: Font.DemiBold
        color: Colors.overSurfaceVariant
        leftPadding: 4
        topPadding: 6
        bottomPadding: 2
    }

    delegate: Item {
        id: row

        required property BluetoothDevice modelData
        required property int index

        // friendlyDeviceList is sorted paired-first, so a section starts at the
        // first row and wherever paired state flips.
        readonly property bool startsSection: index === 0
            || (BluetoothService.friendlyDeviceList[index - 1]?.paired ?? !modelData.paired) !== modelData.paired

        width: root.width
        height: rowColumn.implicitHeight

        ColumnLayout {
            id: rowColumn

            width: root.itemWidth
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                visible: row.startsSection

                SectionLabel {
                    Layout.fillWidth: true
                    text: row.modelData.paired ? "My devices" : "Available devices"
                }

                SectionLabel {
                    visible: !row.modelData.paired && BluetoothService.discovering
                    text: "Scanning…"
                    color: Styling.srItem("overprimary")
                    rightPadding: 4
                }
            }

            BluetoothDeviceItem {
                Layout.fillWidth: true
                baseVariant: root.itemVariant
                device: row.modelData
            }
        }
    }

    // While nothing new has been found, the footer keeps the "Available
    // devices" section visible with its scan state and a way to scan again.
    footer: Item {
        width: root.width
        height: BluetoothService.enabled && !root.hasAvailable ? footerColumn.implicitHeight + 4 : 0
        visible: height > 0

        ColumnLayout {
            id: footerColumn

            width: root.itemWidth
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 4

            SectionLabel {
                Layout.fillWidth: true
                text: "Available devices"
            }

            StyledRect {
                id: scanRow

                Layout.fillWidth: true
                Layout.preferredHeight: 48
                variant: scanMouse.containsMouse && !BluetoothService.discovering ? "focus" : root.itemVariant
                radius: Styling.radius(4)
                scale: scanMouse.pressed ? 0.98 : 1.0

                PressBehavior on scale {
                    pressed: scanMouse.pressed
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Text {
                        text: Icons.arrowsClockwise
                        font.family: Icons.font
                        font.pixelSize: 18
                        color: BluetoothService.discovering ? Styling.srItem("overprimary") : Colors.overBackground

                        RotationAnimation on rotation {
                            running: BluetoothService.discovering
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            onRunningChanged: {
                                if (!running)
                                    parent.rotation = 0;
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: BluetoothService.discovering
                            ? "Searching for nearby devices… Put your device in pairing mode."
                            : "No new devices found. Click to scan again."
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: scanMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !BluetoothService.discovering
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BluetoothService.startDiscovery()
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: !BluetoothService.enabled && root.count === 0
        text: "Bluetooth is disabled"
        color: Colors.overSurfaceVariant
    }
}
