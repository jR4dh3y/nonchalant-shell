import QtQuick
import qs.modules.theme

// Hover/press wash for a StyledRect pill. StyledRect clips its children to
// its own (possibly asymmetric) corners, so the tint needs no radius of its
// own and always matches the pill's shape.
Rectangle {
    id: root

    property bool hovered: false
    property bool pressed: false
    property real hoverOpacity: 0.25
    property real pressedOpacity: hoverOpacity

    anchors.fill: parent
    color: Styling.srItem("overprimary")
    opacity: root.pressed ? root.pressedOpacity : (root.hovered ? root.hoverOpacity : 0)

    Behavior on opacity {
        enabled: Motion.enabled
        NumberAnimation {
            duration: Motion.hoverDuration
            easing.type: Easing.OutQuad
        }
    }
}
