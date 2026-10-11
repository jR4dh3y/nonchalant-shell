// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P   A   R   C   E   L                                                  │
// │   the updates as a parcel · the count written on the label               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// A box in outline, taped over the seam, with a paper label bearing the count
// in the signature's script.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property real size: 120
    property string count: ""

    readonly property real cx: root.size / 2
    readonly property real cy: root.size * 0.36
    readonly property real w: root.size * 0.42
    readonly property real d: root.size * 0.2
    readonly property real tall: root.size * 0.4

    width: root.size
    height: root.size

    component Facet: Shape {
        id: facet

        property var points: []
        property real shade: 0.1

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ink.text
            strokeWidth: 2.5
            joinStyle: ShapePath.RoundJoin
            fillColor: Qt.rgba(root.ink.text.r, root.ink.text.g, root.ink.text.b, facet.shade)

            PathPolyline { path: facet.points }
        }
    }

    Facet {
        shade: 0.18
        points: [
            Qt.point(root.cx - root.w, root.cy), Qt.point(root.cx, root.cy - root.d),
            Qt.point(root.cx + root.w, root.cy), Qt.point(root.cx, root.cy + root.d),
            Qt.point(root.cx - root.w, root.cy)
        ]
    }

    Facet {
        shade: 0.05
        points: [
            Qt.point(root.cx - root.w, root.cy), Qt.point(root.cx, root.cy + root.d),
            Qt.point(root.cx, root.cy + root.d + root.tall),
            Qt.point(root.cx - root.w, root.cy + root.tall), Qt.point(root.cx - root.w, root.cy)
        ]
    }

    Facet {
        shade: 0.11
        points: [
            Qt.point(root.cx + root.w, root.cy), Qt.point(root.cx, root.cy + root.d),
            Qt.point(root.cx, root.cy + root.d + root.tall),
            Qt.point(root.cx + root.w, root.cy + root.tall), Qt.point(root.cx + root.w, root.cy)
        ]
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ink.muted
            strokeWidth: 3
            fillColor: "transparent"
            startX: root.cx - root.w / 2; startY: root.cy - root.d / 2

            PathLine { x: root.cx + root.w / 2; y: root.cy + root.d / 2 }
        }

        ShapePath {
            strokeColor: root.ink.muted
            strokeWidth: 3
            fillColor: "transparent"
            startX: root.cx; startY: root.cy + root.d

            PathLine { x: root.cx; y: root.cy + root.d + root.tall }
        }
    }

    Paper {
        ink: root.ink
        radius: 3
        x: root.cx + 6
        y: root.cy + root.d + 4
        width: root.w * 0.72
        height: root.w * 0.56
        rotation: -6

        Text {
            anchors.centerIn: parent
            text: root.count
            font.family: Theme.fontHand
            font.pixelSize: Math.round(root.w * 0.42)
            color: Theme.paperInk
        }
    }
}
