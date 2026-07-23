import QtQuick
import QtQuick.Effects
import qs.config

// Intentionally inert. Outline-via-shadow was a text Multieffect path that
// softens glyphs the same way as Shadow.qml.
MultiEffect {
    shadowEnabled: false
    blurEnabled: false
    shadowBlur: 0
    shadowOpacity: 1.0

    maskSpreadAtMin: 1.0
    maskSpreadAtMax: 1.0

    shadowColor: Config.resolveColor(Config.theme.srBg.border[0])
}
