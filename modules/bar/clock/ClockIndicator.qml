import QtQuick
import qs.config
import qs.modules.theme

Text {
    renderType: Text.NativeRendering
    font.hintingPreference: Font.PreferFullHinting
    text: Icons.clock
    color: Colors.overBackground
    font.pixelSize: 20
    font.family: Icons.font
}
