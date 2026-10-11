// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S P A R K L I N E                                                      │
// │   a series over time · filled area and stroke                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import qs.modules.widgets.desktop.impasto.theme

// Oldest value on the left, newest on the right. A line with no filled area,
// since it shows a trend rather than a quantity; the dot marks the current
// reading.
Item {
    id: root

    property var values: []
    // Zero scales to the series maximum, for rates with no natural ceiling;
    // otherwise this is a fixed ceiling.
    property real maximum: 1
    property color stroke: Theme.accent
    property real thickness: 1.6
    property bool showDot: true

    readonly property real ceiling: {
        if (root.maximum > 0)
            return root.maximum
        let highest = 0
        for (const value of root.values)
            highest = Math.max(highest, value)
        return highest > 0 ? highest : 1
    }

    function pointAt(index: int): point {
        const count = Math.max(2, root.values.length)
        const x = index / (count - 1) * root.width
        const fraction = Math.max(0, Math.min(1, root.values[index] / root.ceiling))
        return Qt.point(x, root.height - fraction * root.height)
    }

    Shape {
        anchors.fill: parent
        visible: root.values.length > 1
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.thickness
            strokeColor: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: {
                    const points = []
                    for (let index = 0; index < root.values.length; index++)
                        points.push(root.pointAt(index))
                    return points
                }
            }
        }
    }

    Rectangle {
        id: dot

        readonly property point head: root.values.length > 1
            ? root.pointAt(root.values.length - 1) : Qt.point(0, 0)

        visible: root.showDot && root.values.length > 1
        x: dot.head.x - width / 2
        y: dot.head.y - height / 2
        width: 5
        height: 5
        radius: width / 2
        color: root.stroke
    }
}
