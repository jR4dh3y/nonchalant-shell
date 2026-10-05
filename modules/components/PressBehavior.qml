import QtQuick
import qs.modules.theme

// Tactile press feedback for `scale`: `PressBehavior on scale { pressed: ... }`.
// Pressing eases down monotonically; releasing springs back with overshoot.
Behavior {
    id: root

    property bool pressed: false

    enabled: Motion.enabled

    NumberAnimation {
        duration: root.pressed ? Motion.pressDuration : Motion.releaseDuration
        easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
        easing.overshoot: Motion.pressOvershoot
    }
}
