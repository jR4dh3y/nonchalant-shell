import QtQuick
import qs.modules.components
import qs.modules.theme

// A left power shelf action. Capsule actions sit on the shared highlight like
// workspace buttons; detached actions are droplets that stretch into a
// confirmation capsule while armed.
Item {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)

    required property string key
    required property string label
    required property string glyph
    required property real restSize
    required property real outerRadius
    property bool detached: false
    property bool selected: false
    property bool armed: false
    readonly property real labelPadding: 8

    signal activated()
    signal entered()

    objectName: "leftPower-" + key
    implicitWidth: armed ? restSize + labelText.implicitWidth + labelPadding * 2 : restSize
    implicitHeight: restSize
    width: implicitWidth
    height: implicitHeight
    Accessible.role: Accessible.Button
    Accessible.name: armed ? "Confirm " + label.toLowerCase() : label
    Accessible.onPressAction: root.activated()
    scale: mouse.pressed ? 0.90 : 1
    PressBehavior on scale { pressed: mouse.pressed }

    Behavior on implicitWidth {
        enabled: Motion.enabled
        NumberAnimation {
            duration: root.armed ? Motion.expandDuration : Motion.collapseDuration
            easing.type: root.armed ? Easing.OutBack : Easing.OutQuad
            easing.overshoot: Motion.overshoot
        }
    }

    StyledRect {
        id: surface
        anchors.fill: parent
        variant: root.armed ? "errorcontainer" : (root.selected ? "focus" : "pane")
        backgroundOpacity: root.detached || root.armed ? 1 : 0
        enableBorder: false
        enableShadow: false
        radius: root.detached ? Styling.pillRadius(height) : root.outerRadius
        clip: true

        HoverTint {
            hovered: mouse.containsMouse && !root.armed
            pressed: mouse.pressed && !root.armed
        }

        StyledText {
            id: labelText
            x: root.restSize - root.labelPadding / 2
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: surface.item
            font.weight: Font.DemiBold
            opacity: root.armed ? 1 : 0
            Behavior on opacity {
                enabled: Motion.enabled
                NumberAnimation {
                    duration: root.armed ? Motion.fadeInDuration : Motion.fadeOutDuration
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    StyledText {
        x: (root.restSize - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        text: root.armed ? Icons.check : root.glyph
        font.family: Icons.font
        font.pixelSize: Styling.fontSize(4) * (root.detached ? 1.2 : 1)
        font.weight: root.selected ? Font.DemiBold : Font.Medium
        color: root.armed || root.selected ? surface.item
            : root.key === "poweroff" ? root.shellPalette.danger : root.shellPalette.overBackground
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.entered()
        onClicked: root.activated()
    }
}
