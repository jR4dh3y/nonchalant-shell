// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S   K   Y                                                              │
// │   the weather drawn · a sun, a moon, a cloud, and what falls out of it   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// The weather drawn as shapes: a sun with rays, a crescent, an outlined cloud,
// and precipitation or fog under it. Keyed on the glyph weather.py already
// chose, so the condition mapping lives in one place.
//
// `quiet` draws in the muted colour, for the forecast. Rain and lightning use
// the accent.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property string glyph: ""
    property real size: 100
    property bool quiet: false

    readonly property string kind: {
        switch (root.glyph) {
        case "󰖨": return "sun"
        case "󰖔": return "moon"
        case "󰖕": return "partly"
        case "󰼱": return "partlyNight"
        case "󰖑": return "fog"
        case "󰼳": return "drizzle"
        case "󰖖": return "rain"
        case "󰼶": return "snow"
        case "󰙾": return "storm"
        default:  return "cloud"
        }
    }

    readonly property bool hasSun: root.kind === "sun" || root.kind === "partly"
    readonly property bool hasMoon: root.kind === "moon" || root.kind === "partlyNight"
    readonly property bool hasCloud: !(root.kind === "sun" || root.kind === "moon")
    // A sun or moon behind a cloud is smaller and up in the corner.
    readonly property bool behind: root.kind === "partly" || root.kind === "partlyNight"
    readonly property bool falls: root.kind === "drizzle" || root.kind === "rain"
        || root.kind === "snow" || root.kind === "storm" || root.kind === "fog"

    readonly property color line: root.quiet ? root.ink.muted : root.ink.text
    readonly property real s: root.size
    readonly property real stroke: Math.max(1.5, root.s * 0.03)

    width: root.size
    height: root.size

    // ── SUN ─────────────────────────────────────────────────────────────────

    Item {
        id: sun

        visible: root.hasSun

        readonly property real cx: root.behind ? root.s * 0.32 : root.s / 2
        readonly property real cy: root.behind ? root.s * 0.32 : root.s / 2
        readonly property real rr: root.behind ? root.s * 0.15 : root.s * 0.24

        Rectangle {
            x: sun.cx - sun.rr
            y: sun.cy - sun.rr
            width: 2 * sun.rr
            height: 2 * sun.rr
            radius: sun.rr
            color: "transparent"
            border.color: root.line
            border.width: root.stroke
        }

        Repeater {
            model: 8

            Item {
                required property int index

                readonly property real reach: sun.rr + sun.rr * 0.32 + sun.rr * 0.5

                x: sun.cx - width / 2
                y: sun.cy - height / 2
                width: 2 * reach
                height: 2 * reach
                rotation: index * 45

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    width: root.stroke
                    height: sun.rr * 0.5
                    radius: width / 2
                    color: root.line
                }
            }
        }
    }

    // ── MOON ────────────────────────────────────────────────────────────────
    //
    // A crescent: the right half of a circle, closed by a flatter arc back
    // up the same side, so the thick of it faces right.

    Shape {
        id: moon

        visible: root.hasMoon
        preferredRendererType: Shape.CurveRenderer

        readonly property real cx: root.behind ? root.s * 0.34 : root.s / 2
        readonly property real cy: root.behind ? root.s * 0.34 : root.s / 2
        readonly property real rr: root.behind ? root.s * 0.17 : root.s * 0.28

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.line
            startX: moon.cx
            startY: moon.cy - moon.rr

            PathArc {
                x: moon.cx; y: moon.cy + moon.rr
                radiusX: moon.rr; radiusY: moon.rr
                direction: PathArc.Clockwise
            }

            PathArc {
                x: moon.cx; y: moon.cy - moon.rr
                radiusX: moon.rr * 1.15; radiusY: moon.rr * 1.15
                direction: PathArc.Counterclockwise
            }
        }
    }

    // ── CLOUD ───────────────────────────────────────────────────────────────
    //
    // Three bumps and a flat base, in outline. Lower and to the right when
    // there is a sun behind it; higher when something falls out of it.

    Shape {
        id: cloud

        visible: root.hasCloud
        preferredRendererType: Shape.CurveRenderer

        readonly property real cw: root.behind ? root.s * 0.68 : root.s * 0.84
        readonly property real x0: root.behind ? root.s * 0.28 : root.s * 0.08
        readonly property real y0: root.behind ? root.s * 0.8
            : (root.falls ? root.s * 0.56 : root.s * 0.68)

        ShapePath {
            strokeColor: root.line
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: cloud.x0
            startY: cloud.y0

            PathArc {
                x: cloud.x0 + cloud.cw * 0.30; y: cloud.y0 - cloud.cw * 0.22
                radiusX: cloud.cw * 0.19; radiusY: cloud.cw * 0.19
            }

            PathArc {
                x: cloud.x0 + cloud.cw * 0.72; y: cloud.y0 - cloud.cw * 0.20
                radiusX: cloud.cw * 0.26; radiusY: cloud.cw * 0.26
            }

            PathArc {
                x: cloud.x0 + cloud.cw; y: cloud.y0
                radiusX: cloud.cw * 0.18; radiusY: cloud.cw * 0.18
            }

            PathLine { x: cloud.x0; y: cloud.y0 }
        }
    }

    // ── PRECIPITATION ───────────────────────────────────────────────────────

    // Drizzle and rain: three strokes, slanted, longer and heavier for rain.
    Repeater {
        model: root.kind === "drizzle" || root.kind === "rain" ? 3 : 0

        Rectangle {
            required property int index

            x: cloud.x0 + cloud.cw * (0.25 + 0.25 * index)
            y: cloud.y0 + root.s * 0.06
            width: root.kind === "rain" ? root.stroke : root.stroke * 0.7
            height: root.kind === "rain" ? root.s * 0.2 : root.s * 0.12
            radius: width / 2
            rotation: 20
            color: root.ink.accent
        }
    }

    // Snow: three flakes.
    Repeater {
        model: root.kind === "snow" ? 3 : 0

        Rectangle {
            required property int index

            x: cloud.x0 + cloud.cw * (0.22 + 0.25 * index) - width / 2
            y: cloud.y0 + root.s * (index === 1 ? 0.16 : 0.09)
            width: root.s * 0.07
            height: width
            radius: width / 2
            color: "transparent"
            border.color: root.line
            border.width: root.stroke * 0.7
        }
    }

    // Fog: the lines the cloud sits in.
    Repeater {
        model: root.kind === "fog" ? 3 : 0

        Rectangle {
            required property int index

            x: cloud.x0 + cloud.cw * (index === 1 ? 0.18 : 0.05)
            y: cloud.y0 + root.s * (0.09 + 0.09 * index)
            width: cloud.cw * (index === 1 ? 0.7 : 0.9)
            height: root.stroke
            radius: height / 2
            color: root.ink.muted
        }
    }

    // A storm: the bolt.
    Shape {
        id: bolt

        visible: root.kind === "storm"
        preferredRendererType: Shape.CurveRenderer

        readonly property real bx: cloud.x0 + cloud.cw * 0.5
        readonly property real by: cloud.y0 + root.s * 0.04
        readonly property real u: root.s * 0.055

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.ink.accent

            PathPolyline {
                path: [
                    Qt.point(bolt.bx + bolt.u * 1, bolt.by),
                    Qt.point(bolt.bx - bolt.u * 1.4, bolt.by + bolt.u * 2.6),
                    Qt.point(bolt.bx + bolt.u * 0.2, bolt.by + bolt.u * 2.6),
                    Qt.point(bolt.bx - bolt.u * 0.6, bolt.by + bolt.u * 5),
                    Qt.point(bolt.bx + bolt.u * 1.6, bolt.by + bolt.u * 2),
                    Qt.point(bolt.bx + bolt.u * 0.1, bolt.by + bolt.u * 2),
                    Qt.point(bolt.bx + bolt.u * 1, bolt.by)
                ]
            }
        }
    }
}
