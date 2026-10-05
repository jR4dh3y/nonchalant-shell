pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme

// Island-style reveal for surfaces attached to the bar. The body pinches out
// of the pill it belongs to: width grows from `originWidth`, height springs
// open with a slight overshoot that stretches the body past its resting size,
// and the content arrives a beat later, fading in while drifting away from
// the bar. Closing is monotonic: content fades out quickly and the body
// retracts toward the bar.
//
// The content is never scaled or moved by the body; the body only clips it.
// Scaling large surfaces (the dashboard) resamples text and hitches layout.
Item {
    id: root

    property bool shown: false
    property real contentWidth: 0
    property real contentHeight: 0
    // Width of the pill the surface grows out of.
    property real originWidth: contentWidth / 2
    // Grow upward (bar at the bottom of the screen) instead of downward.
    property bool fromBottom: false
    property string variant: "popup"
    property real radius: Styling.radius(8)
    property int padding: 8
    // Upper bound for the spring's stretch past the resting height; keep it
    // within whatever margin the hosting window leaves around the surface.
    property real maxStretch: 12

    default property alias content: page.data
    readonly property alias body: body
    readonly property real progress: root.reveal
    readonly property bool fullyHidden: root.reveal <= 0.001

    property real reveal: 0
    readonly property real revealClamped: Math.max(0, Math.min(1, root.reveal))
    readonly property real stretch: Math.min(root.maxStretch, Math.max(0, root.reveal - 1) * root.bodyHeight)

    width: contentWidth
    height: contentHeight

    // The body follows content size changes while open (a launcher growing
    // with results) instead of snapping; the content itself never animates.
    property real bodyWidth: contentWidth
    property real bodyHeight: contentHeight
    Behavior on bodyWidth {
        enabled: Motion.enabled && root.shown && !root.fullyHidden
        NumberAnimation {
            duration: Motion.fadeInDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on bodyHeight {
        enabled: Motion.enabled && root.shown && !root.fullyHidden
        NumberAnimation {
            duration: Motion.fadeInDuration
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: openAnim
        target: root
        property: "reveal"
        to: 1
        duration: Motion.expandDuration
        easing.type: Easing.OutBack
        easing.overshoot: Motion.overshoot
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "reveal"
        to: 0
        duration: Motion.collapseDuration
        easing.type: Easing.InCubic
    }

    onShownChanged: {
        openAnim.stop();
        closeAnim.stop();
        if (!Motion.enabled) {
            root.reveal = root.shown ? 1 : 0;
            return;
        }
        (root.shown ? openAnim : closeAnim).start();
    }

    Component.onCompleted: root.reveal = root.shown ? 1 : 0

    StyledRect {
        id: body

        readonly property real startWidth: Math.max(0, Math.min(root.originWidth, root.bodyWidth))

        variant: root.variant
        enableShadow: false
        visible: !root.fullyHidden
        width: body.startWidth + (root.bodyWidth - body.startWidth) * root.revealClamped
        height: root.bodyHeight * root.revealClamped + root.stretch
        x: Math.round((root.width - width) / 2)
        y: root.fromBottom ? root.height - height : 0
        radius: Math.min(root.radius, height / 2)
        animateRadius: false

        Item {
            id: page

            readonly property real restDrift: root.fromBottom ? Motion.drift : -Motion.drift
            property real drift: restDrift

            // Cancel the body's own offset so the content stays put while the
            // body reveals it. Growing upward, the content rides the body's
            // animated far edge, so a size change moves it smoothly instead
            // of jumping with the resized surface.
            x: root.padding - body.x
            y: root.padding - body.y + (root.fromBottom ? root.height - root.bodyHeight : 0)
            width: root.contentWidth - root.padding * 2
            height: root.contentHeight - root.padding * 2
            opacity: 0
            transform: Translate {
                y: page.drift
            }

            states: State {
                name: "shown"
                when: root.shown
                PropertyChanges {
                    page.opacity: 1
                    page.drift: 0
                }
            }

            transitions: [
                Transition {
                    to: "shown"
                    enabled: Motion.enabled
                    SequentialAnimation {
                        PauseAnimation {
                            duration: Motion.contentEnterDelay
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                property: "opacity"
                                duration: Motion.fadeInDuration
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                property: "drift"
                                duration: Motion.expandDuration
                                easing.type: Easing.OutBack
                                easing.overshoot: Motion.overshoot
                            }
                        }
                    }
                },
                Transition {
                    from: "shown"
                    enabled: Motion.enabled
                    NumberAnimation {
                        properties: "opacity,drift"
                        duration: Motion.fadeOutDuration
                        easing.type: Easing.OutQuad
                    }
                }
            ]
        }
    }
}
