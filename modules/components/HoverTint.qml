import QtQuick
import qs.modules.theme

// Neutral hover state layer: the surface ink (the `focus` variant's item
// color) at low alpha under the foreground. It lifts flat, rest and already
// lifted surfaces in dark and light mode without borrowing an accent hue.
// Keep it off accent fills; selection already owns those colors. Match each
// corner of the pill without capturing its foreground text.
Rectangle {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)

    property bool hovered: false
    property bool pressed: false
    property real hoverOpacity: 0.1
    property real pressedOpacity: 0.16

    anchors.fill: parent
    radius: parent?.radius ?? 0
    topLeftRadius: parent?.topLeftRadius ?? root.radius
    topRightRadius: parent?.topRightRadius ?? root.radius
    bottomLeftRadius: parent?.bottomLeftRadius ?? root.radius
    bottomRightRadius: parent?.bottomRightRadius ?? root.radius
    color: Styling.srItem("focus", root.shellPalette)
    opacity: root.pressed ? root.pressedOpacity : (root.hovered ? root.hoverOpacity : 0)

    Behavior on opacity {
        enabled: Motion.enabled
        NumberAnimation {
            duration: Motion.hoverDuration
            easing.type: Easing.OutQuad
        }
    }
}
