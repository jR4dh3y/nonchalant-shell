pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme
import qs.modules.widgets.desktop

import "../faces"

Item {
    id: root

    property string moduleId: ""
    property string family: "2x2"
    property var ink
    property var row: null
    property bool active: false

    readonly property bool wide: root.family === "4x2" || root.family === "8x2"
    readonly property bool large: root.family === "4x4"
    readonly property bool showMediaPlay: root.moduleId === "media" && root.family === "2x2"
    readonly property bool showMediaTransport: root.moduleId === "media" && root.wide
    readonly property bool showTimerControls: root.moduleId === "timer" && root.family !== "2x2"
    readonly property real controlSize: Math.min(Styling.fontSize(4), root.height * 0.18)
    readonly property color inkColor: root.ink?.text ?? Colors.overBackground
    readonly property color mutedColor: root.ink?.muted ?? Colors.overSurfaceVariant
    readonly property color accentColor: root.ink?.accent ?? Colors.primary
    readonly property string label: data.label
    readonly property string reading: data.reading
    readonly property string note: data.note
    readonly property string glyph: data.glyph
    readonly property string seed: root.row?.key ?? root.moduleId
    readonly property real tilt: {
        let hash = 0
        for (let index = 0; index < root.seed.length; index++)
            hash = (hash * 31 + root.seed.charCodeAt(index)) >>> 0
        return (hash % 7 - 3) * 1.25
    }
    readonly property bool detailed: root.large
        && ["media", "calendar", "tasks", "clock"].includes(root.moduleId)
    readonly property real patchRoundness: {
        switch (root.moduleId) {
        case "media": case "clock": case "timer": case "pet": return 0.5
        case "stats": case "github": case "tasks": return 0.18
        case "weather": return 0.38
        default: return 0.3
        }
    }
    readonly property string petGlyph: {
        switch (Config.desktop.petStyle) {
        case "plush": return "◉‿◉"
        case "pixel": return "▦"
        case "paper": return "◕"
        default: return PetService.speciesInfo?.id === "sol" ? "☀" : "◕"
        }
    }
    readonly property string patchVariant: {
        switch (root.moduleId) {
        case "battery": case "timer": case "volume": case "media": case "stats": return "primary"
        case "weather": case "brightness": case "pet": case "claude": return "tertiary"
        case "network": case "bluetooth": case "github": case "clock": case "calendar": case "tasks": case "codex": return "secondary"
        case "updates": case "games": return "error"
        default: return "primary"
        }
    }

    WidgetFace {
        id: data
        visible: false
        moduleId: root.moduleId
        family: root.family
        ink: root.ink
        row: root.row
        active: root.active
    }

    WidgetShadow { radius: Styling.radius(-2) }
    StyledRect {
        id: sticker
        anchors.fill: parent
        variant: "common"
        radius: Styling.radius(-2)
        backgroundOpacity: 0.24

        StyledRect {
            id: paper
            anchors.fill: parent
            anchors.margins: root.large ? 14 : root.width > 300 ? 12 : 8
            variant: "pane"
            radius: Styling.radius(-4)
            backgroundOpacity: 0.72

            StyledRect {
                id: patch
                x: root.wide ? parent.width * 0.04 : parent.width * 0.08
                y: root.wide ? parent.height * 0.18 : parent.height * 0.1
                width: root.wide ? parent.height * 0.58 : parent.width * 0.52
                height: width
                variant: root.patchVariant
                radius: width * root.patchRoundness
                rotation: root.tilt
                backgroundOpacity: 0.72

                StickerArt {
                    anchors.fill: parent
                    moduleId: root.moduleId
                    glyph: root.moduleId === "pet" ? root.petGlyph : root.glyph
                    progress: data.progress
                    now: data.now
                    foreground: root.inkColor
                    accent: root.accentColor
                    muted: root.mutedColor
                    row: root.row
                    interactive: root.active
                }
                FaceActionButton {
                    visible: root.showMediaPlay
                    x: parent.width * 0.6
                    y: parent.height * 0.6
                    controlWidth: Math.min(parent.width * 0.36, root.controlSize * 1.4)
                    controlHeight: controlWidth
                    text: MprisController.isPlaying ? Icons.pause : Icons.play
                    accessibleName: MprisController.isPlaying ? "Pause playback" : "Start playback"
                    foregroundColor: Colors.overPrimary
                    backgroundColor: root.ink?.green ?? Colors.green
                    enabled: MprisController.canTogglePlaying
                    opacity: enabled ? 1 : 0.45
                    onClicked: MprisController.togglePlaying()
                }
            }

            StyledRect {
                id: tag
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: root.wide ? 10 : 8
                anchors.rightMargin: root.wide ? 12 : 10
                rotation: -root.tilt * 0.65
                width: Math.min(parent.width * 0.42, tagText.implicitWidth + 20)
                height: tagText.implicitHeight + 12
                variant: root.patchVariant
                radius: Styling.radius(-5)
                backgroundOpacity: 0.45
                enableBorder: false

                Text {
                    id: tagText
                    anchors.centerIn: parent
                    width: parent.width - Styling.fontSize(0)
                    text: root.label.toUpperCase()
                    color: root.inkColor
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-2)
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }

            Text {
                visible: !root.detailed
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: root.wide ? 16 : 12
                anchors.bottomMargin: root.wide ? 14 : 10
                text: root.moduleId === "games" || root.moduleId === "pet" ? "✦" : "✧"
                color: root.accentColor
                font.family: Config.theme.monoFont
                font.pixelSize: root.large ? Styling.fontSize(8) : Styling.fontSize(4)
            }

            Column {
                visible: !root.detailed
                anchors.left: root.wide ? patch.right : parent.left
                anchors.right: root.wide ? tag.left : parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: root.wide ? 12 : 10
                anchors.rightMargin: root.wide ? 10 : 10
                anchors.bottomMargin: root.wide
                    ? 12 + ((root.showMediaTransport || root.showTimerControls)
                        ? root.controlSize + Styling.fontSize(-3) : 0)
                    : 10
                spacing: Styling.fontSize(-4)

                Text {
                    width: parent.width
                    text: root.reading
                    color: root.inkColor
                    font.family: Config.theme.font
                    font.pixelSize: root.large ? Styling.fontSize(10) : root.wide ? Styling.fontSize(5) : Styling.fontSize(3)
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.note !== ""
                    text: root.note
                    color: root.mutedColor
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    elide: Text.ElideRight
                }
            }
            Loader {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Styling.fontSize(0)
                anchors.rightMargin: Styling.fontSize(0)
                anchors.bottomMargin: Styling.fontSize(-1)
                height: parent.height * 0.46
                active: root.visible && root.detailed && root.moduleId !== "calendar"
                sourceComponent: detail
            }
            MediaTransport {
                visible: root.showMediaTransport
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Styling.fontSize(-2)
                buttonSize: root.controlSize
                foregroundColor: root.inkColor
                accentColor: root.ink?.green ?? Colors.green
                accentTextColor: Colors.overPrimary
                surfaceColor: root.ink?.paper ?? Colors.surfaceContainerHigh
            }
            TimerControls {
                visible: root.showTimerControls
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Styling.fontSize(-2)
                buttonSize: root.controlSize
                foregroundColor: root.inkColor
                accentColor: root.ink?.green ?? Colors.green
                accentTextColor: Colors.overPrimary
                surfaceColor: root.ink?.paper ?? Colors.surfaceContainerHigh
            }
        }

        StyledRect {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.large ? 10 : 6
            width: root.wide ? parent.width * 0.2 : parent.width * 0.28
            height: Math.max(6, root.height * 0.045)
            rotation: root.moduleId === "media" || root.moduleId === "calendar" ? -5 : 4
            variant: "tertiary"
            radius: Styling.radius(-7)
            backgroundOpacity: 0.55
            enableBorder: false
        }
    }

    Loader {
        anchors.fill: parent
        anchors.margins: root.family === "4x4" ? Styling.fontSize(0) : Styling.fontSize(-1)
        z: 2
        active: root.visible && root.moduleId === "calendar" && root.family !== "2x2"
        sourceComponent: calendar
    }

    Component {
        id: detail
        FaceDetail {
            anchors.fill: parent
            moduleId: root.moduleId
            family: root.family
            ink: root.ink
            now: data.now
            showMediaArt: false
            theme: "sticker"
            row: root.row
            interactive: root.active
        }
    }

    Component {
        id: calendar
        CalendarTasksView {
            anchors.fill: parent
            family: root.family
            theme: "sticker"
            ink: root.ink
            row: root.row
            interactive: root.active
        }
    }
}

