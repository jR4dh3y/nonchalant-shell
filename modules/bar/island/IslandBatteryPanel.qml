pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    implicitWidth: 480
    implicitHeight: mainColumn.implicitHeight + 28

    signal backRequested()

    function getBatteryColor(): color {
        if (!Battery.available) return Colors.overBackground;
        const pct = Battery.percentage;
        if (pct <= 20) return Colors.red;
        if (pct <= 50) return Colors.yellow;
        return Colors.green;
    }

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Header: Back button + Title + Live Status Pill
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

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
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Battery & Power"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
            }

            Item { Layout.fillWidth: true }

            // Live status badge
            StyledRect {
                implicitWidth: statusRow.implicitWidth + 14
                implicitHeight: 22
                radius: 11
                variant: Battery.isCharging ? "primary" : "common"

                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Battery.available
                            ? (Battery.isCharging ? "CHARGING" : (Battery.isPluggedIn ? "PLUGGED IN" : "ON BATTERY"))
                            : "AC POWER"
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-4)
                        font.bold: true
                        color: Battery.isCharging ? Colors.overPrimary : Colors.overBackground
                    }
                }
            }
        }

        // 1. Primary Battery Overview Card
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            radius: Styling.radius(2)
            variant: "internalbg"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Big Battery Icon
                    StyledRect {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: 22
                        variant: "common"

                        Text {
                            anchors.centerIn: parent
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: Battery.available ? Battery.getBatteryIcon() : Icons.lightning
                            font.family: Icons.font
                            font.pixelSize: 22
                            color: root.getBatteryColor()
                        }
                    }

                    // Percentage and Status Text
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 8

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: Battery.available ? Math.round(Battery.percentage) + "%" : "AC Power"
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(3)
                                font.bold: true
                                color: Colors.overBackground
                            }

                            StyledRect {
                                visible: Battery.available
                                implicitWidth: stateText.implicitWidth + 10
                                implicitHeight: 18
                                radius: 9
                                variant: Battery.isCharging ? "primary" : "common"

                                Text {
                                    id: stateText
                                    anchors.centerIn: parent
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    text: Battery.isCharging ? "Charging" : (Battery.isPluggedIn ? "Full" : "Discharging")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-4)
                                    font.bold: true
                                    color: Battery.isCharging ? Colors.overPrimary : Colors.overBackground
                                }
                            }
                        }

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: {
                                if (!Battery.available) return "System is running on direct AC power";
                                if (Battery.isCharging) {
                                    return Battery.timeToFull !== "" ? "Full in " + Battery.timeToFull : "Charging...";
                                }
                                if (Battery.isPluggedIn) return "Fully charged • Plugged in";
                                return Battery.timeToEmpty !== "" ? Battery.timeToEmpty + " remaining" : "Estimating time remaining...";
                            }
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overSurfaceVariant
                        }
                    }
                }

                // Battery progress bar gauge
                StyledRect {
                    visible: Battery.available
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    variant: "common"

                    StyledRect {
                        width: Math.max(6, Math.min(parent.width, parent.width * (Battery.percentage / 100)))
                        height: parent.height
                        radius: 3
                        variant: Battery.percentage <= 20 ? "error" : "primary"

                        Behavior on width {
                            enabled: Config.animDuration > 0
                            NumberAnimation { duration: 250 }
                        }
                    }
                }
            }
        }

        // 2. Power Profile Selector Card
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: Styling.radius(2)
            variant: "internalbg"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: "POWER PROFILE"
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-3)
                    font.bold: true
                    color: Colors.overSurfaceVariant
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // 1. Performance
                    StyledRect {
                        id: perfBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: Styling.radius(1)
                        variant: PowerProfile.currentProfile === "performance" ? "primary" : (perfMouse.containsMouse ? "focus" : "common")

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: Icons.performance
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: PowerProfile.currentProfile === "performance" ? Colors.overPrimary : Colors.overBackground
                            }

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: "Performance"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: PowerProfile.currentProfile === "performance"
                                color: PowerProfile.currentProfile === "performance" ? Colors.overPrimary : Colors.overBackground
                            }
                        }

                        MouseArea {
                            id: perfMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfile.setProfile("performance")
                        }
                    }

                    // 2. Balanced
                    StyledRect {
                        id: balBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: Styling.radius(1)
                        variant: PowerProfile.currentProfile === "balanced" ? "primary" : (balMouse.containsMouse ? "focus" : "common")

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: Icons.balanced
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: PowerProfile.currentProfile === "balanced" ? Colors.overPrimary : Colors.overBackground
                            }

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: "Balanced"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: PowerProfile.currentProfile === "balanced"
                                color: PowerProfile.currentProfile === "balanced" ? Colors.overPrimary : Colors.overBackground
                            }
                        }

                        MouseArea {
                            id: balMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfile.setProfile("balanced")
                        }
                    }

                    // 3. Power Saver
                    StyledRect {
                        id: saverBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: Styling.radius(1)
                        variant: PowerProfile.currentProfile === "power-saver" ? "primary" : (saverMouse.containsMouse ? "focus" : "common")

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: Icons.powerSave
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: PowerProfile.currentProfile === "power-saver" ? Colors.overPrimary : Colors.overBackground
                            }

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: "Power Saver"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: PowerProfile.currentProfile === "power-saver"
                                color: PowerProfile.currentProfile === "power-saver" ? Colors.overPrimary : Colors.overBackground
                            }
                        }

                        MouseArea {
                            id: saverMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfile.setProfile("power-saver")
                        }
                    }
                }
            }
        }
    }
}
