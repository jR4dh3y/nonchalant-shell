// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L   E   A   F                                                          │
// │   calendar leaf drawing                                                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// One leaf of a wall calendar: two rings, the month on an accent ribbon, the
// day in the notes' ink and the weekday under it. `band` is the ribbon's
// height; with no ribbon text it is a blank sheet, which the month is drawn on.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property string month: ""
    property string day: ""
    property string weekday: ""
    property bool rings: true
    property real band: 30
    property bool today: true

    default property alias sheet: paper.data

    Paper {
        id: paper

        ink: root.ink
        anchors.fill: parent
    }

    Rectangle {
        x: 0
        y: 0
        width: parent.width
        height: root.band + Theme.paperRadius
        radius: Theme.paperRadius
        color: root.today ? root.ink.accent : root.ink.muted
    }

    Paper {
        ink: root.ink
        radius: 0
        x: 0
        y: root.band
        width: parent.width
        height: Theme.paperRadius
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.band / 2 - height / 2
        width: parent.width - 12
        text: root.month
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        font.weight: Font.DemiBold
        font.letterSpacing: 1
        color: root.ink.accentText
    }

    Repeater {
        model: root.rings ? [0.3, 0.7] : []

        Item {
            required property real modelData

            x: parent.width * modelData - 6
            y: -7

            Rectangle {
                x: 3
                y: 7
                width: 6
                height: 6
                radius: 3
                color: Theme.paperInk
                opacity: 0.5
            }

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: "transparent"
                border.color: root.ink.text
                border.width: 2.5
            }
        }
    }

    Text {
        visible: root.day !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.band + (parent.height - root.band) / 2 - height / 2 - (root.weekday !== "" ? 6 : 0)
        text: root.day
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(Math.min(parent.width * 0.5, (parent.height - root.band) * 0.5))
        font.weight: Font.Bold
        color: Theme.paperInk
    }

    Text {
        visible: root.weekday !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: parent.width - 12
        text: root.weekday
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.paperInkMuted
    }
}
