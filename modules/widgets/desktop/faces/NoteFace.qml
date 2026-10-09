pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme

Item {
    id: root

    property string family: "2x2"
    property var ink
    property var row: null
    property bool active: false

    readonly property var note: NotesService.noteFor(root.row)
    readonly property bool band: root.family === "8x2"
    readonly property color textColor: root.ink?.text ?? Colors.overBackground
    readonly property color mutedColor: root.ink?.muted ?? Colors.overSurfaceVariant
    readonly property color paperColor: NotesService.paperOf(root.note?.tint ?? "yellow")

    StyledRect {
        anchors.fill: parent
        variant: "common"
        color: root.paperColor
        radius: Styling.radius(-2)
        enableShadow: Config.desktop.widgetShadow

        Column {
            anchors.fill: parent
            anchors.margins: root.width > 300 ? Styling.fontSize(2) : Styling.fontSize(0)
            spacing: Styling.fontSize(-3)

            Text {
                width: parent.width
                visible: (root.note?.title ?? "").trim() !== ""
                text: root.note?.title ?? ""
                color: root.textColor
                font.family: Config.desktop.notesHandwriting ? Config.defaultFont : Config.theme.font
                font.pixelSize: root.family === "2x2" ? Styling.fontSize(-1) : Styling.fontSize(1)
                font.italic: Config.desktop.notesHandwriting
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                height: root.band ? parent.height : parent.height - (root.note?.title ? Styling.fontSize(5) : 0)
                text: root.note?.text || "No notes yet"
                color: root.textColor
                font.family: Config.desktop.notesHandwriting ? Config.defaultFont : Config.theme.font
                font.pixelSize: root.family === "2x2" ? Styling.fontSize(0) : Styling.fontSize(2)
                font.italic: Config.desktop.notesHandwriting
                wrapMode: root.band ? Text.NoWrap : Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: root.band ? 1 : 5
                verticalAlignment: Text.AlignVCenter
            }

        }
    }

}
