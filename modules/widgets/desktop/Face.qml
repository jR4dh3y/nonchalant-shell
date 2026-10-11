// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F   A   C   E                                                          │
// │   picks a widget face by module, family and theme                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import qs.modules.widgets.desktop.impasto.services

import "faces"
import "faces/analogue"
import "faces/sticker"

// Source dispatch is unchanged; activation belongs to the Nonchalant host.
Item {
    id: root

    property string moduleId: ""
    property string family: "4x2"
    property string theme: DesktopService.themeOf(root.row)
    property var ink: DesktopService.inkFor(root.row)
    property var row: null
    property bool active: false

    readonly property bool shared: root.moduleId === "notes" || root.moduleId === "spectrum"
    readonly property bool analogue: root.theme === "analogue" && !root.shared
    readonly property bool sticker: root.theme === "sticker" && !root.shared
    readonly property bool effectiveActive: root.active && root.visible
        && root.width > 0 && root.height > 0
        && (root.moduleId === "spectrum" || DesktopService.opacityOf(root.row) > 0)

    Loader {
        anchors.fill: parent
        active: root.visible && root.width > 0 && root.height > 0
            && (root.moduleId === "spectrum" || DesktopService.opacityOf(root.row) > 0)
        sourceComponent: {
            if (root.moduleId === "lyrics")
                return lyrics
            if (root.analogue)
                return analogue
            if (root.sticker)
                return sticker
            if (root.family === "2x2")
                return squares
            if (root.family === "4x4")
                return larges
            if (root.family === "8x2")
                return bands
            return wides
        }
    }

    Component {
        id: lyrics
        LyricsFace { family: root.family; ink: root.ink; active: root.effectiveActive }
    }

    Component {
        id: analogue
        Analogue { moduleId: root.moduleId; family: root.family; ink: root.ink; row: root.row }
    }

    Component {
        id: sticker
        Sticker { moduleId: root.moduleId; family: root.family; ink: root.ink; row: root.row }
    }

    Component {
        id: squares
        Squares { moduleId: root.moduleId; ink: root.ink; row: root.row; active: root.effectiveActive }
    }

    Component {
        id: wides
        Wides { moduleId: root.moduleId; ink: root.ink; row: root.row; active: root.effectiveActive }
    }

    Component {
        id: larges
        Larges { moduleId: root.moduleId; ink: root.ink; row: root.row; active: root.effectiveActive }
    }

    Component {
        id: bands
        Bands { moduleId: root.moduleId; ink: root.ink; row: root.row; active: root.effectiveActive }
    }
}
