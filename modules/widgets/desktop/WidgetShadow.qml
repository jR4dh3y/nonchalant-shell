pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.modules.theme

Loader {
    id: root

    property real radius: Styling.radius(4)

    anchors.fill: parent
    active: visible && Config.desktop.widgetShadow && Config.theme.shadowOpacity > 0
    z: -1

    sourceComponent: RectangularShadow {
        radius: root.radius
        color: Config.resolveColor(Config.theme.shadowColor)
        opacity: Config.theme.shadowOpacity
        blur: Config.theme.shadowBlur * Styling.fontSize(0)
        offset: Qt.vector2d(Config.theme.shadowXOffset, Config.theme.shadowYOffset)
    }
}
