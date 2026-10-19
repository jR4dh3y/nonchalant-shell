import QtQuick
import qs.modules.theme

// Match each corner of the pill without capturing its foreground text.
Rectangle {
    id: root

    property bool hovered: false
    property bool pressed: false
    property real hoverOpacity: 0.25
    property real pressedOpacity: hoverOpacity

    anchors.fill: parent
    radius: parent?.radius ?? 0
    topLeftRadius: parent?.topLeftRadius ?? root.radius
    topRightRadius: parent?.topRightRadius ?? root.radius
    bottomLeftRadius: parent?.bottomLeftRadius ?? root.radius
    bottomRightRadius: parent?.bottomRightRadius ?? root.radius
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
