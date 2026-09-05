import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property string side: "left"
    readonly property bool isRight: side === "right"
    property real earRadius: 14
    property color earColor: "#000000"

    implicitWidth: Math.max(0, earRadius)
    implicitHeight: Math.max(0, earRadius)
    width: implicitWidth
    height: implicitHeight

    readonly property real kappa: 0.5522847498307935

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false
        visible: root.earRadius > 0

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.earColor

            startX: root.isRight ? 0 : 0
            startY: root.isRight ? root.earRadius : 0

            PathCubic {
                control1X: root.isRight ? 0 : root.earRadius * (1.0 - root.kappa)
                control1Y: root.isRight ? root.earRadius * root.kappa : 0
                control2X: root.isRight ? root.earRadius * root.kappa : root.earRadius
                control2Y: root.isRight ? 0 : root.earRadius * root.kappa
                x: root.isRight ? root.earRadius : root.earRadius
                y: root.isRight ? 0 : root.earRadius
            }

            PathLine {
                x: root.isRight ? 0 : root.earRadius
                y: 0
            }

            PathLine {
                x: 0
                y: root.isRight ? root.earRadius : 0
            }
        }
    }
}
