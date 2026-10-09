pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: root

    required property ShellScreen screen

    width: 1
    height: 1

    SpectrumEdgeSurface {
        targetScreen: root.screen
    }

    NoteDeckSurface {
        targetScreen: root.screen
    }
}