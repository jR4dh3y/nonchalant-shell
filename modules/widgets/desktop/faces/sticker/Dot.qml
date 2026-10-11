// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D   O   T                                                              │
// │   a round sticker with a glyph · a button                                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme

// A round sticker with one glyph on it, pressed like a button when something
// listens to `clicked`.
Cut {
    id: root

    property string glyph: ""
    property color hue: Theme.accent
    property bool live: true

    signal clicked()

    Tone { id: tone; hue: root.hue }

    shape: "circle"
    fill: tone.fill
    lean: Theme.stickerLean * 0.6

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: Theme.fontMono
        font.pixelSize: Math.round(root.side * 0.4)
        color: tone.deep
    }

    HoverHandler {
        enabled: root.live
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.live
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }
}
