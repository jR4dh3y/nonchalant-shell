// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G   A   U   G   E                                                      │
// │   needle gauge with a red zone                                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// A needle gauge: a 240° arc with eleven marks, the top fifth in warning red,
// and an accent needle. A label under the hub and a small value under that.
//
// `warns` removes the red, `lowIsBad` moves it to the empty end, and `ends`
// labels the two ends (E and F on a fuel gauge).
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property real size: 120
    property real fraction: 0
    property string label: ""
    property string value: ""
    property bool warns: true
    property bool lowIsBad: false
    property var ends: []

    default property alias content: hub.data

    readonly property real clamped: Math.max(0, Math.min(1, root.fraction))
    readonly property real r: root.size / 2 - 6
    readonly property real cx: root.size / 2
    readonly property real cy: root.size / 2
    readonly property real start: 150
    readonly property real sweep: 240

    width: root.size
    height: root.size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ink.dim
            strokeWidth: 2
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.cx; centerY: root.cy
                radiusX: root.r; radiusY: root.r
                startAngle: root.start
                sweepAngle: root.sweep
            }
        }

        ShapePath {
            strokeColor: root.warns ? Theme.indicatorBad : "transparent"
            strokeWidth: 3
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.cx; centerY: root.cy
                radiusX: root.r; radiusY: root.r
                startAngle: root.lowIsBad ? root.start : root.start + root.sweep * 0.82
                sweepAngle: root.sweep * 0.18
            }
        }
    }

    Repeater {
        model: 11

        Item {
            id: mark

            required property int index

            readonly property bool major: mark.index % 5 === 0

            anchors.fill: parent
            rotation: root.start + root.sweep * mark.index / 10 + 90

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.cy - root.r + 5
                width: mark.major ? 2.5 : 1.5
                height: mark.major ? 11 : 6
                radius: width / 2
                color: mark.major ? root.ink.text : root.ink.muted
            }
        }
    }

    Repeater {
        model: root.ends

        Text {
            required property int index
            required property string modelData

            readonly property real angle: (root.start + (index === 0 ? 0 : root.sweep)) * Math.PI / 180

            x: root.cx + (root.r + 12) * Math.cos(angle) - width / 2
            y: root.cy + (root.r + 12) * Math.sin(angle) - height / 2
            text: modelData
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: root.ink.muted
        }
    }

    Item {
        anchors.fill: parent
        rotation: root.start + root.sweep * root.clamped + 90

        Behavior on rotation { NumberAnimation { duration: Theme.durationMedium } }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.cy - (root.r - 14)
            width: 3
            height: root.r - 14 + root.r * 0.2
            radius: width / 2
            color: root.ink.accent
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 9
        height: 9
        radius: 4.5
        color: root.ink.text
    }

    // A slot for a mark above the hub.
    Item {
        id: hub

        anchors.fill: parent
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cy + root.r * 0.5
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        font.letterSpacing: 1
        color: root.ink.muted
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cy + root.r * 0.5 + 15
        text: root.value
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeRegular
        font.weight: Font.DemiBold
        color: root.ink.text
    }
}
