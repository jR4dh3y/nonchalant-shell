pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

StyledRect {
    id: root

    implicitWidth: 52
    implicitHeight: 52
    Layout.preferredWidth: 52
    Layout.preferredHeight: 52
    radius: 26

    property string icon: ""
    property int iconSize: showArc ? 18 : 22
    property bool active: false
    property color iconColor: active ? Colors.overPrimary : Colors.overBackground
    variant: active ? "primary" : (mouseArea.containsMouse ? "focus" : "internalbg")

    // Radial progress properties
    property real value: 0.0
    property color arcColor: Colors.primary
    property color trackColor: Qt.rgba(1, 1, 1, 0.14)
    property bool showArc: false
    property bool isMuted: false

    signal clicked(var mouse)
    signal wheelScrolled(int delta)

    // Radial Progress Arc
    Item {
        id: progressMeter
        anchors.fill: parent
        visible: root.showArc

        readonly property real gapAngle: 45
        readonly property real totalAngleDeg: 360 - 2 * gapAngle
        readonly property real normalizedValue: Math.max(0, Math.min(1, root.value))
        property real currentAngleDeg: normalizedValue * totalAngleDeg
        readonly property real meterRadius: (root.width / 2) - 6
        readonly property real lineWidth: 3.5

        Behavior on currentAngleDeg {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true
            visible: root.showArc

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();

                const centerX = width / 2;
                const centerY = height / 2;
                const radStart = (Math.PI / 2) + (progressMeter.gapAngle * Math.PI / 180);
                const radTotal = (progressMeter.totalAngleDeg * Math.PI / 180);
                const radProgress = (progressMeter.currentAngleDeg * Math.PI / 180);

                ctx.lineCap = "round";
                ctx.lineWidth = progressMeter.lineWidth;

                // 1. Full track (background)
                ctx.strokeStyle = root.trackColor;
                ctx.beginPath();
                ctx.arc(centerX, centerY, progressMeter.meterRadius, radStart, radStart + radTotal, false);
                ctx.stroke();

                // 2. Active progress arc
                if (progressMeter.currentAngleDeg > 0) {
                    ctx.strokeStyle = root.arcColor;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, progressMeter.meterRadius, radStart, radStart + radProgress, false);
                    ctx.stroke();
                }
            }

            Connections {
                target: progressMeter
                function onCurrentAngleDegChanged() { canvas.requestPaint(); }
            }

            Connections {
                target: root
                function onArcColorChanged() { canvas.requestPaint(); }
                function onTrackColorChanged() { canvas.requestPaint(); }
                function onShowArcChanged() { canvas.requestPaint(); }
                function onValueChanged() { canvas.requestPaint(); }
            }

            Component.onCompleted: canvas.requestPaint()
        }
    }

    // Centered icon
    Text {
        anchors.centerIn: parent
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        text: root.icon
        font.family: Icons.font
        font.pixelSize: root.iconSize
        color: root.iconColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => root.clicked(mouse)
        onWheel: (wheel) => root.wheelScrolled(wheel.angleDelta.y)
    }
}
