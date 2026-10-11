// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   U   T                                                              │
// │   one sticker · a shape with a vinyl edge, tilted                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// One sticker: a shape cut out of a palette hue with a vinyl edge round it,
// tilted by a hash of `seed` so it keeps its angle and its neighbours lean
// apart. What goes inside is drawn upright on it and turns with it.
//
//   circle   a disc
//   pill     rounded to half its short side
//   soft     a square with soft corners
//   cookie   a circle with `lobes` bumps `depth` deep, turned by `turn`
Item {
    id: root

    property string shape: "circle"
    property int lobes: 12
    property real depth: 0.07
    property real turn: 0
    property color fill: Theme.stickerPaper
    property color paper: Theme.stickerPaper
    property string seed: ""

    // The largest tilt either way; 0 stands it straight.
    property real lean: Theme.stickerLean

    readonly property real side: Math.min(root.width, root.height)
    // A share of the short side; a sticker sized by its own contents sets it
    // from something else, or the two would chase each other.
    property real edge: Math.max(2.5, root.side * Theme.stickerEdge)

    default property alias content: inside.data

    rotation: {
        let hash = 0
        for (let index = 0; index < root.seed.length; index++)
            hash = (hash * 31 + root.seed.charCodeAt(index)) % 1009
        return root.seed === "" ? 0 : (hash % 2 === 0 ? 1 : -1) * root.lean * (0.25 + (hash % 97) / 97 * 0.75)
    }
    antialiasing: true

    Rectangle {
        anchors.fill: parent
        visible: root.shape !== "cookie"
        antialiasing: true
        radius: root.shape === "soft" ? root.side * 0.24 : root.side / 2
        color: root.fill
        border.width: root.edge
        border.color: root.paper
    }

    Shape {
        anchors.fill: parent
        visible: root.shape === "cookie"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fill
            strokeColor: root.paper
            strokeWidth: 2 * root.edge
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: {
                    const points = []
                    const middleX = root.width / 2
                    const middleY = root.height / 2
                    const reach = root.side / 2 - root.edge
                    const steps = Math.max(96, root.lobes * 16)
                    for (let step = 0; step <= steps; step++) {
                        const angle = step / steps * 2 * Math.PI
                        const radius = reach * (1 - root.depth
                            + root.depth * Math.cos(root.lobes * (angle + root.turn)))
                        points.push(Qt.point(middleX + radius * Math.cos(angle),
                                             middleY + radius * Math.sin(angle)))
                    }
                    return points
                }
            }
        }
    }

    Item {
        id: inside

        anchors.fill: parent
    }
}
