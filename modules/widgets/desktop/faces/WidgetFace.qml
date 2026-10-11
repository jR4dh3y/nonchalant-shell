// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W   I   D   G   E   T       F   A   C   E                              │
// │   the grid every family is laid out on                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// The layout every Modern face shares: the mark top left, the label top right,
// the main reading along the bottom with a caption under it. Keeping this fixed
// lets widgets line up as a set. Wide faces give part of their width to `extra`
// (a sparkline, the forecast, the transport); large ones add `body` in the
// middle.
Item {
    id: root

    // The module's name in the corner, so widgets identify themselves without a
    // hover.
    property string label: ""

    // The main value, as large as the face allows.
    property string reading: ""

    // Qualifies the reading: time remaining, location, the timer's label. One
    // line, elided.
    property string note: ""

    // Colours resolved by the widget from its ink and style.
    property var ink: DesktopService.inkFor(null)

    // Warning colours do not follow the palette; modules pass one in when their
    // reading needs it.
    property color tint: root.ink.text

    // The reading's size: the same for every family except the band, which has
    // height to spare.
    property int readingSize: Theme.fontSizeWidget

    // The fraction of the width given to `extra`; 0 for a square. Declared
    // rather than derived from `extra`'s contents, because bindings do not
    // track list properties.
    property real extraShare: 0

    // The mark, sized up to the box.
    default property alias mark: markBox.data

    // Wide-face content.
    property alias extra: extraBox.data

    // Large-face content, between the mark and the reading.
    property alias body: bodyBox.data

    // Wide faces get more padding so they do not look like a stretched square.
    readonly property int padding: root.width > 300 ? 22 : 18

    readonly property real textWidth:
        root.width - 2 * root.padding - root.width * root.extraShare

    Item {
        id: markBox

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: root.padding
        anchors.topMargin: root.padding
        width: 40
        height: 40
    }

    Text {
        id: name

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: root.padding
        anchors.topMargin: root.padding + 4
        anchors.left: markBox.right
        anchors.leftMargin: 8

        text: root.label
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        color: root.ink.muted
    }

    Item {
        id: bodyBox

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: markBox.bottom
        anchors.bottom: readings.top
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: 12
        anchors.bottomMargin: 12
    }

    // Anchored to the bottom, so the reading stays put with or without a
    // caption.
    Column {
        id: readings

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.padding
        anchors.bottomMargin: root.padding
        width: root.textWidth
        spacing: 2

        // Readings range from two characters to "Not connected", so the text
        // shrinks to fit on one line, down to `fontSizeLarge`. `HorizontalFit`,
        // not `Fit`: this item is as tall as its text, so `Fit` has no height
        // to shrink towards.
        Text {
            width: parent.width
            text: root.reading
            elide: Text.ElideRight
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontSizeLarge
            font.family: Theme.fontFamily
            font.pixelSize: root.readingSize
            font.weight: Font.DemiBold
            color: root.tint
        }

        Text {
            width: parent.width
            visible: root.note !== ""
            text: root.note
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: root.ink.muted
        }
    }

    // Under the label rather than beside the mark, so the label has the top
    // right corner to itself.
    Item {
        id: extraBox

        anchors.right: parent.right
        anchors.top: name.bottom
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.padding
        anchors.topMargin: 10
        anchors.bottomMargin: root.padding
        width: Math.max(0, root.width * root.extraShare - root.padding)
    }
}
