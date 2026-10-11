// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   L   I   P   B   O   A   R   D                                      │
// │   clipboard drawing for the tasks face                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services
import qs.modules.widgets.desktop.impasto.components

// A clipboard with the tasks down it as TaskRows: the checkbox completes a
// task, the rest of the row opens the board on it. A title along the top when
// there is room.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property var tasks: []
    property string title: ""
    property var row: null

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: root.ink.raised
        border.color: root.ink.border
        border.width: 1
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: -6
        width: 40
        height: 16
        radius: 5
        color: root.ink.muted
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: -10
        width: 16
        height: 8
        radius: 3
        color: root.ink.text
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        anchors.topMargin: 18
        spacing: 2

        Text {
            visible: root.title !== ""
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: root.ink.text
        }

        Item { width: 1; height: root.title !== "" ? 4 : 0 }

        Repeater {
            model: root.tasks

            TaskRow {
                required property var modelData

                width: parent.width
                task: modelData
                dated: false
                ink: ({
                    text: root.ink.text, muted: root.ink.muted, accent: root.ink.accent,
                    accentText: root.ink.accentText, raised: root.ink.raised, red: Theme.red
                })
                onOpened: {
                    TasksService.open(modelData.key, root.row)
                    ModuleService.requestPanel("board", root.row)
                }
            }
        }
    }
}
