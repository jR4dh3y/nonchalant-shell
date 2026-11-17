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
    // Measure the visual gap from the bar's outer edge, while keeping the
    // originating control as the vertical/morph anchor.
    property Item edgeItem: anchorItem
    // Content to display inside the popup
    default property alias contentData: surface.content

    // Visual configuration
    property int popupPadding: 8
    property int visualMargin: 8  // Distance from bar
    property int shadowMargin: 16  // Room around the surface for the spring stretch
    property string variant: "popup"  // StyledRect variant for background
    property string contentVariant: ""
    // See MorphSurface: select content by `presentedKey` so switching an open
    // popup fades the outgoing content out before the incoming one appears.
    property string contentKey: ""
    readonly property string presentedKey: surface.presentedKey

    // Behavior configuration
    property bool closeOnFocusLost: true

    // Logical open state (changes immediately, not after animation)
    property bool isOpen: false

    // Signal emitted when popup is closed externally (click outside)
    signal closedExternally

    property int contentWidth: 220
    property int contentHeight: 150
    // Room for content the popup may switch to while open (a tray grid
    // becoming an app menu), so switching never resizes the window.
    property int reservedWidth: 0
    property int reservedHeight: 0

    // The window only grows while it is up. Resizing it under an animating
    // body re-anchors it a frame apart from the body and clips a shrinking
    // body to its new size; the body morphs inside a stable frame instead.
    property int frameWidth: 0
    property int frameHeight: 0
    function fitFrame(): void {
        const width = Math.max(root.contentWidth, root.reservedWidth);
        const height = Math.max(root.contentHeight, root.reservedHeight);
        root.frameWidth = root.visible ? Math.max(root.frameWidth, width) : width;
        root.frameHeight = root.visible ? Math.max(root.frameHeight, height) : height;
    }
    onContentWidthChanged: fitFrame()
    onContentHeightChanged: fitFrame()
    onReservedWidthChanged: fitFrame()
    onReservedHeightChanged: fitFrame()
    onVisibleChanged: fitFrame()
    Component.onCompleted: fitFrame()

    readonly property int totalWidth: frameWidth + shadowMargin * 2
    // A left dock's popup spans the dock's full height, so it never moves;
    // the body is placed inside it, centred on its control.
    readonly property real dockHeight: root.leftBar ? (root.anchor.window?.contentItem?.height ?? 0) : 0
    readonly property int totalHeight: root.dockHeight > 0 ? Math.ceil(root.dockHeight) : frameHeight + shadowMargin * 2
    property real anchorCenterY: 0

    implicitWidth: totalWidth
    implicitHeight: totalHeight

    readonly property bool bottomBar: !leftBar && (Config.bar?.position ?? "top") === "bottom"
    readonly property bool leftBar: (Config.bar?.style ?? "default") === "left"

    // Open away from the configured screen edge. A left dock opens sideways,
    // vertically centered on the anchor pill.
    anchor.window: root.anchorItem ? root.anchorItem.QsWindow.window : null
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.onAnchoring: {
        const windowContent = root.anchor.window?.contentItem;
        if (!windowContent)
            return;
        // Coordinate mappings are not reactive. Resolve after the control's
        // layout has settled, each time the native popup is positioned.
        const origin = root.anchorItem.mapToItem(windowContent, 0, 0);
        const edge = root.edgeItem.mapToItem(windowContent, root.edgeItem.width, 0);
        root.anchor.rect.x = root.leftBar
            ? edge.x + root.visualMargin - root.shadowMargin
            : origin.x + (root.anchorItem.width - root.totalWidth) / 2;
        root.anchorCenterY = origin.y + root.anchorItem.height / 2;
        root.anchor.rect.y = root.dockHeight > 0 ? 0 : origin.y + (root.leftBar
            ? (root.anchorItem.height - root.totalHeight) / 2
            : root.bottomBar
                ? -root.totalHeight - root.visualMargin + root.shadowMargin
                : root.anchorItem.height + root.visualMargin - root.shadowMargin);
    }

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
        objectName: root.objectName ? root.objectName + "Surface" : ""

        x: root.shadowMargin
        y: root.dockHeight > 0 ? 0 : root.shadowMargin
        width: root.frameWidth
        height: root.dockHeight > 0 ? root.totalHeight : root.frameHeight
        contentWidth: root.contentWidth
        contentHeight: root.contentHeight
        // Centred on the control, kept the visual margin inside the screen.
        restY: Math.max(root.visualMargin, Math.min(root.totalHeight - root.visualMargin - root.contentHeight,
            root.anchorCenterY - root.contentHeight / 2))
        originWidth: root.anchorItem.width
        fromBottom: root.bottomBar
        fromLeft: root.leftBar
        variant: root.variant
        contentVariant: root.contentVariant
        contentKey: root.contentKey
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
