pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

// BarPopup: A popup component that anchors to bar elements
// Shared popup surface for bar-attached controls.
PopupWindow {
    id: root

    // Required: the item this popup anchors to
    required property Item anchorItem
    // Content to display inside the popup
    default property alias contentData: contentContainer.data

    // Visual configuration
    property int popupPadding: 8
    property int visualMargin: 8  // Distance from bar
    property int shadowMargin: 16  // Extra margin for shadow
    property string variant: "popup"  // StyledRect variant for background

    // Behavior configuration
    property bool closeOnFocusLost: true
    // Large nested surfaces can remain mapped between opens to avoid
    // compositor remap artifacts. Their input is limited by the mask below.
    property bool keepMapped: false

    // Logical open state (changes immediately, not after animation)
    property bool isOpen: false

    // Signal emitted when popup is closed externally (click outside)
    signal closedExternally

    // Reveal the popup at its attachment edge. Moving or scaling a large popup
    // makes dashboard content hitch and resamples text; changing only this clip
    // boundary keeps the content stationary and sharp.
    property real revealProgress: 0
    // Mutable duration so sibling switches can use a snappier close/open.
    property int transitionMs: Config.animDuration > 0 ? Config.animDuration : 0

    // Total size including shadow margin
    readonly property int totalWidth: contentWidth + shadowMargin * 2
    readonly property int totalHeight: contentHeight + shadowMargin * 2
    property int contentWidth: 220
    property int contentHeight: 150

    implicitWidth: totalWidth
    implicitHeight: totalHeight

    // Smooth size changes when content (e.g. dashboard) finishes loading.
    Behavior on contentWidth {
        enabled: root.transitionMs > 0 && root.visible
        NumberAnimation {
            duration: Math.max(root.transitionMs / 2, 80)
            easing.type: Easing.OutCubic
        }
    }
    Behavior on contentHeight {
        enabled: root.transitionMs > 0 && root.visible
        NumberAnimation {
            duration: Math.max(root.transitionMs / 2, 80)
            easing.type: Easing.OutCubic
        }
    }

    readonly property bool bottomBar: (Config.bar?.position ?? "top") === "bottom"

    // Open away from the configured screen edge.
    anchor.item: anchorItem
    anchor.rect.x: (anchorItem.width - totalWidth) / 2
    anchor.rect.y: bottomBar
        ? -totalHeight - visualMargin + shadowMargin
        : anchorItem.height + visualMargin - shadowMargin
    anchor.rect.width: 0
    anchor.rect.height: 0

    color: "transparent"
    visible: keepMapped
    mask: Region {
        item: root.visible ? revealViewport : null
    }

    property bool focusActive: false

    FocusGrab {
        id: focusGrab
        active: root.visible && root.focusActive
        windows: [root]

        onCleared: {
            if (root.closeOnFocusLost && root.isOpen) {
                root.isOpen = false;
                root.closedExternally();
                root.close();
            }
        }
    }

    Behavior on revealProgress {
        enabled: root.transitionMs > 0
        NumberAnimation {
            duration: root.transitionMs
            easing.type: root.isOpen ? Easing.OutCubic : Easing.InCubic
        }
    }

    Item {
        id: revealViewport

        x: root.shadowMargin
        width: root.contentWidth
        height: root.contentHeight * root.revealProgress
        y: root.bottomBar
            ? root.shadowMargin + root.contentHeight - height
            : root.shadowMargin
        clip: true

        StyledRect {
            id: popupContainer

            width: root.contentWidth
            height: root.contentHeight
            y: root.bottomBar ? revealViewport.height - height : 0
            variant: root.variant
            enableShadow: false
            radius: Styling.radius(8)

            Item {
                id: contentContainer
                anchors.fill: parent
                anchors.margins: root.popupPadding
            }
        }
    }

    function open() {
        if (visible && isOpen && revealProgress >= 0.99)
            return;

        closeTimer.stop();
        resetTransitionTimer.stop();

        // Snappy full-duration open for a clean settle.
        transitionMs = Config.animDuration > 0 ? Config.animDuration : 0;

        // One bar popup at a time; a replaced sibling uses a quicker collapse.
        Visibilities.claimBarPopup(root);

        isOpen = true;

        // A mid-close reopen continues from the current reveal boundary.
        if (!visible)
            visible = true;

        // Grab focus immediately so we don't thrash focus between the two popups.
        focusActive = true;

        Qt.callLater(() => {
            if (!root.isOpen)
                return;
            revealProgress = 1;
        });
    }

    // Faster exit used when another popup is replacing this one.
    function closeQuick() {
        _closeInternal(true);
    }

    function close() {
        _closeInternal(false);
    }

    function _closeInternal(quick) {
        if (!visible && !isOpen)
            return;

        isOpen = false;
        focusActive = false;
        Visibilities.releaseBarPopup(root);

        const base = Config.animDuration > 0 ? Config.animDuration : 0;
        transitionMs = quick ? Math.max(Math.round(base / 2), 80) : base;

        revealProgress = 0;

        closeTimer.interval = transitionMs > 0 ? transitionMs + 30 : 20;
        closeTimer.restart();

        // Restore default transition length after the close finishes.
        resetTransitionTimer.interval = closeTimer.interval + 10;
        resetTransitionTimer.restart();
    }

    function toggle() {
        if (isOpen || (visible && revealProgress > 0.5))
            close();
        else
            open();
    }

    Timer {
        id: closeTimer
        interval: 50
        onTriggered: {
            if (!root.isOpen && !root.keepMapped)
                root.visible = false;
        }
    }

    Timer {
        id: resetTransitionTimer
        interval: 50
        onTriggered: {
            root.transitionMs = Config.animDuration > 0 ? Config.animDuration : 0;
        }
    }
}
