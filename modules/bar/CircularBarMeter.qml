pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.theme

// Scrollable bar meter; flat controls share the droplet radial geometry.
Item {
    id: root

    required property Item bar
    property bool layerEnabled: false
    property bool flat: false
    property int meterSize: 36

    property real startRadius: Styling.radius(0)
    property real endRadius: Styling.radius(0)
    property real value: 0
    property string icon: ""
    property real iconSize: root.flat ? 11 : 14
    property color progressColor: Styling.srItem("overprimary")
    property string tooltipText: ""
    property bool clickEnabled: true
    property bool isHovered: false

    signal adjusted(real value)
    signal activated
    signal secondaryActivated

    readonly property real normalizedValue: Math.max(0, Math.min(1, value))

    Layout.preferredWidth: meterSize
    Layout.preferredHeight: meterSize
    Layout.fillHeight: !flat
    Layout.alignment: Qt.AlignVCenter

    implicitWidth: meterSize
    implicitHeight: meterSize

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    StyledRect {
        id: buttonBg
        anchors.fill: parent
        variant: root.flat ? "transparent" : "bg"
        enableShadow: !root.flat && root.layerEnabled
        enableBorder: !root.flat
        topLeftRadius: root.flat ? (root.meterSize / 2) : root.startRadius
        topRightRadius: root.flat ? (root.meterSize / 2) : root.endRadius
        bottomLeftRadius: root.flat ? (root.meterSize / 2) : root.startRadius
        bottomRightRadius: root.flat ? (root.meterSize / 2) : root.endRadius
        scale: (root.clickEnabled && meterMouseArea.pressed) ? 0.92 : 1.0

        PressBehavior on scale {
            pressed: meterMouseArea.pressed
        }

        HoverTint {
            hovered: root.isHovered
            hoverOpacity: root.flat ? 0.12 : 0.2
        }

        BarRadialMeter {
            anchors.centerIn: parent
            width: controlSize
            height: controlSize
            controlSize: root.flat ? root.meterSize : 32
            meterRadius: root.flat ? standardRadius : 12
            lineWidth: root.flat ? standardLineWidth : 3
            startAngle: root.flat ? 140 : 135
            spanAngle: root.flat ? 260 : 270
            trackColor: root.flat ? Qt.alpha(Colors.overBackground, 0.24) : Colors.outlineVariant
            value: root.normalizedValue
            progressColor: root.progressColor
        }

        StyledText {
            anchors.centerIn: parent
            text: root.icon
            font.family: Icons.font
            font.pixelSize: root.iconSize
            color: Colors.overBackground
        }

        MouseArea {
            id: meterMouseArea
            anchors.fill: parent
            acceptedButtons: root.clickEnabled ? (Qt.LeftButton | Qt.RightButton) : Qt.NoButton
            cursorShape: root.clickEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.secondaryActivated();
                } else {
                    root.activated();
                }
            }
            onWheel: wheel => {
                const direction = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                if (direction === 0)
                    return;
                root.adjusted(Math.max(0, Math.min(1, root.normalizedValue + (direction > 0 ? 0.05 : -0.05))));
                wheel.accepted = true;
            }
        }

        StyledToolTip {
            show: root.isHovered
            tooltipText: root.tooltipText
        }
    }
}
