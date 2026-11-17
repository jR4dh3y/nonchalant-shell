pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import qs.config

Item {
    id: root

    property Item bar: null
    property bool isHovered: false
    property bool layerEnabled: false
    property bool flat: false
    property bool showMeter: true
    property int meterSize: 36

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Popup visibility state
    property bool popupOpen: batteryPopup.isOpen
    property bool usePopup: true

    signal activated

    // Function to interpolate color between green and red based on battery percentage
    function getBatteryColor() {
        return Battery.statusColor();
    }

    Layout.preferredWidth: meterSize
    Layout.preferredHeight: meterSize
    Layout.fillHeight: !flat
    Layout.alignment: Qt.AlignVCenter

    implicitWidth: meterSize
    implicitHeight: meterSize

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // Main button with circular progress
    StyledRect {
        id: buttonBg
        variant: root.flat ? "transparent" : (root.popupOpen ? "primary" : "bg")
        anchors.fill: parent
        enableShadow: !root.flat && root.layerEnabled
        enableBorder: !root.flat

        topLeftRadius: root.flat ? Styling.pillRadius(root.meterSize) : root.startRadius
        topRightRadius: root.flat ? Styling.pillRadius(root.meterSize) : root.endRadius
        bottomLeftRadius: root.flat ? Styling.pillRadius(root.meterSize) : root.startRadius
        bottomRightRadius: root.flat ? Styling.pillRadius(root.meterSize) : root.endRadius
        scale: mainBatMouse.pressed ? 0.92 : 1.0

        PressBehavior on scale {
            pressed: mainBatMouse.pressed
        }

        // Background highlight on hover
        HoverTint {
            hovered: root.isHovered && !root.popupOpen
            hoverOpacity: root.flat ? 0.12 : 0.25
        }

        // Battery meter; shares the radial meter so it follows roundness.
        BarRadialMeter {
            id: progressMeter
            anchors.centerIn: parent
            width: controlSize
            height: controlSize
            visible: Battery.available && root.showMeter
            controlSize: root.flat ? (root.meterSize - 2) : 32
            meterRadius: root.flat ? (root.meterSize / 2 - 4.5) : 12
            lineWidth: root.flat ? 2.2 : 3
            cornerRadius: root.flat
                ? Math.max(0, Styling.pillRadius(root.meterSize) - (root.meterSize / 2 - meterRadius))
                : Math.max(0, Math.min(root.startRadius, root.endRadius) - (root.meterSize / 2 - meterRadius))
            startAngle: 135
            spanAngle: 270
            value: Battery.percentage / 100
            trackColor: root.flat ? Qt.rgba(1, 1, 1, 0.14) : Colors.outlineVariant
            progressColor: root.getBatteryColor()
        }

        // Central icon (Lightning/Plug for battery, PowerProfile icon otherwise)
        StyledText {
            id: batteryIcon
            anchors.centerIn: parent
            text: !root.showMeter && Battery.available ? Battery.getBatteryIcon() : Battery.available ? (Battery.isPluggedIn ? Icons.plug : Icons.lightning) : PowerProfile.getProfileIcon(PowerProfile.currentProfile)
            font.family: Icons.font
            font.pixelSize: !root.showMeter ? Styling.fontSize(4) : root.flat ? (Battery.available ? 11 : 14) : (Battery.available ? 14 : 18)
            color: root.popupOpen ? buttonBg.item : Colors.overBackground

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        MouseArea {
            id: mainBatMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.activated();
                if (root.usePopup)
                    batteryPopup.toggle();
            }
        }

        StyledToolTip {
            show: root.isHovered && !root.popupOpen
            tooltipText: Battery.available ? ("Battery: " + Math.round(Battery.percentage) + "%" + (Battery.isCharging ? " (Charging)" : "")) : ("Power Profile: " + PowerProfile.getProfileDisplayName(PowerProfile.currentProfile))
        }
    }

    // Battery popup with Power Profiles
    BarPopup {
        id: batteryPopup
        anchorItem: buttonBg
        edgeItem: root.bar?.barHitbox ?? anchorItem
        contentVariant: "pane"

        contentWidth: Math.max(280, mainColumn.implicitWidth + batteryPopup.popupPadding * 2)
        // Fixed height calculation to prevent expansion animation on first open
        // Battery details (60px) + spacing (4px) + Profiles (36px)
        contentHeight: (Battery.available ? 64 : 0) + 36 + batteryPopup.popupPadding * 2

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            spacing: 4

            StyledRect {
                id: batteryDetailsContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                visible: Battery.available
                variant: "common"
                enableShadow: false

                radius: Styling.radius(0)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: 12

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Battery.getBatteryIcon()
                        font.family: Icons.font
                        font.pixelSize: 24
                        color: root.getBatteryColor()
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: Battery.isPluggedIn ? (Battery.isCharging ? "Charging" : "Full") : "On battery"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.overBackground
                        }

                        StyledText {
                            text: Battery.isPluggedIn ? (Battery.timeToFull !== "" ? "Full in " + Battery.timeToFull : "Fully charged") : (Battery.timeToEmpty !== "" ? Battery.timeToEmpty + " remaining" : "")
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            opacity: 0.8
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    // Battery percentage display
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Math.round(Battery.percentage) + "%"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(2)
                        font.bold: true
                        color: root.getBatteryColor()
                        opacity: 0.8
                    }
                }
            }

            RowLayout {
                id: profilesRow
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Repeater {
                    model: PowerProfile.availableProfiles

                    delegate: StyledRect {
                        id: profileButton
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredWidth: 80
                        height: 36

                        readonly property bool isSelected: PowerProfile.currentProfile === modelData
                        readonly property bool isFirst: index === 0
                        readonly property bool isLast: index === PowerProfile.availableProfiles.length - 1
                        property bool buttonHovered: false
                        property bool buttonPressed: false

                        readonly property real defaultRadius: Styling.radius(0)
                        readonly property real selectedRadius: Styling.radius(0) / 2

                        variant: isSelected ? "primary" : (buttonHovered ? "focus" : "common")
                        enableShadow: false
                        scale: buttonPressed ? 0.93 : 1.0

                        PressBehavior on scale {
                            pressed: profileButton.buttonPressed
                        }

                        topLeftRadius: isSelected ? (isFirst ? defaultRadius : selectedRadius) : defaultRadius
                        bottomLeftRadius: isSelected ? (isFirst ? defaultRadius : selectedRadius) : defaultRadius
                        topRightRadius: isSelected ? (isLast ? defaultRadius : selectedRadius) : defaultRadius
                        bottomRightRadius: isSelected ? (isLast ? defaultRadius : selectedRadius) : defaultRadius

                        StyledText {
                            anchors.centerIn: parent
                            text: PowerProfile.getProfileIcon(profileButton.modelData)
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: profileButton.item
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onPressed: profileButton.buttonPressed = true
                            onReleased: profileButton.buttonPressed = false
                            onCanceled: profileButton.buttonPressed = false
                            onEntered: profileButton.buttonHovered = true
                            onExited: profileButton.buttonHovered = false

                            onClicked: {
                                PowerProfile.setProfile(profileButton.modelData);
                            }
                        }

                        StyledToolTip {
                            show: profileButton.buttonHovered
                            tooltipText: PowerProfile.getProfileDisplayName(profileButton.modelData)
                        }
                    }
                }
            }
        }
    }
}
