import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.components

// Blurred copy of a screen's wallpaper for Niri's overview backdrop.
//
// Niri places this surface inside the backdrop through the layer rule that
// NiriGenerator writes, so it shows only between and around the zoomed-out
// workspaces. The blur renders once into a cached layer; the surface stays
// idle until the wallpaper or tint changes.
PanelWindow {
    id: root

    // The wallpaper owner for this screen. It resolves per-screen wallpapers
    // and cached still frames for video and GIF wallpapers.
    required property Wallpaper wallpaperOwner

    readonly property string frameUrl: {
        const owner = root.wallpaperOwner;
        return owner ? owner.getLockscreenFrameUrl(owner.effectiveWallpaper) : "";
    }
    readonly property bool ready: image.ready
    readonly property int blurRadius: 64

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Niri honours place-within-backdrop only for background surfaces that
    // ignore exclusive zones.
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nonchalant:overview-backdrop"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // The backdrop never takes pointer input; overview clicks belong to Niri.
    mask: Region {}

    TintedWallpaper {
        id: image

        // Extend past the screen edges so the blur never samples the
        // transparent border and darkens the edges.
        anchors.fill: parent
        anchors.margins: -root.blurRadius
        source: root.frameUrl
        tintEnabled: root.wallpaperOwner?.tintEnabled ?? false
        visible: source !== ""

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: root.blurRadius
            blur: 1.0
            autoPaddingEnabled: false
        }
    }
}
