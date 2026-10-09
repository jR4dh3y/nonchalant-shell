pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme

import "../faces"

Item {
    id: root

    property string moduleId: ""
    property string family: "2x2"
    property var ink
    property var row: null
    property bool active: false

    readonly property real side: Math.min(root.width, root.height)
    readonly property bool clockFace: root.moduleId === "clock"
    readonly property bool recordFace: root.moduleId === "media"
    readonly property bool wide: root.family === "4x2" || root.family === "8x2"
    readonly property bool showMediaControls: root.recordFace && root.family !== "2x2"
    readonly property bool showTimerControls: root.moduleId === "timer" && root.family !== "2x2"
    readonly property real controlSize: Math.min(Styling.fontSize(4), root.height * 0.18)
    readonly property color textColor: root.ink?.text ?? Colors.overBackground
    readonly property color mutedColor: root.ink?.muted ?? Colors.overSurfaceVariant
    readonly property color accentColor: root.ink?.accent ?? Colors.primary
    readonly property string petGlyph: {
        if (root.moduleId !== "pet")
            return data.glyph
        switch (Config.desktop.petStyle) {
        case "plush": return "◉‿◉"
        case "pixel": return "▦"
        case "paper": return "◕"
        default:
            switch (PetService.speciesInfo?.id ?? "") {
            case "sprout": return "♣"
            case "ember": return "♨"
            case "sol": return "☀"
            case "drift": return "☁"
            default: return "◕"
            }
        }
    }

    WidgetFace {
        id: data
        visible: false
        moduleId: root.moduleId
        family: root.family
        ink: root.ink
        row: root.row
        active: root.active && (root.moduleId === "clock" || root.moduleId === "calendar" || root.moduleId === "stats")
    }

    StyledRect {
        id: instrument
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.family === "4x4" ? root.height * 0.12 : root.height * 0.08
        width: root.wide ? Math.min(root.height * 0.62, root.width * 0.28) : root.side * 0.68
        height: width
        variant: "pane"
        radius: width / 2
        backgroundOpacity: 0.48
        enableShadow: Config.desktop.widgetShadow

        Gauge {
            anchors.fill: parent
            visible: ["battery", "volume", "brightness", "timer", "claude", "codex"].includes(root.moduleId)
            anchors.margins: root.side * 0.07
            value: data.progress
            thickness: Math.max(2, root.side * 0.025)
            trackColor: root.ink?.dim ?? Colors.surfaceVariant
            fillColor: root.moduleId === "battery" && Battery.available && Battery.percentage <= 20
                ? Colors.red : root.accentColor
        }

        StyledRect {
            anchors.centerIn: parent
            visible: root.recordFace
            width: parent.width * 0.72
            height: width
            variant: "common"
            radius: width / 2
            backgroundOpacity: 0.72
            enableBorder: false

            StyledRect {
                anchors.centerIn: parent
                width: parent.width * 0.3
                height: width
                variant: "primary"
                radius: width / 2
                enableBorder: false
            }
        }

        StyledRect {
            anchors.centerIn: parent
            visible: root.moduleId === "battery"
            width: parent.width * 0.32
            height: parent.height * 0.58
            variant: "common"
            radius: Styling.radius(-2)
            backgroundOpacity: 0.3

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: parent.width * 0.12
                height: Math.max(0, (parent.height - parent.width * 0.24) * Math.max(0, Math.min(1, data.progress)))
                color: root.accentColor
                radius: width / 2
            }
        }

        Item {
            anchors.fill: parent
            visible: root.moduleId === "stats"

            Repeater {
                model: [SystemResources.cpuUsage, SystemResources.ramUsage, SystemResources.gpuUsage]

                delegate: Rectangle {
                    required property int index
                    required property real modelData
                    readonly property real barWidth: parent.width * 0.12
                    height: Math.max(root.side * 0.08, parent.height * 0.62 * Math.max(0.04, Math.min(1, modelData / 100)))
                    width: barWidth
                    x: parent.width * (0.24 + index * 0.25)
                    y: parent.height * 0.78 - height
                    radius: width / 2
                    color: root.ink?.accent ?? Colors.primary
                    opacity: index === 2 && !SystemResources.gpuDetected ? 0.25 : 1
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: root.clockFace

            Repeater {
                model: 12

                delegate: Rectangle {
                    required property int index
                    readonly property real angle: index * Math.PI / 6
                    x: parent.width / 2 + Math.sin(angle) * parent.width * 0.37 - width / 2
                    y: parent.height / 2 - Math.cos(angle) * parent.height * 0.37 - height / 2
                    width: Math.max(1, root.side * 0.018)
                    height: root.side * 0.055
                    radius: width / 2
                    rotation: index * 30
                    color: root.ink?.dim ?? Colors.surfaceVariant
                }
            }

            Rectangle {
                x: parent.width / 2 - width / 2
                y: parent.height / 2 - height
                width: Math.max(2, root.side * 0.018)
                height: root.side * 0.25
                color: root.accentColor
                radius: width / 2
                transformOrigin: Item.Bottom
                rotation: data.now.getMinutes() * 6
            }

            Rectangle {
                x: parent.width / 2 - width / 2
                y: parent.height / 2 - height
                width: Math.max(2, root.side * 0.025)
                height: root.side * 0.17
                color: root.textColor
                radius: width / 2
                transformOrigin: Item.Bottom
                rotation: (data.now.getHours() % 12) * 30 + data.now.getMinutes() / 2
            }

            StyledRect {
                anchors.centerIn: parent
                width: Math.max(4, root.side * 0.05)
                height: width
                variant: "primary"
                radius: width / 2
                enableBorder: false
            }
        }

        Item {
            anchors.fill: parent
            visible: !root.clockFace && !root.recordFace && root.moduleId !== "battery" && root.moduleId !== "stats"

            AnalogueArt {
                anchors.fill: parent
                moduleId: root.moduleId
                glyph: root.moduleId === "pet" ? root.petGlyph : data.glyph
                now: data.now
                foreground: root.textColor
                accent: root.accentColor
                muted: root.mutedColor
                row: root.row
                interactive: root.active
            }
        }
    }

    Column {
        id: readings
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.wide ? root.width * 0.34 : root.width * 0.12
        anchors.rightMargin: root.wide ? root.width * 0.08 : root.width * 0.12
        anchors.bottomMargin: root.height * 0.12
            + ((root.showMediaControls || root.showTimerControls)
                ? root.controlSize + Styling.fontSize(-3) : 0)
        spacing: Styling.fontSize(-3)

        Text {
            width: parent.width
            text: data.label.toUpperCase()
            font.family: Config.theme.monoFont
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.DemiBold
            color: root.mutedColor
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: data.reading
            font.family: Config.theme.monoFont
            font.pixelSize: root.family === "8x2" ? Styling.fontSize(12) : Styling.fontSize(7)
            font.weight: Font.Bold
            color: root.textColor
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.family !== "2x2"
            text: data.note
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: root.mutedColor
            elide: Text.ElideRight
        }
    }
    MediaTransport {
        visible: root.showMediaControls
        anchors.left: readings.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.04
        buttonSize: root.controlSize
        spacing: Styling.fontSize(-4)
        foregroundColor: root.textColor
        accentColor: root.accentColor
        accentTextColor: root.ink?.accentText ?? Colors.overPrimary
        surfaceColor: root.ink?.raised ?? Colors.surfaceContainerHigh
    }

    TimerControls {
        visible: root.showTimerControls
        anchors.left: readings.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.04
        buttonSize: root.controlSize
        spacing: Styling.fontSize(-4)
        foregroundColor: root.textColor
        accentColor: root.accentColor
        accentTextColor: root.ink?.accentText ?? Colors.overPrimary
        surfaceColor: root.ink?.raised ?? Colors.surfaceContainerHigh
    }

    CalendarTasksView {
        anchors.fill: parent
        anchors.margins: root.family === "4x4" ? Styling.fontSize(0) : Styling.fontSize(-1)
        z: 2
        visible: root.moduleId === "calendar" && root.family !== "2x2"
        family: root.family
        theme: "analogue"
        ink: root.ink
        row: root.row
        interactive: root.active
    }
}
