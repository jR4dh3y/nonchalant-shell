// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T   O   N   E                                                          │
// │   a palette hue as a sticker wears it · fill and print                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme

// One palette hue as a sticker wears it: `fill` is the hue washed towards the
// vinyl white, `deep` the same hue darkened for what is printed on it, and
// `hue` itself for a ring or a bar.
QtObject {
    id: root

    property color hue: Theme.accent

    function mix(from: color, to: color, share: real): color {
        return Qt.rgba(from.r + (to.r - from.r) * share, from.g + (to.g - from.g) * share,
                       from.b + (to.b - from.b) * share, 1)
    }

    readonly property color fill: root.mix(root.hue, Theme.stickerPaper, Theme.stickerWash)
    readonly property color deep: root.mix(root.hue, Theme.island, Theme.stickerDeep)
    readonly property color track: Qt.rgba(root.deep.r, root.deep.g, root.deep.b, 0.14)
}
