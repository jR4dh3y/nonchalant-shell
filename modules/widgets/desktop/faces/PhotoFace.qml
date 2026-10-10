pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme
import qs.modules.widgets.desktop

Item {
    id: root

    property string family: "2x2"
    property var ink
    property var row: null
    property bool active: false

    readonly property string source: DesktopWidgetService.pictureOf(root.row)
    readonly property var still: DesktopWidgetService.sizeFor(root.family)
    readonly property bool lost: picture.status === Image.Error
    readonly property bool empty: root.source === "" || root.lost
    readonly property color foreground: root.ink?.text ?? Colors.overBackground
    readonly property color muted: root.ink?.muted ?? Colors.overSurfaceVariant

    WidgetShadow { radius: Styling.radius(-2) }
    StyledRect {
        anchors.fill: parent
        variant: "common"
        radius: Styling.radius(-2)
        color: root.ink?.raised ?? Colors.surfaceContainer
        enableBorder: true

        Image {
            id: picture
            anchors.fill: parent
            visible: !root.empty
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: Math.max(1, (root.still?.width ?? root.width) * 2)
            sourceSize.height: Math.max(1, (root.still?.height ?? root.height) * 2)
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - Styling.fontSize(8)
            spacing: Styling.fontSize(-3)
            visible: root.empty

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.lost ? "󰋪" : "󰋩"
                color: root.foreground
                font.family: Config.theme.monoFont
                font.pixelSize: root.family === "4x4" ? Styling.monoFontSize(12) : Styling.monoFontSize(5)
            }

            Text {
                width: parent.width
                text: root.lost ? "Picture not found" : "No picture"
                horizontalAlignment: Text.AlignHCenter
                color: root.foreground
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: "Choose a photo path in the desktop editor"
                horizontalAlignment: Text.AlignHCenter
                color: root.muted
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                wrapMode: Text.Wrap
                elide: Text.ElideRight
            }
        }
    }

}
