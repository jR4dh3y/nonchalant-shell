import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

// Intentionally inert. Applying MultiEffect as layer.effect on text-bearing
// items re-rasterizes glyphs into an FBO and makes bold labels look soft/hazy.
// Keep this type so existing `layer.effect: Shadow {}` references still resolve.
MultiEffect {
    shadowEnabled: false
    blurEnabled: false
    shadowHorizontalOffset: Config.theme.shadowXOffset
    shadowVerticalOffset: Config.theme.shadowYOffset
    shadowBlur: Config.theme.shadowBlur
    shadowColor: Config.resolveColor(Config.theme.shadowColor)
    shadowOpacity: Config.theme.shadowOpacity
}
