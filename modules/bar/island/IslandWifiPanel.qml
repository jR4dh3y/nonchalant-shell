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
        NetworkService.rescanWifi();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Header: Back button + Title + Actions (Globe, Settings, Rescan, Switch)
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
                text: "Wi-Fi"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
                elide: Text.ElideRight
            }

            // Status label (connecting or limited)
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                visible: NetworkService.wifiConnecting || NetworkService.wifiStatus === "limited"
                text: NetworkService.wifiConnecting ? "Connecting..." : (NetworkService.wifiStatus === "limited" ? "Limited" : "")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: NetworkService.wifiStatus === "limited" ? Colors.warning : Styling.srItem("overprimary")
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            // Action 1: Captive Portal (Globe)
            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: globeMouse.containsMouse ? "focus" : "common"
                enabled: NetworkService.wifiStatus === "limited"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.globe
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: NetworkService.wifiStatus === "limited" ? Styling.srItem("overprimary") : (globeMouse.containsMouse ? Colors.overBackground : Colors.overSurfaceVariant)
                }

                MouseArea {
                    id: globeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: NetworkService.wifiStatus === "limited" ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (NetworkService.wifiStatus === "limited") {
                            NetworkService.openPublicWifiPortal();
                        }
                    }
                }

                StyledToolTip {
                    show: globeMouse.containsMouse
                    tooltipText: "Open captive portal"
                }
            }

            // Action 2: Network Settings (popOpen / ↗)
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
                    onClicked: Quickshell.execDetached(["nm-connection-editor"])
                }

                StyledToolTip {
                    show: settingsMouse.containsMouse
                    tooltipText: "Network settings"
                }
            }

            // Action 3: Rescan networks (arrowsClockwise / 🔄)
            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: rescanMouse.containsMouse ? "focus" : "common"
                enabled: NetworkService.wifiEnabled

                Text {
                    id: rescanIcon
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowsClockwise
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: (NetworkService.wifiScanning || NetworkService.isUpdating) ? Styling.srItem("overprimary") : (NetworkService.wifiEnabled ? Colors.overBackground : Colors.outline)

                    RotationAnimation on rotation {
                        running: NetworkService.wifiScanning || NetworkService.isUpdating
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
                    cursorShape: NetworkService.wifiEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (NetworkService.wifiEnabled) {
                            NetworkService.rescanWifi();
                        }
                    }
                }

                StyledToolTip {
                    show: rescanMouse.containsMouse
                    tooltipText: "Rescan networks"
                }
            }

            // Action 4: Capsule Toggle Switch
            Item {
                id: toggleSwitch
                implicitWidth: 40
                implicitHeight: 22

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: NetworkService.wifiEnabled ? Styling.srItem("overprimary") : Colors.surfaceBright
                    border.color: NetworkService.wifiEnabled ? Styling.srItem("overprimary") : Colors.outline
                    border.width: 1

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation { duration: 150 }
                    }

                    Rectangle {
                        x: NetworkService.wifiEnabled ? parent.width - width - 2 : 2
                        y: 2
                        width: parent.height - 4
                        height: width
                        radius: width / 2
                        color: NetworkService.wifiEnabled ? Colors.background : Colors.overSurfaceVariant

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
                        const next = !NetworkService.wifiEnabled;
                        NetworkService.enableWifi(next);
                        if (next) {
                            NetworkService.rescanWifi();
                        }
                    }
                }
            }
        }

        // Wi-Fi network list
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: wifiList
                anchors.fill: parent
                clip: true
                spacing: 6
                model: NetworkService.friendlyWifiNetworks

                delegate: Item {
                    id: delegateRoot
                    required property var modelData
                    width: wifiList.width
                    height: networkItem.implicitHeight

                    WifiNetworkItem {
                        id: networkItem
                        width: parent.width
                        baseVariant: "internalbg"
                        network: delegateRoot.modelData
                    }
                }
            }

            // Empty state: no networks found or disabled
            Text {
                anchors.centerIn: parent
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                visible: wifiList.count === 0 && !NetworkService.wifiScanning
                text: NetworkService.wifiEnabled ? "No networks found" : "Wi-Fi is disabled"
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                color: Colors.overSurfaceVariant
            }

            // Scanning indicator when list is empty
            RowLayout {
                anchors.centerIn: parent
                visible: wifiList.count === 0 && NetworkService.wifiScanning
                spacing: 8

                Text {
                    text: Icons.arrowsClockwise
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: Styling.srItem("overprimary")

                    RotationAnimation on rotation {
                        running: NetworkService.wifiScanning
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }

                Text {
                    text: "Scanning for networks..."
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    color: Colors.overSurfaceVariant
                }
            }
        }
    }
}
