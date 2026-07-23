import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

// Intentionally inert — same reason as Shadow.qml. Do not re-enable for Text.
MultiEffect {
    shadowEnabled: false
    blurEnabled: false
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 2
    shadowBlur: 0.5
    shadowColor: Config.resolveColor(Config.theme.shadowColor)
    shadowOpacity: 1
}
