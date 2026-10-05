pragma Singleton
import QtQuick
import Quickshell
import qs.config

// Shared motion tokens for every shell surface (island and default bar).
// Expansion is a long, softly overshooting spring; collapse is a monotonic
// curve so nothing swells on close. Content enters a beat after its surface
// starts growing so it lands on an already-open shape instead of popping in
// clipped.
Singleton {
    id: root

    readonly property bool enabled: Config.animDuration > 0

    readonly property int expandDuration: enabled ? Math.max(360, Math.round(Config.animDuration * 1.3)) : 0
    readonly property int collapseDuration: enabled ? Math.max(240, Math.round(Config.animDuration * 0.9)) : 0
    readonly property int fadeInDuration: enabled ? Math.max(200, Math.round(Config.animDuration * 0.8)) : 0
    readonly property int fadeOutDuration: enabled ? Math.max(90, Math.round(Config.animDuration * 0.35)) : 0
    readonly property int contentEnterDelay: Math.round(expandDuration * 0.22)
    readonly property real overshoot: 1.12
    // Vertical travel of content entering or leaving a surface.
    readonly property real drift: 6

    // Tactile press feedback: a quick monotonic press, a springy release.
    readonly property int pressDuration: enabled ? Math.max(60, Math.round(Config.animDuration * 0.27)) : 0
    readonly property int releaseDuration: enabled ? Math.max(200, Math.round(Config.animDuration * 0.83)) : 0
    readonly property real pressOvershoot: 1.4

    readonly property int hoverDuration: enabled ? Math.max(80, Math.round(Config.animDuration / 2)) : 0
}
