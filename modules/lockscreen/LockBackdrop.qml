import QtQuick
import qs.modules.components
import qs.modules.globals
import qs.modules.theme

// The dimmed lockscreen wallpaper. Shared by the lock curtain (overlay layer,
// over the live desktop) and the lock surface itself, so the handoff between
// them in either direction is pixel-identical and therefore invisible.
Item {
    id: root

    required property string screenName

    readonly property real scrimOpacity: 0.55
    // True once the wallpaper can be shown (or when there is none to wait for).
    readonly property bool ready: wallpaper.source === "" || wallpaper.ready

    // Opaque base: the scrim colour shows until the wallpaper is decoded, so
    // the clean wallpaper can never flash at full brightness.
    Rectangle {
        anchors.fill: parent
        color: Colors.background
    }

    TintedWallpaper {
        id: wallpaper
        anchors.fill: parent
        radius: 0
        tintEnabled: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false

        readonly property string framePath: {
            const manager = GlobalStates.wallpaperManager;
            if (!manager)
                return "";
            const perScreen = manager.perScreenWallpapers || {};
            return manager.getLockscreenFramePath(perScreen[root.screenName] || manager.currentWallpaper);
        }

        source: framePath ? "file://" + framePath : ""
        visible: source !== ""
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.background
        opacity: root.scrimOpacity
    }
}
