pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.modules.theme

// Small adapter for the imported game boards; all tokens come from Nonchalant.
Singleton {
    readonly property color accent: Colors.primary
    readonly property color accentHover: Colors.primaryFixedDim
    readonly property color accentText: Colors.overPrimary
    readonly property color blue: Colors.blue
    readonly property color green: Colors.green
    readonly property color yellow: Colors.yellow
    readonly property color red: Colors.red
    readonly property color indicator: Colors.primary
    readonly property color indicatorWarn: Colors.yellow
    readonly property color indicatorTimer: Colors.green
    readonly property color indicatorBad: Colors.error
    readonly property color indicatorDim: Colors.outlineVariant
    readonly property color text: Colors.overSurface
    readonly property color textMuted: Colors.overSurfaceVariant
    readonly property color island: Colors.surfaceContainerLowest
    readonly property color scrim: Colors.scrim
    readonly property color scrimText: Colors.overSurface
    readonly property color hairline: Colors.outlineVariant
    readonly property string fontFamily: Config.theme.font
    readonly property string fontMono: Config.theme.monoFont
    readonly property real fontSizeLabel: Styling.fontSize(-4)
    readonly property real fontSizeSmall: Styling.fontSize(-2)
    readonly property real fontSizeMedium: Styling.fontSize(0)
    readonly property real fontSizeLarge: Styling.fontSize(4)
    readonly property real radiusSmall: Styling.radius(-4)
    readonly property real radiusMedium: Styling.radius(0)
    readonly property real radiusLarge: Styling.radius(4)
    readonly property real radiusPill: Styling.radius(1000)
    readonly property int durationFast: Config.animDuration / 4
    readonly property int durationMedium: Config.animDuration / 2
    readonly property int spectrumBar: Styling.fontSize(0) / 2
    readonly property real spectrumGap: Styling.fontSize(-4)
    readonly property real spectrumFloor: Styling.fontSize(-2)
    readonly property real spectrumCurve: 0.5
    readonly property real spectrumBase: 0.15
    readonly property real spectrumTip: 0.8
    readonly property int easing: Easing.OutCubic

    function surfaceIn(window: var): color {
        return Colors.surfaceContainer
    }

    function surfaceHoverIn(window: var): color {
        return Colors.surfaceContainerHigh
    }

    function borderIn(window: var): color {
        return Colors.outlineVariant
    }
}