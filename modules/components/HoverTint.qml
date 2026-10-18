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
    topLeftRadius: parent?.topLeftRadius ?? parent?.radius ?? 0
    topRightRadius: parent?.topRightRadius ?? parent?.radius ?? 0
    bottomLeftRadius: parent?.bottomLeftRadius ?? parent?.radius ?? 0
    bottomRightRadius: parent?.bottomRightRadius ?? parent?.radius ?? 0
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
