// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   R I N G   I N D I C A T O R                                            │
// │   a circular gauge · track, sweep and whatever sits inside               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Shapes

import qs.modules.widgets.desktop.impasto.theme

// A circular gauge that fills clockwise from the top. Generic: it takes a
// fraction and a colour, and children are drawn inside it.
Item {
    id: root

    property real progress: 0
    property real thickness: 3
    property color trackColor: Theme.borderIn(QsWindow.window)
    property color fillColor: Theme.accent

    // Sweep duration. Slow values (charge, countdown) use the shell's easing;
    // fast ones such as a sound level need it short or the ring lags.
    property int sweepDuration: Theme.durationMedium

    default property alias content: centre.data

    readonly property real clamped: Math.max(0, Math.min(1, root.progress))
    readonly property real radius: (Math.min(root.width, root.height) - root.thickness) / 2

    implicitWidth: Theme.capsuleHeight
    implicitHeight: Theme.capsuleHeight

    Shape {
        anchors.fill: parent
        // The curve renderer antialiases the sweep properly; the default one
        // leaves a visibly stepped edge at this size.
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.thickness
            strokeColor: root.trackColor
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeWidth: root.thickness
            strokeColor: root.fillColor
            fillColor: "transparent"
            // Rounded ends read as a gauge rather than a cut pie slice, but at
            // zero they would still paint a dot, hence the guard below.
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: root.clamped <= 0 ? 0 : Math.max(2, 360 * root.clamped)

                Behavior on sweepAngle {
                    NumberAnimation {
                        duration: root.sweepDuration
                        easing.type: Theme.easing
                    }
                }
            }
        }
    }

    Item {
        id: centre
        anchors.fill: parent
    }
}
