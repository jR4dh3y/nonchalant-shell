pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components
import qs.modules.theme
import qs.config

Item {
    id: root

    required property string text
    property string icon: ""
    property bool highlighted: false
    property bool enabled: true
    signal clicked()

    implicitWidth: label.implicitWidth + 2 * Styling.fontSize(0)
    implicitHeight: Math.max(Styling.fontSize(0) * 2.5, label.implicitHeight + Styling.fontSize(-1))
    scale: 1

    Accessible.role: Accessible.Button
    Accessible.name: root.text

    PressBehavior on scale {
        pressed: press.pressed
    }

    StyledRect {
        anchors.fill: parent
        variant: root.highlighted ? "primary" : "common"
        opacity: root.enabled ? 1 : 0.45
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.icon === "" ? root.text : `${root.icon}  ${root.text}`
        color: root.highlighted ? Colors.overPrimary : Colors.overSurface
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    HoverHandler {
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        id: press
        enabled: root.enabled
        gesturePolicy: TapHandler.ReleaseWithinBounds
        acceptedButtons: Qt.LeftButton
        onTapped: root.clicked()
    }
}