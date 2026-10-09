pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.config
import qs.modules.components
import qs.modules.theme

Button {
    id: root

    required property string accessibleName
    property bool iconOnly: true
    property color foregroundColor: Colors.overBackground
    property color backgroundColor: Colors.surfaceContainerHigh
    property color focusColor: Colors.primary
    property real controlWidth: Styling.fontSize(6)
    property real controlHeight: root.controlWidth

    implicitWidth: root.controlWidth
    implicitHeight: root.controlHeight
    width: root.controlWidth
    height: root.controlHeight
    padding: 0
    activeFocusOnTab: true
    Accessible.name: root.accessibleName

    scale: root.down ? 0.94 : 1
    PressBehavior on scale {
        pressed: root.down
    }

    background: StyledRect {
        variant: "common"
        color: root.backgroundColor
        backgroundOpacity: root.hovered || root.down || root.activeFocus ? 0.9 : 0.55
        radius: Styling.radius(-4)
        enableBorder: true
        border.color: root.activeFocus ? root.focusColor : Colors.outlineVariant
    }

    contentItem: Text {
        text: root.text
        color: root.foregroundColor
        font.family: root.iconOnly ? Icons.font : Config.theme.font
        font.pixelSize: root.iconOnly ? Styling.monoFontSize(4) : Styling.fontSize(-2)
        font.weight: root.iconOnly ? Font.Normal : Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
