pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme

// Shared text primitive. Qt's default distance-field renderer (QtRendering)
// produces a soft halo on small/bold UI glyphs; native hinted rendering keeps
// edges crisp for static shell chrome. Prefer this over bare Text for labels.
Text {
    id: root

    color: Colors.overBackground
    font.family: Config.theme.font
    font.pixelSize: Styling.fontSize(0)
    renderType: Text.NativeRendering
    font.hintingPreference: Font.PreferFullHinting
}
