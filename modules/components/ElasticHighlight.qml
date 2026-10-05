import QtQuick
import qs.modules.theme
import qs.config

// Selection highlight that morphs between sibling items. A fast lead tracker and
// a slow follow tracker are unioned, so the pill stretches toward the new target
// before its trailing edge catches up. Place it as a sibling under the items and
// set originX/originY to the items' container offset.
StyledRect {
    id: root

    property Item targetItem: null
    property real originX: 0
    property real originY: 0

    // Last non-null target: the pill stays put while fading out instead of
    // sweeping back to the origin.
    property Item shownItem: null
    // Off while appearing so the pill snaps to its first target, then morphs.
    property bool morphing: false

    variant: "primary"
    radius: Styling.radius(4)
    opacity: targetItem ? 1 : 0
    visible: opacity > 0

    function show(item: Item) {
        if (!item) {
            morphing = false;
            return;
        }
        shownItem = item;
        if (!morphing)
            Qt.callLater(() => root.morphing = root.targetItem !== null);
    }

    onTargetItemChanged: show(targetItem)
    Component.onCompleted: show(targetItem)

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 3
            easing.type: Easing.OutQuad
        }
    }

    readonly property real tx: shownItem ? shownItem.x : 0
    readonly property real ty: shownItem ? shownItem.y : 0
    readonly property real tw: shownItem ? shownItem.width : 0
    readonly property real th: shownItem ? shownItem.height : 0

    // Tracker 1 (fast / lead)
    property real t1x: tx
    property real t1y: ty
    property real t1w: tw
    property real t1h: th

    Behavior on t1x {
        enabled: Config.animDuration > 0 && root.morphing
        NumberAnimation {
            duration: Config.animDuration / 3
            easing.type: Easing.OutSine
        }
    }
    Behavior on t1y {
        enabled: Config.animDuration > 0 && root.morphing
        NumberAnimation {
            duration: Config.animDuration / 3
            easing.type: Easing.OutSine
        }
    }
    Behavior on t1w {
        enabled: Config.animDuration > 0 && root.morphing
        NumberAnimation {
            duration: Config.animDuration / 3
            easing.type: Easing.OutSine
        }
    }
    Behavior on t1h {
        enabled: Config.animDuration > 0 && root.morphing
        NumberAnimation {
            duration: Config.animDuration / 3
            easing.type: Easing.OutSine
        }
    }

    // Tracker 2 (slow / follow)
    property real t2x: tx
    property real t2y: ty
    property real t2w: tw
    property real t2h: th

    Behavior on t2x {
        enabled: Config.animDuration > 0 && root.morphing
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutSine
        }
    }
    Behavior on t2y {
        enabled: Config.animDuration > 0 && root.morphing
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutSine
        }
    }
    Behavior on t2w {
        enabled: Config.animDuration > 0 && root.morphing
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutSine
        }
    }
    Behavior on t2h {
        enabled: Config.animDuration > 0 && root.morphing
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutSine
        }
    }

    x: Math.min(t1x, t2x) + originX
    y: Math.min(t1y, t2y) + originY
    width: Math.max(t1x + t1w, t2x + t2w) - Math.min(t1x, t2x)
    height: Math.max(t1y + t1h, t2y + t2h) - Math.min(t1y, t2y)
}
