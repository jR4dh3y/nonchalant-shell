pragma ComponentBehavior: Bound

import QtQuick

// Detached surfaces keep popup chrome around their optional content layer.
StyledRect {
    id: root

    variant: "popup"
    property string contentVariant: ""
    property real contentInset: 8

    StyledRect {
        anchors.fill: parent
        anchors.margins: Math.max(root.contentInset, root.border.width)
        visible: root.contentVariant !== ""
        variant: root.contentVariant || "transparent"
        radius: Math.max(0, root.radius - anchors.margins)
        enableBorder: false
    }
}
