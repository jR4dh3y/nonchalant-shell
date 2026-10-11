// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S   P   R   E   A   D                                                  │
// │   layout for sticker faces · the sticker, then its tag                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// The layout most sticker faces share: one sticker that is the widget, and a
// tag of words stuck beside it. Neither fills the squares.
//
//   2×2   the sticker, centred, with `line` on a small tag over its foot
//   4×2   the sticker on the left, the tag to its right, `extra` under it
//   8×2   the same, with larger words
//
// The sticker's room is `object`, a square; the face draws inside it.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)
    property string seed: ""

    property string line: ""
    property string reading: ""
    property string note: ""
    property color hue: root.ink.accent

    // Set by faces that fill `extra`, so the tag moves up to make room; a
    // binding cannot count a list property's children.
    property bool filled: false

    default property alias object: objectBox.data
    property alias extra: extraBox.data

    readonly property bool square: root.family === "2x2"
    readonly property bool band: root.family === "8x2"

    readonly property real side: Math.min(root.width, root.height)
    readonly property real objectSide: root.side * (root.square ? 0.98 : 1)

    Item {
        id: objectBox

        width: root.objectSide
        height: root.objectSide
        x: root.square ? (root.width - width) / 2 : (root.height - height) / 2
        y: (root.height - height) / 2 - (root.square && root.line !== "" ? root.side * 0.04 : 0)
    }

    Tag {
        visible: root.square && root.line !== ""
        seed: root.seed + "line"
        hue: root.ink.paper
        reading: root.line
        size: 0.9
        room: root.width * 0.8
        x: root.width - width - root.side * 0.04
        y: root.height - height - root.side * 0.02
    }

    Item {
        id: words

        visible: !root.square
        x: objectBox.x + objectBox.width + root.side * 0.02
        width: root.width - x - root.side * 0.06
        height: root.height

        Tag {
            id: tag

            seed: root.seed + "tag"
            hue: root.hue
            reading: root.reading
            note: root.note
            size: root.band ? 1.5 : 1.2
            room: words.width
            y: root.filled ? words.height * 0.05 : (words.height - height) / 2
        }

        Item {
            id: extraBox

            y: tag.y + tag.height + root.side * 0.04
            x: root.side * 0.03
            width: words.width - x
            height: Math.max(0, words.height - y - root.side * 0.04)
        }
    }
}
