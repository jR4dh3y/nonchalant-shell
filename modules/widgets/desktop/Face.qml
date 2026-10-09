pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services

import "faces"
import "faces/analogue"
import "faces/sticker"

Item {
    id: root

    property string moduleId: ""
    property string family: "4x2"
    property string theme: DesktopWidgetService.themeOf(root.row)
    property var ink: DesktopWidgetService.inkFor(root.row)
    property var row: null
    property bool active: false
    readonly property bool effectiveActive: root.active
        && (root.moduleId === "spectrum" || DesktopWidgetService.opacityOf(root.row) > 0)
    enabled: root.active && !DesktopWidgetService.editing


    Loader {
        anchors.fill: parent
        active: root.visible
            && (root.moduleId === "spectrum" || DesktopWidgetService.opacityOf(root.row) > 0)
        sourceComponent: {
            if (root.moduleId === "notes")
                return noteFace
            if (root.moduleId === "photo")
                return photoFace
            if (root.moduleId === "spectrum")
                return spectrumFace
            if (root.moduleId === "lyrics")
                return lyricsFace
            if (root.theme === "analogue")
                return analogueFace
            if (root.theme === "sticker")
                return stickerFace
            if (root.family === "2x2")
                return squaresFace
            if (root.family === "4x4")
                return largesFace
            if (root.family === "8x2")
                return bandsFace
            return widesFace
        }
    }

    Component {
        id: noteFace
        NoteFace { anchors.fill: parent; family: root.family; ink: root.ink; row: root.row; active: root.effectiveActive }
    }

    Component {
        id: photoFace
        PhotoFace { anchors.fill: parent; family: root.family; ink: root.ink; row: root.row; active: root.effectiveActive }
    }

    Component {
        id: spectrumFace
        SpectrumFace { anchors.fill: parent; family: root.family; ink: root.ink; row: root.row; active: root.effectiveActive }
    }

    Component {
        id: lyricsFace
        LyricsFace { anchors.fill: parent; family: root.family; ink: root.ink; active: root.effectiveActive }
    }

    Component {
        id: analogueFace
        Analogue { anchors.fill: parent; moduleId: root.moduleId; family: root.family; ink: root.ink; row: root.row; active: root.effectiveActive }
    }

    Component {
        id: stickerFace
        Sticker { anchors.fill: parent; moduleId: root.moduleId; family: root.family; ink: root.ink; row: root.row; active: root.effectiveActive }
    }

    Component {
        id: squaresFace
        Squares { anchors.fill: parent; moduleId: root.moduleId; ink: root.ink; row: root.row; active: root.effectiveActive }
    }

    Component {
        id: widesFace
        Wides { anchors.fill: parent; moduleId: root.moduleId; ink: root.ink; row: root.row; active: root.effectiveActive }
    }

    Component {
        id: largesFace
        Larges { anchors.fill: parent; moduleId: root.moduleId; ink: root.ink; row: root.row; active: root.effectiveActive }
    }

    Component {
        id: bandsFace
        Bands { anchors.fill: parent; moduleId: root.moduleId; ink: root.ink; row: root.row; active: root.effectiveActive }
    }
}