pragma Singleton
import QtQuick
import Quickshell
import qs.config

// Deck's own motion set: rails and detents instead of the shared island springs.
// Surfaces slide open on a fast-decelerating rail and retract quickly. Pages
// travel along the rail in the direction of the selected tab, their cards land
// in sequence, and selectors settle into place with a small detent.
Singleton {
    id: root

    readonly property bool enabled: Config.animDuration > 0

    readonly property int openDuration: enabled ? Math.max(280, Math.round(Config.animDuration * 1.1)) : 0
    readonly property int closeDuration: enabled ? Math.max(140, Math.round(Config.animDuration * 0.5)) : 0
    readonly property int resizeDuration: enabled ? Math.max(220, Math.round(Config.animDuration * 0.85)) : 0
    readonly property int pageDuration: enabled ? Math.max(220, Math.round(Config.animDuration * 0.8)) : 0
    readonly property int cardDuration: enabled ? Math.max(200, Math.round(Config.animDuration * 0.75)) : 0
    readonly property int detentDuration: enabled ? Math.max(200, Math.round(Config.animDuration * 0.7)) : 0
    readonly property int stagger: enabled ? Math.max(18, Math.round(Config.animDuration / 10)) : 0
    // Cards after this position share the last delay so long lists still land promptly.
    readonly property int maximumStaggerSteps: 6

    readonly property int openEasing: Easing.OutExpo
    readonly property int closeEasing: Easing.InQuad
    readonly property int travelEasing: Easing.OutCubic
    readonly property int detentEasing: Easing.OutBack
    readonly property real detentOvershoot: 1.6

    // Distances are in multiples of the base font size.
    readonly property real railTravel: 1.5
    readonly property real pageTravel: 1.4
    readonly property real cardTravel: 0.7

    function delayFor(order: int): int {
        return Math.max(0, Math.min(order, maximumStaggerSteps)) * stagger;
    }
}
