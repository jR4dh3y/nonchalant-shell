// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D   I   A   L                                                          │
// │   analogue clock dial                                                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// A clock face: twelve marks (every third one long), two hands, and an accent
// seconds hand when seconds are enabled. The large size adds minute marks, four
// numerals and a date window at three o'clock.
//
// Each hand is a dial-sized item rotated about its centre, with the hand drawn
// up from the middle, so the pivot is always the dial's centre.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property real size: 150
    property bool numerals: false
    property bool minuteTicks: false
    property bool dateWindow: false

    // Seconds cost sixty times the repaints, so the hand only exists when
    // enabled.
    readonly property bool seconds: SettingsService.clockShowsSeconds
    readonly property date now: clock.date
    readonly property real r: root.size / 2

    width: root.size
    height: root.size

    SystemClock {
        id: clock
        precision: root.seconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: root.ink.dim
        border.width: 1
    }

    Repeater {
        model: root.minuteTicks ? 60 : 12

        Item {
            id: tick

            required property int index

            readonly property bool hour: root.minuteTicks ? tick.index % 5 === 0 : true
            readonly property bool quarter: root.minuteTicks
                ? tick.index % 15 === 0 : tick.index % 3 === 0

            anchors.fill: parent
            rotation: tick.index * (root.minuteTicks ? 6 : 30)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.r * 0.08
                width: tick.quarter ? 3 : (tick.hour ? 2 : 1)
                height: tick.quarter ? root.r * 0.16 : (tick.hour ? root.r * 0.09 : root.r * 0.045)
                radius: width / 2
                color: tick.quarter ? root.ink.text : root.ink.muted
            }
        }
    }

    Repeater {
        model: root.numerals ? [[12, 0], [3, 90], [6, 180], [9, 270]] : []

        Text {
            required property var modelData

            readonly property real angle: (modelData[1] - 90) * Math.PI / 180

            x: root.r + root.r * 0.72 * Math.cos(angle) - width / 2
            y: root.r + root.r * 0.72 * Math.sin(angle) - height / 2
            text: `${modelData[0]}`
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.DemiBold
            color: root.ink.text
        }
    }

    // The date, in a window at three o'clock.
    Paper {
        visible: root.dateWindow
        ink: root.ink
        radius: 3
        x: root.r + root.r * 0.5 - width / 2
        y: root.r - height / 2
        width: 26
        height: 22

        Text {
            anchors.centerIn: parent
            text: `${root.now.getDate()}`
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
            color: Theme.paperInk
        }
    }

    Item {
        anchors.fill: parent
        rotation: (root.now.getHours() % 12) * 30 + root.now.getMinutes() * 0.5

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - height
            width: Math.max(4, root.r * 0.07)
            height: root.r * 0.52
            radius: width / 2
            color: root.ink.text
        }
    }

    Item {
        anchors.fill: parent
        rotation: root.now.getMinutes() * 6 + root.now.getSeconds() * 0.1

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - height
            width: Math.max(3, root.r * 0.045)
            height: root.r * 0.74
            radius: width / 2
            color: root.ink.text
        }
    }

    Item {
        visible: root.seconds
        anchors.fill: parent
        rotation: root.now.getSeconds() * 6

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - root.r * 0.82
            width: 1.5
            height: root.r * 0.82 + root.r * 0.18
            color: root.ink.accent
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.max(6, root.r * 0.1)
        height: width
        radius: width / 2
        color: root.ink.text
    }

    Rectangle {
        anchors.centerIn: parent
        visible: root.seconds
        width: Math.max(2, root.r * 0.04)
        height: width
        radius: width / 2
        color: root.ink.accent
    }
}
