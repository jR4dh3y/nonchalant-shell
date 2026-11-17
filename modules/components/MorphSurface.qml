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
// Content stays at native scale and at its resting position; the body only
// reveals or conceals it. Scaling large surfaces (the dashboard) resamples
// text and hitches layout.
Item {
    id: root

    property bool shown: false
    property real contentWidth: 0
    property real contentHeight: 0
    // Width of the pill the surface grows out of.
    property real originWidth: contentWidth / 2
    // Optional source item for a full geometry morph, sampled on each transition.
    property Item originItem: null
    property rect originRect: Qt.rect(0, 0, 0, 0)
    // Grow upward (bar at the bottom of the screen) instead of downward.
    property bool fromBottom: false
    // Pin the body to the left edge instead of centering it (left-edge dock).
    property bool fromLeft: false
    // Resting top of the body on a left-edge dock, derived by the host from
    // `contentHeight`. The body glides there on the same curve as its size,
    // so whichever edge the host anchors (top, centre or bottom) stays put.
    property real restY: 0
    property string variant: "popup"
    property string contentVariant: "pane"
    // Fades the chrome (variant + contentVariant) in or out while the
    // content stays, e.g. a frameless dashboard turning into a framed menu.
    property bool showChrome: true
    property real radius: Styling.radius(8)
    // Mask the content to the rounded body while it moves. A side dock's
    // surfaces sweep their cut edge across the content as they grow, so the
    // corners would show square. The mask renders the content into a texture
    // layer for the duration of a motion only; at rest text is drawn directly.
    property bool maskContent: root.fromLeft
    // Hosts select content by the presented key. Immediate switches start
    // the frame morph with the new content, without an empty fade frame:
    // a frozen copy of the outgoing content stays where it rested and fades
    // out, then the incoming content fades in, while the frame morphs
    // between them. Each panel keeps its own anchor, so a contracting
    // edge conceals the outgoing panel exactly as a growing one reveals the
    // incoming panel.
    property string contentKey: ""
    property string presentedKey: ""
    property bool immediateContentSwitch: false
    property real swapOutDuration: 0
    property int padding: 8
    // Upper bound for the spring's stretch past the resting height; keep it
    // within whatever margin the hosting window leaves around the surface.
    property real maxStretch: 12

    default property alias content: page.data
    readonly property alias body: body
    readonly property real progress: root.reveal
    readonly property bool fullyHidden: root.reveal <= 0.001
    // The body is changing shape; content is masked to its rounded corners.
    readonly property bool moving: !root.fullyHidden && (root.reveal !== 1
        || root.bodyWidth !== root.contentWidth || root.bodyHeight !== root.contentHeight
        || root.bodyY !== root.restY || swap.running || handoff.running)

    property real reveal: 0
    readonly property real revealClamped: Math.max(0, Math.min(1, root.reveal))
    readonly property real stretch: Math.min(root.maxStretch, Math.max(0, root.reveal - 1) * (root.fromLeft ? root.bodyWidth : root.bodyHeight))

    width: contentWidth
    height: contentHeight

    // The body follows content size changes (a launcher growing with
    // results, a menu replacing a grid) instead of snapping; the content
    // itself never animates. Position and size share one curve, and any
    // retarget restarts both together, so an anchored edge never drifts.
    property real bodyWidth: contentWidth
    property real bodyHeight: contentHeight
    property real bodyY: restY
    readonly property bool followsContent: Motion.enabled && !root.fullyHidden
    Behavior on bodyWidth {
        enabled: root.followsContent
        NumberAnimation {
            duration: Motion.fadeInDuration
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on bodyHeight {
        enabled: root.followsContent
        NumberAnimation {
            duration: Motion.fadeInDuration
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on bodyY {
        enabled: root.followsContent
        NumberAnimation {
            duration: Motion.fadeInDuration
            easing.type: Easing.InOutQuad
        }
    }

    property real chrome: root.showChrome ? 1 : 0
    Behavior on chrome {
        enabled: root.followsContent
        NumberAnimation {
            duration: Motion.fadeInDuration
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on radius {
        enabled: root.followsContent
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

    function updateOrigin(): void {
        root.originRect = root.originItem
            ? root.originItem.mapToItem(root, 0, 0, root.originItem.width, root.originItem.height)
            : Qt.rect(0, 0, 0, 0);
    }

    SequentialAnimation {
        id: swap
        NumberAnimation {
            target: viewport
            property: "opacity"
            to: 0
            duration: root.swapOutDuration
            easing.type: Easing.OutQuad
        }
        ScriptAction { script: root.presentedKey = root.contentKey }
        NumberAnimation {
            target: viewport
            property: "opacity"
            to: 1
            duration: Motion.fadeInDuration
            easing.type: Easing.OutCubic
        }
    }

    // Freeze the outgoing page, then swap once the render thread reports the
    // snapshot is written. Render loops order ticks and syncs differently, so
    // nothing else proves the texture holds this page rather than an older
    // one. Without a capture the switch happens without the outgoing copy.
    property bool handoffPending: false
    property real handoffIncoming: 0
    property real handoffOutgoing: 0
    function finishHandoff(captured: bool): void {
        if (!root.handoffPending)
            return;
        captureTimeout.stop();
        root.handoffPending = false;
        outgoing.opacity = captured ? root.handoffOutgoing : 0;
        if (root.contentKey === root.presentedKey) {
            root.stopHandoff();
            return;
        }
        viewport.opacity = captured ? root.handoffIncoming : 1;
        root.presentedKey = root.contentKey;
        if (captured)
            handoff.restart();
    }
    Timer {
        id: captureTimeout
        interval: 100
        onTriggered: root.finishHandoff(false)
    }

    // Fade-through: the outgoing copy clears quickly, then the incoming page
    // fades in, so two unrelated layouts never overlap. The frame keeps
    // morphing throughout, which carries the motion across the brief gap.
    ParallelAnimation {
        id: handoff
        NumberAnimation {
            target: outgoing
            property: "opacity"
            to: 0
            duration: Motion.fadeOutDuration
            easing.type: Easing.OutQuad
        }
        SequentialAnimation {
            PauseAnimation {
                duration: Math.round(Motion.fadeOutDuration * 0.7)
            }
            NumberAnimation {
                target: viewport
                property: "opacity"
                to: 1
                duration: Motion.fadeInDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    function stopHandoff(): void {
        root.handoffPending = false;
        captureTimeout.stop();
        handoff.stop();
        outgoing.opacity = 0;
        viewport.opacity = 1;
    }

    onContentKeyChanged: {
        if (root.contentKey === root.presentedKey && !swap.running && !root.handoffPending)
            return;
        if (!root.shown || root.fullyHidden || !Motion.enabled) {
            swap.stop();
            root.stopHandoff();
            root.presentedKey = root.contentKey;
            return;
        }
        if (root.immediateContentSwitch) {
            if (root.handoffPending)
                return;
            // A reversal hands the incoming page the opacity its frozen
            // copy had reached, so neither side jumps.
            root.handoffIncoming = handoff.running ? outgoing.opacity : 0;
            handoff.stop();
            outgoing.restX = root.padding + body.restX;
            outgoing.restY = root.padding + (root.fromLeft ? root.restY : (root.fromBottom ? root.height - root.bodyHeight : 0));
            outgoing.width = page.width;
            outgoing.height = page.height;
            // Drawn, so the capture runs, but faint enough that the texture
            // it held before this capture never shows.
            root.handoffOutgoing = viewport.opacity;
            outgoing.opacity = 0.01;
            root.handoffPending = true;
            snapshot.scheduleUpdate();
            captureTimeout.restart();
            return;
        }
        swap.stop();
        root.swapOutDuration = Motion.fadeOutDuration * viewport.opacity;
        swap.start();
    }

    onShownChanged: {
        root.updateOrigin();
        if (swap.running) {
            swap.stop();
            viewport.opacity = 1;
        }
        root.stopHandoff();
        root.presentedKey = root.contentKey;
        openAnim.stop();
        closeAnim.stop();
        if (!Motion.enabled) {
            root.reveal = root.shown ? 1 : 0;
            return;
        }
        (root.shown ? openAnim : closeAnim).start();
    }
    // A host may switch between an origin morph and a plain reveal while
    // open; a reversal must start from the new origin, not a stale one.
    onOriginItemChanged: root.updateOrigin()

    Component.onCompleted: {
        root.updateOrigin();
        root.reveal = root.shown ? 1 : 0;
        root.presentedKey = root.contentKey;
    }

    Item {
        id: body

        readonly property real startWidth: root.originItem ? root.originRect.width : Math.max(0, Math.min(root.originWidth, root.bodyWidth))
        // Matches the chrome's corners so the mask and the frame agree.
        readonly property real radius: Math.min(root.radius, height / 2)
        readonly property real restX: root.fromLeft ? 0 : Math.round((root.width - root.contentWidth) / 2)

        visible: !root.fullyHidden
        width: body.startWidth + (root.bodyWidth - body.startWidth) * root.revealClamped + (root.fromLeft ? root.stretch : 0)
        height: root.originItem
            ? root.originRect.height + (root.bodyHeight - root.originRect.height) * root.revealClamped + (root.fromLeft ? 0 : root.stretch)
            : (root.fromLeft ? root.bodyHeight : root.bodyHeight * root.revealClamped + root.stretch)
        x: root.originItem ? root.originRect.x * (1 - root.revealClamped)
            : (root.fromLeft ? 0 : Math.round((root.width - width) / 2))
        y: root.originItem ? root.originRect.y + ((root.fromLeft ? root.bodyY : 0) - root.originRect.y) * root.revealClamped
            : (root.fromLeft ? root.bodyY : (root.fromBottom ? root.height - height : 0))

        FloatingSurface {
            anchors.fill: parent
            variant: root.variant
            contentVariant: root.contentVariant
            contentInset: root.padding
            enableShadow: false
            radius: body.radius
            opacity: root.chrome
            visible: opacity > 0
        }

        // The outgoing page of an immediate switch, pinned where it rested
        // and masked to the body's rounded corners. While it is captured it
        // overlays the identical live page.
        ShaderEffectSource {
            id: snapshot
            // Held only for a handoff, so the texture is released at rest.
            sourceItem: outgoing.visible ? page : null
            live: false
            hideSource: false
            visible: false
            onScheduledUpdateCompleted: root.finishHandoff(true)
        }
        ShaderEffect {
            id: outgoing

            property real restX: 0
            property real restY: 0
            readonly property ShaderEffectSource source: snapshot
            readonly property vector2d size: Qt.vector2d(width, height)
            readonly property vector4d clipRect: Qt.vector4d(-x, -y, body.width, body.height)
            readonly property real radius: body.radius

            x: outgoing.restX - body.x
            y: outgoing.restY - body.y
            opacity: 0
            visible: opacity > 0 || root.handoffPending
            fragmentShader: "rounded_mask.frag.qsb"
        }

        // Rectangular bounds clip at rest keeps text in the window scene
        // graph; while the body moves, a rounded mask keeps the content
        // inside the same corners the chrome paints.
        Item {
            id: viewport

            anchors.fill: parent
            clip: true

            Item {
                id: page

                // The layer is the page, whose size holds for a whole motion,
                // so its texture is allocated once per motion rather than on
                // every frame of the body's changing size. The shader cuts
                // the body's rounded rectangle out of it.
                layer.enabled: root.maskContent && root.moving && body.radius > 0 && page.opacity > 0
                layer.effect: ShaderEffect {
                    readonly property vector2d size: Qt.vector2d(width, height)
                    readonly property vector4d clipRect: Qt.vector4d(-page.x - (root.fromLeft ? page.drift : 0),
                        -page.y - (root.fromLeft ? 0 : page.drift), body.width, body.height)
                    readonly property real radius: body.radius
                    fragmentShader: "rounded_mask.frag.qsb"
                }

                readonly property real restDrift: !root.fromLeft && root.fromBottom ? Motion.drift : -Motion.drift
                property real drift: restDrift

                x: root.padding - body.x + body.restX
                y: root.padding - body.y + (root.fromLeft ? root.restY : (root.fromBottom ? root.height - root.bodyHeight : 0))
                width: root.contentWidth - root.padding * 2
                height: root.contentHeight - root.padding * 2
                opacity: 0
                transform: Translate {
                    x: root.fromLeft ? page.drift : 0
                    y: root.fromLeft ? 0 : page.drift
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
                            duration: root.originItem ? Motion.collapseDuration : Motion.fadeOutDuration
                            easing.type: root.originItem ? Easing.InCubic : Easing.OutQuad
                        }
                    }
                ]
            }
        }
    }
}
