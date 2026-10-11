// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T   A   G                                                              │
// │   a pill sticker with words on it                                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// A pill sticker with words on it: `reading` over `note`, as wide as they
// need and never wider than `room`. `size` scales the type, 1 on a 4×2.
Cut {
    id: root

    property string reading: ""
    property string note: ""
    property color hue: Theme.accent
    property real room: 240
    property real size: 1

    readonly property real padding: 18 * root.size

    Tone { id: tone; hue: root.hue }

    shape: "pill"
    edge: Math.max(2.5, Theme.fontSizeLarge * root.size * 0.25)
    fill: tone.fill
    // Rounded up, or a width a hair short of the text's elides it.
    width: Math.min(root.room, Math.ceil(Math.max(topWidth.advanceWidth,
        root.note !== "" ? bottomWidth.advanceWidth : 0)) + 2 + 2 * root.padding + 2 * root.edge)
    height: words.implicitHeight + 2 * root.padding * 0.62 + 2 * root.edge

    // The words' own widths, measured apart from the Text items, whose
    // widths are set from the tag's.
    TextMetrics { id: topWidth; font: top.font; text: root.reading }
    TextMetrics { id: bottomWidth; font: bottom.font; text: root.note }

    Column {
        id: words

        anchors.verticalCenter: parent.verticalCenter
        x: root.padding + root.edge
        width: root.width - 2 * (root.padding + root.edge)
        spacing: 0

        Text {
            id: top

            width: parent.width
            text: root.reading
            elide: Text.ElideRight
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontSizeRegular
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(Theme.fontSizeLarge * 1.15 * root.size)
            font.weight: Font.Bold
            color: tone.deep
        }

        Text {
            id: bottom

            width: parent.width
            visible: root.note !== ""
            text: root.note
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(Theme.fontSizeSmall * root.size)
            font.weight: Font.Medium
            color: tone.deep
            opacity: 0.75
        }
    }
}
