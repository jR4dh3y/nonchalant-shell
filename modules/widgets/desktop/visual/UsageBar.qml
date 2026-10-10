pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components
import qs.modules.theme

StyledRect {
    id: root

    required property real progress
    required property color fillColor

    implicitHeight: Styling.fontSize(-5)
    variant: "pane"
    radius: height / 2
    backgroundOpacity: 0.35
    enableBorder: false

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.progress))
        height: parent.height
        radius: height / 2
        color: root.fillColor
    }
}