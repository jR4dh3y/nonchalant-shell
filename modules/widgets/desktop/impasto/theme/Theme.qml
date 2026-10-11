// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T H E M E                                                              │
// │   design tokens · consumed by every component                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.modules.theme

Singleton {
    id: root

    // The island and its glass/solid ground are fixed parts of Impasto's
    // drawing language; palette-derived ink stays connected to Nonchalant.
    readonly property color island: "#000000"
    readonly property real terminalTint: 0.22
    readonly property real terminalOpacity: 0.90
    readonly property color terminalGround: Qt.rgba(root.accent.r * root.terminalTint,
        root.accent.g * root.terminalTint, root.accent.b * root.terminalTint, root.terminalOpacity)

    readonly property string deskStyle: Config.desktop.ground || "solid"
    readonly property bool deskSolid: root.deskStyle !== "glass"
    readonly property bool deskGlass: root.deskStyle === "glass"
    readonly property bool glass: root.deskGlass

    function groundOf(style: string): color {
        return style === "glass" ? root.terminalGround : root.island
    }

    function rimOf(style: string): color {
        return style === "glass" ? Qt.rgba(1, 1, 1, 0.20) : "#262626"
    }

    readonly property color islandSurface: "#141414"
    readonly property color islandSurfaceHover: "#1f1f1f"
    readonly property color islandBorder: "#262626"

    function veilOf(style: string): color {
        return style === "glass" ? Qt.rgba(1, 1, 1, 0.08) : root.islandSurface
    }

    function veilHoverOf(style: string): color {
        return style === "glass" ? Qt.rgba(1, 1, 1, 0.14) : root.islandSurfaceHover
    }

    function veilLineOf(style: string): color {
        return style === "glass" ? Qt.rgba(1, 1, 1, 0.12) : root.islandBorder
    }

    function styleIn(window: var): string {
        return !!window && window.glassy === true
            ? (window.groundStyle ?? root.deskStyle) : "classic"
    }

    function surfaceIn(window: var): color {
        return root.veilOf(root.styleIn(window))
    }

    function surfaceHoverIn(window: var): color {
        return root.veilHoverOf(root.styleIn(window))
    }

    function borderIn(window: var): color {
        return root.veilLineOf(root.styleIn(window))
    }

    // These source semantic colours are wallpaper-independent status signals.
    readonly property color indicator: "#ffffff"
    readonly property color indicatorDim: "#4d4d4d"
    readonly property color indicatorGood: "#32d74b"
    readonly property color indicatorWarn: "#ffd60a"
    readonly property color indicatorBad: "#ff453a"
    readonly property color indicatorTimer: "#64d2ff"

    readonly property color scrimText: "#ffffff"
    readonly property color hairline: "#20ffffff"

    // Palette-derived semantic ink roles.
    property color surface: Colors.surface
    property color text: Colors.overSurface
    property color textMuted: Colors.overSurfaceVariant
    property color accent: Colors.primary
    property color accentHover: Colors.primaryFixedDim
    property color accentText: Colors.overPrimary
    readonly property color red: Colors.red
    readonly property color green: Colors.green
    readonly property color yellow: Colors.yellow
    readonly property color blue: Colors.blue

    readonly property color paperWash: "#c4ffffff"
    readonly property color paperInk: "#1c1c1e"
    readonly property color paperInkMuted: "#8a1c1c1e"
    readonly property color paperLine: "#261c1c1e"
    readonly property int paperRadius: 10

    readonly property color stickerPaper: "#fbf7ee"
    readonly property real stickerWash: 0.45
    readonly property real stickerDeep: 0.62
    readonly property real stickerEdge: 0.028
    readonly property real stickerLean: 5

    readonly property var githubLevels: [
        "#26292e", "#0e4429", "#006d32", "#26a641", "#39d353"
    ]
    readonly property int paletteTransition: 260

    Behavior on surface { ColorAnimation { duration: root.paletteTransition } }
    Behavior on text { ColorAnimation { duration: root.paletteTransition } }
    Behavior on textMuted { ColorAnimation { duration: root.paletteTransition } }
    Behavior on accent { ColorAnimation { duration: root.paletteTransition } }
    Behavior on accentHover { ColorAnimation { duration: root.paletteTransition } }
    Behavior on accentText { ColorAnimation { duration: root.paletteTransition } }

    readonly property int spectrumBar: 10
    readonly property int spectrumGap: 6
    readonly property int spectrumFloor: 3
    readonly property real spectrumBase: 0.95
    readonly property real spectrumTip: 0.25
    readonly property real spectrumCurve: 0.55

    // Grid and surface geometry are upstream source values, not shell styling.
    readonly property int desktopCell: 86
    readonly property int desktopCellLargest: 108
    readonly property int desktopGutter: 18
    readonly property int desktopStride: root.desktopCell + root.desktopGutter
    readonly property int desktopRadius: 22
    // The source default; Nonchalant has no bar-height setting for this ring size.
    readonly property int capsuleHeight: 32

    readonly property int cardPadding: 16
    readonly property int cardMark: 44
    readonly property int cardGap: 14
    readonly property int cardRow: 22
    readonly property int cardRowGap: 8
    readonly property int cardFigure: 24
    readonly property int cardInset: 4
    readonly property int cardLabel: 84
    readonly property int cardWidth: 380

    function cardHeight(rows: int, extra: int): int {
        const body = rows * root.cardRow + Math.max(0, rows - 1) * root.cardRowGap + (extra ?? 0)
        return 2 * (root.cardInset + root.cardPadding) + root.cardMark
            + (body > 0 ? root.cardGap + body : 0)
    }

    readonly property int dockMenuWidth: 250
    readonly property int dockMenuRow: 30
    readonly property int dockMenuPadding: 6

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 18
    readonly property int radiusPill: 999
    readonly property real pictureCorner: 0.24

    readonly property real glassEdge: 0.12
    readonly property color glassSheen: Qt.rgba(1, 1, 1, 0.10)
    readonly property int glassSheenDepth: 48

    readonly property int shadowRange: 14
    readonly property real shadowOpacity: 0.5
    readonly property color shadowColor: "#000000"
    readonly property int shadowSpread: 4

    readonly property int durationFast: 140
    readonly property int durationMedium: 200
    readonly property int durationMorph: 380
    readonly property int easing: Easing.OutCubic
    readonly property bool lively: true

    FontLoader {
        id: interFont
        source: Quickshell.shellPath("assets/fonts/impasto/Inter[opsz,wght].ttf")
    }

    FontLoader {
        id: signatureFont
        source: Quickshell.shellPath("assets/fonts/impasto/GrapeNuts-Regular.ttf")
    }

    readonly property var installedFonts: {
        const families = Qt.fontFamilies()
        const bundled = []
        if (interFont.status === FontLoader.Ready && interFont.name !== "")
            bundled.push(interFont.name)
        if (signatureFont.status === FontLoader.Ready && signatureFont.name !== "")
            bundled.push(signatureFont.name)
        return families.concat(bundled)
    }

    function fontOf(stack: string): string {
        const names = stack.split(",")
        for (const name of names) {
            const family = name.trim()
            if (family !== "" && root.installedFonts.indexOf(family) !== -1)
                return family
        }
        return names[names.length - 1].trim()
    }

    readonly property string fontFamily: root.fontOf(
        Config.desktop.fontFamily ?? "Inter, Cantarell, SF Pro Text, sans-serif")
    readonly property string fontMono: root.fontOf(
        Config.desktop.fontMono ?? "JetBrainsMono Nerd Font Mono, monospace")
    readonly property string fontDisplay: root.fontFamily === "Inter"
        ? root.fontOf("Inter Display, Inter") : root.fontFamily
    readonly property string fontSignature: signatureFont.status === FontLoader.Ready
        && signatureFont.name !== ""
        ? signatureFont.name : root.fontOf(`Grape Nuts, Georgia, ${root.fontFamily}`)
    readonly property string fontHand: Config.desktop.notesHandwriting
        ? root.fontSignature : root.fontFamily

    readonly property int fontSizeLabel: 10
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeRegular: 13
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeWidget: 30
    readonly property int fontSizeDisplay: 68
}
