// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I   N   S   T   R   U   M   E   N   T                                  │
// │   layout for analogue faces · drawing, then text                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// The layout for Analogue faces: the object (a dial, a gauge, a record) takes a
// square, and the text goes beside or under it.
//
//   2×2   the object, centred, with one small line under it
//   4×2   the object on the left; the reading and the note to its right, and
//         `extra` under them
//   8×2   as 4×2, wider, with a larger reading
//   4×4   the 4×2 layout on top of `body`
//
// Faces that do not fit this (the month, two gauges side by side) lay
// themselves out.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)

    // The line under the object on a 2×2; empty when the object says it all.
    property string line: ""

    // Beside the object on wide faces: the value and what qualifies it.
    property string reading: ""
    property string note: ""
    property color tint: root.ink.text

    // Set by faces that fill `extra`, so the text moves up to make room; a
    // binding cannot count a list property's children.
    property bool filled: false

    default property alias object: objectBox.data
    property alias extra: extraBox.data
    property alias body: bodyBox.data

    readonly property bool square: root.family === "2x2"
    readonly property bool large: root.family === "4x4"
    readonly property bool band: root.family === "8x2"

    readonly property int padding: root.square ? 18 : 22

    // The top region: the whole face, or the upper half of a large one.
    readonly property real upper: root.large ? root.height / 2 : root.height
    readonly property real objectSide: root.upper - 2 * root.padding
    readonly property int lineRoom: root.square && root.line !== "" ? 26 : 0

    Item {
        id: objectBox

        x: root.padding
        y: root.padding
        width: root.square ? root.width - 2 * root.padding : root.objectSide
        height: root.square
            ? root.height - 2 * root.padding - root.lineRoom : root.objectSide
    }

    Text {
        visible: root.square && root.line !== ""
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.padding - 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width - 2 * root.padding
        text: root.line
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: root.ink.muted
    }

    Column {
        id: words

        visible: !root.square
        anchors.left: objectBox.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: root.padding
        y: root.filled ? root.padding + 6 : root.upper / 2 - height / 2
        spacing: 2

        // Shrinks to fit on one line, like WidgetFace's reading.
        Text {
            width: parent.width
            text: root.reading
            elide: Text.ElideRight
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontSizeLarge
            font.family: Theme.fontFamily
            font.pixelSize: root.band ? Theme.fontSizeDisplay * 0.65 : Theme.fontSizeWidget
            font.weight: Font.DemiBold
            color: root.tint
        }

        Text {
            width: parent.width
            visible: root.note !== ""
            text: root.note
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular
            color: root.ink.muted
        }
    }

    Item {
        id: extraBox

        visible: !root.square
        anchors.left: words.left
        anchors.right: words.right
        y: words.y + words.height + 10
        height: Math.max(0, root.upper - root.padding - y)
    }

    Item {
        id: bodyBox

        visible: root.large
        x: root.padding
        y: root.upper
        width: root.width - 2 * root.padding
        height: root.upper - root.padding
    }
}
