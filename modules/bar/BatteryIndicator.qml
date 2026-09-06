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

        topLeftRadius: root.flat ? (root.meterSize / 2) : root.startRadius
        topRightRadius: root.flat ? (root.meterSize / 2) : root.endRadius
        bottomLeftRadius: root.flat ? (root.meterSize / 2) : root.startRadius
        bottomRightRadius: root.flat ? (root.meterSize / 2) : root.endRadius

        // Background highlight on hover
        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.popupOpen ? 0 : (root.isHovered ? (root.flat ? 0.12 : 0.25) : 0)
            radius: root.flat ? (width / 2) : parent.topLeftRadius
            topLeftRadius: root.flat ? (width / 2) : parent.topLeftRadius
            topRightRadius: root.flat ? (width / 2) : parent.topRightRadius
            bottomLeftRadius: root.flat ? (width / 2) : parent.bottomLeftRadius
            bottomRightRadius: root.flat ? (width / 2) : parent.bottomRightRadius

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        // Circular progress indicator (only if battery available)
        Item {
            id: progressCanvas
            anchors.centerIn: parent
            width: root.flat ? (root.meterSize - 2) : 32
            height: width
            visible: Battery.available

            property real angle: (Battery.percentage / 100) * (360 - 2 * gapAngle)
            property real radius: root.flat ? (root.meterSize / 2 - 4.5) : 12
            property real lineWidth: root.flat ? 2.2 : 3
            property real gapAngle: 45

            Canvas {
                id: canvas
                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    let ctx = getContext("2d");
                    ctx.reset();

                    let centerX = width / 2;
                    let centerY = height / 2;
                    let radius = progressCanvas.radius;
                    let lineWidth = progressCanvas.lineWidth;

                    ctx.lineCap = "round";

                    // Base start angle (matching CircularControl: bottom + gap)
                    let baseStartAngle = (Math.PI / 2) + (progressCanvas.gapAngle * Math.PI / 180);
                    let progressAngleRad = progressCanvas.angle * Math.PI / 180;

                    // Draw background track (remaining part)
                    let totalAngleRad = (360 - 2 * progressCanvas.gapAngle) * Math.PI / 180;

                    ctx.strokeStyle = root.flat ? Qt.rgba(1, 1, 1, 0.14) : Colors.outlineVariant;
                    ctx.lineWidth = lineWidth;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, baseStartAngle + progressAngleRad, baseStartAngle + totalAngleRad, false);
                    ctx.stroke();

                    // Draw progress
                    if (progressCanvas.angle > 0) {
                        ctx.strokeStyle = root.getBatteryColor();
                        ctx.lineWidth = lineWidth;
                        ctx.beginPath();
                        ctx.arc(centerX, centerY, radius, baseStartAngle, baseStartAngle + progressAngleRad, false);
                        ctx.stroke();
                    }
                }

                Connections {
                    target: progressCanvas
                    function onAngleChanged() {
                        canvas.requestPaint();
                    }
                }

                Connections {
                    target: Battery
                    function onPercentageChanged() {
                        canvas.requestPaint();
                    }
                }
            }

            Behavior on angle {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Central icon (Lightning/Plug for battery, PowerProfile icon otherwise)
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            id: batteryIcon
            anchors.centerIn: parent
            text: Battery.available ? (Battery.isPluggedIn ? Icons.plug : Icons.lightning) : PowerProfile.getProfileIcon(PowerProfile.currentProfile)
            font.family: Icons.font
            font.pixelSize: root.flat ? (Battery.available ? 11 : 14) : (Battery.available ? 14 : 18)
            color: root.popupOpen ? buttonBg.item : Colors.overBackground

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.activated();
                if (root.usePopup)
                    batteryPopup.toggle();
            }
        }

        StyledToolTip {
            visible: root.isHovered && !root.popupOpen
            tooltipText: Battery.available ? ("Battery: " + Math.round(Battery.percentage) + "%" + (Battery.isCharging ? " (Charging)" : "")) : ("Power Profile: " + PowerProfile.getProfileDisplayName(PowerProfile.currentProfile))
        }
    }

    // Battery popup with Power Profiles
    BarPopup {
        id: batteryPopup
        anchorItem: buttonBg

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

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
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

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            Layout.fillWidth: true
                            text: Battery.isPluggedIn ? (Battery.isCharging ? "Charging" : "Full") : "On battery"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.overBackground
                        }

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
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
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
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

                        readonly property real defaultRadius: Styling.radius(0)
                        readonly property real selectedRadius: Styling.radius(0) / 2

                        variant: isSelected ? "primary" : (buttonHovered ? "focus" : "common")
                        enableShadow: false

                        topLeftRadius: isSelected ? (isFirst ? defaultRadius : selectedRadius) : defaultRadius
                        bottomLeftRadius: isSelected ? (isFirst ? defaultRadius : selectedRadius) : defaultRadius
                        topRightRadius: isSelected ? (isLast ? defaultRadius : selectedRadius) : defaultRadius
                        bottomRightRadius: isSelected ? (isLast ? defaultRadius : selectedRadius) : defaultRadius

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
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
