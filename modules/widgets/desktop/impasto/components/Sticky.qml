// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S T I C K Y                                                            │
// │   one note as paper · the title, the body in handwriting, the colour     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// A sticky note: pastel paper, a title and a handwritten body, used wherever
// a note appears (deck cards, desktop widget, edge tab, tray). The ink is a
// fixed dark (`Theme.paper*`), not the palette's text colour.
Item {
    id: root

    property var note: null

    // What an empty deck says, on plain paper.
    property string placeholder: ""

    property int padding: 12
    property int titleSize: Theme.fontSizeSmall
    property int bodySize: 16
    property bool showAge: true

    readonly property color paper: NotesService.paperOf(root.note ? root.note.tint : "yellow")
    readonly property bool titled: root.note && (root.note.title ?? "").trim() !== ""
    readonly property string title: root.note ? NotesService.titleOf(root.note) : ""
    readonly property string body: root.note ? NotesService.display(root.note.text) : root.placeholder

    Rectangle {
        anchors.fill: parent
        radius: Theme.paperRadius
        color: root.paper
    }

    Item {
        id: head

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: root.padding - 2
        height: root.titleSize + 8

        Text {
            anchors.left: parent.left
            anchors.right: age.visible ? age.left : parent.right
            anchors.rightMargin: age.visible ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: root.titleSize
            font.weight: Font.DemiBold
            color: root.titled ? Theme.paperInk : Theme.paperInkMuted
        }

        Text {
            id: age

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showAge && root.note !== null
            text: root.note ? NotesService.ageOf(root.note.edited) : ""
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeLabel
            color: Theme.paperInkMuted
        }
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: 4
        anchors.bottomMargin: root.padding
        text: root.body
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        font.family: Theme.fontHand
        font.pixelSize: root.bodySize
        lineHeight: 1.1
        color: root.note ? Theme.paperInk : Theme.paperInkMuted
    }
}
