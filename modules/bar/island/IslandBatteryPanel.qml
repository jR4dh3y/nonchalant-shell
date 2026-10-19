pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.UPower as UPowerService
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    implicitWidth: 420
    implicitHeight: Math.max(340, mainColumn.implicitHeight + 28)

    property string backTooltip: "Back to dashboard"
    property bool showBackButton: true
    property Component titleComponent: defaultTitle
    // Health is reported by the physical battery, not the aggregate display device.
    readonly property UPowerService.UPowerDevice healthDevice: UPowerService.UPower.devices.values.find(device => device.isLaptopBattery && device.healthSupported) ?? null
    readonly property list<string> profileModes: ["power-saver", "balanced", "performance"]
    property Item selectedProfileTab: null
    signal backRequested()

    function updateSelectedProfileTab(): void {
        root.selectedProfileTab = profileRepeater?.itemAt(root.profileModes.indexOf(PowerProfile.currentProfile)) ?? null;
    }

    Connections {
        target: PowerProfile
        function onCurrentProfileChanged(): void { root.updateSelectedProfileTab(); }
    }

    function getBatteryColor(): color {
        if (!Battery.available) return Colors.overBackground;
        const pct = Battery.percentage;
        if (pct <= 20) return Colors.red;
        if (pct <= 50) return Colors.yellow;
        return Colors.green;
    }

    Component {
        id: defaultTitle
        StyledText {
            text: "Battery & Power"
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(1)
            font.bold: true
            color: Colors.overBackground
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 12

        // Header: Back button + Title + Live Status Pill
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledRect {
                visible: root.showBackButton
                objectName: "batteryBackButton"
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: backMouse.containsMouse ? "focus" : "common"
                scale: backMouse.pressed ? 0.92 : 1.0

                PressBehavior on scale {
                    pressed: backMouse.pressed
                }

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
                    tooltipText: root.backTooltip
                }
            }

            Loader {
                sourceComponent: root.titleComponent
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

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: Battery.available ? Math.round(Battery.percentage) + "%" : "AC Power"
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(3)
                            font.bold: true
                            color: Colors.overBackground
                        }

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: {
                                if (!Battery.available) return "System is running on direct AC power";
                                if (Battery.isCharging) {
                                    return Battery.timeToFull !== "" ? "Full in " + Battery.timeToFull : "Charging...";
                                }
                                if (Battery.isPluggedIn) return "Fully charged";
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

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Styling.fontSize(0) * 4
            radius: Styling.radius(2)
            variant: "internalbg"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    StyledText {
                        text: Battery.isCharging ? "Charge rate" : "Power draw"
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                    }
                    StyledText {
                        objectName: "batteryPowerRate"
                        text: Battery.available ? Math.abs(Battery.primaryDevice.changeRate).toFixed(1) + " W" : "Unavailable"
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(1)
                        color: Colors.overBackground
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    StyledText {
                        text: "Battery health"
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                    }
                    StyledText {
                        objectName: "batteryHealth"
                        text: root.healthDevice ? Math.round(root.healthDevice.healthPercentage) + "%" : "Unavailable"
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(1)
                        color: Colors.overBackground
                    }
                }
            }
        }

        // Power Profile Selector Card
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: profileColumn.implicitHeight + 20
            radius: Styling.radius(2)
            variant: "internalbg"

            ColumnLayout {
                id: profileColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                StyledText {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: "POWER PROFILE"
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-3)
                    font.bold: true
                    color: Colors.overSurfaceVariant
                }

                StyledRect {
                    id: profileSelector
                    objectName: "powerProfileSelector"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Styling.fontSize(0) * 3
                    variant: "focus"
                    radius: height / 2
                    readonly property real inset: Styling.fontSize(-4) * 0.4

                    ElasticHighlight {
                        id: profileHighlight
                        objectName: "powerProfileHighlight"
                        targetItem: root.selectedProfileTab
                        originX: profileTabs.x
                        originY: profileTabs.y
                        radius: height / 2
                        scale: targetItem?.scale ?? 1
                    }

                    Row {
                        id: profileTabs
                        anchors.fill: parent
                        anchors.margins: profileSelector.inset

                        Repeater {
                            id: profileRepeater
                            model: root.profileModes
                            onItemAdded: root.updateSelectedProfileTab()
                            onItemRemoved: root.updateSelectedProfileTab()

                            Button {
                                id: profileButton
                                required property string modelData
                                readonly property bool selected: PowerProfile.currentProfile === modelData
                                objectName: "powerProfileTab-" + modelData
                                width: profileTabs.width / root.profileModes.length
                                height: profileTabs.height
                                padding: Styling.fontSize(-4) * 0.6
                                enabled: PowerProfile.isAvailable && PowerProfile.availableProfiles.indexOf(modelData) !== -1
                                Accessible.name: modelData === "power-saver" ? "Power Saver" : PowerProfile.getProfileDisplayName(modelData)
                                Accessible.role: Accessible.RadioButton
                                Accessible.checked: selected
                                scale: pressed ? 0.94 : 1
                                PressBehavior on scale { pressed: profileButton.pressed }
                                background: StyledRect {
                                    variant: "focus"
                                    backgroundOpacity: 0
                                    radius: height / 2
                                    border.width: profileButton.visualFocus ? Math.max(1, Math.round(Styling.fontSize(-4) / 8)) : 0
                                    border.color: Colors.primary
                                    HoverTint {
                                        hovered: profileButton.hovered && !profileButton.selected
                                        pressed: profileButton.pressed
                                        hoverOpacity: 0.08
                                        pressedOpacity: 0.12
                                    }
                                }
                                contentItem: Item {
                                    RowLayout {
                                        anchors.centerIn: parent
                                        width: Math.min(implicitWidth, parent.width)
                                        spacing: Styling.fontSize(-4) * 0.5
                                        StyledText {
                                            text: PowerProfile.getProfileIcon(profileButton.modelData)
                                            font.family: Icons.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            color: profileButton.selected ? profileHighlight.item : Colors.overBackground
                                        }
                                        StyledText {
                                            id: profileLabel
                                            Layout.fillWidth: true
                                            text: profileButton.Accessible.name
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-2)
                                            font.weight: Font.Medium
                                            color: profileButton.selected ? profileHighlight.item : Colors.overBackground
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                                onClicked: if (!selected) PowerProfile.setProfile(profileButton.modelData)
                                StyledToolTip {
                                    show: profileButton.hovered && profileLabel.truncated
                                    tooltipText: profileButton.Accessible.name
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
