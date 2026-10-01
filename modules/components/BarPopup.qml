pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

// Shared popup surface for bar-attached controls. The surface morphs out of
// the pill it is anchored to (see MorphSurface), the same motion the island
// uses for its panels.
PopupWindow {
    id: root

    // Required: the item this popup anchors to
    required property Item anchorItem
    // Content to display inside the popup
    default property alias contentData: surface.content

    // Visual configuration
    property int popupPadding: 8
    property int visualMargin: 8  // Distance from bar
    property int shadowMargin: 16  // Room around the surface for the spring stretch
    property string variant: "popup"  // StyledRect variant for background

    // Behavior configuration
    property bool closeOnFocusLost: true

    // Logical open state (changes immediately, not after animation)
    property bool isOpen: false

    // Signal emitted when popup is closed externally (click outside)
    signal closedExternally

    property int contentWidth: 220
    property int contentHeight: 150

    readonly property int totalWidth: contentWidth + shadowMargin * 2
    readonly property int totalHeight: contentHeight + shadowMargin * 2

    implicitWidth: totalWidth
    implicitHeight: totalHeight

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
    visible: false
    mask: Region {
        item: root.visible ? surface.body : null
    }

    FocusGrab {
        active: root.visible && root.isOpen
        windows: [root]

        onCleared: {
            if (root.closeOnFocusLost && root.isOpen) {
                root.close();
                root.closedExternally();
            }
        }
    }

    MorphSurface {
        id: surface

        x: root.shadowMargin
        y: root.shadowMargin
        contentWidth: root.contentWidth
        contentHeight: root.contentHeight
        originWidth: root.anchorItem.width
        fromBottom: root.bottomBar
        variant: root.variant
        padding: root.popupPadding
        maxStretch: root.shadowMargin - 2

        // Unmap only once the surface has fully retracted.
        onFullyHiddenChanged: {
            if (fullyHidden && !root.isOpen)
                root.visible = false;
        }
    }

    function open() {
        if (isOpen)
            return;

        // One bar popup at a time; the replaced sibling closes quickly.
        Visibilities.claimBarPopup(root);

        isOpen = true;
        visible = true;
        // Start the morph once the window is mapped so its first frames are
        // not spent on an unmapped surface.
        Qt.callLater(() => {
            if (root.isOpen)
                surface.shown = true;
        });
    }

    function close() {
        if (!isOpen)
            return;

        isOpen = false;
        Visibilities.releaseBarPopup(root);
        surface.shown = false;
        if (surface.fullyHidden)
            visible = false;
    }

    // Clicking the anchor of an open popup first clears the focus grab, which
    // starts the close; the click then lands here and must not reopen it.
    function toggle() {
        if (isOpen || (visible && surface.progress > 0.5))
            close();
        else
            open();
    }
}
