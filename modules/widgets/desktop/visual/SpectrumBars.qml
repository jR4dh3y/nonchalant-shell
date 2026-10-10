pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.services.desktop

Item {
    id: root

    property bool active: false
    property bool listening: true
    property color fillColor: "white"
    property color peakColor: root.fillColor
    property real barWidth: 4
    property real gap: 3
    property string style: "rounded"
    property string fillStyle: "fade"
    property string lowsAt: "corners"
    property bool showPeaks: false

    readonly property bool hearing: root.active && root.listening
    readonly property int count: Math.min(64, CavaService.bandCount,
        Math.max(0, Math.floor((root.width + root.gap) / Math.max(1, root.barWidth + root.gap))))
    readonly property var wavePoints: {
        if (root.style !== "wave")
            return []
        const points = [Qt.point(0, root.height)]
        const total = Math.max(1, root.count)
        for (let index = 0; index < root.count; index++) {
            const position = (index + 0.5) / total
            const bandPosition = root.lowsAt === "along" ? position : 1 - Math.abs(2 * position - 1)
            const source = Math.round(bandPosition * Math.max(0, CavaService.bandCount - 1))
            const level = root.hearing
                ? Math.max(0, Math.min(1, CavaService.bands[source] ?? 0))
                : 0.03 + 0.3 * Math.abs(Math.sin((index + 1) * 2.17))
            points.push(Qt.point(root.width * position, root.height * (1 - level)))
        }
        points.push(Qt.point(root.width, root.height))
        points.push(Qt.point(0, root.height))
        return points
    }
    property bool subscribed: false

    function colorFor(level: real): color {
        return root.fillStyle === "blend"
            ? Qt.tint(root.fillColor, Qt.rgba(root.peakColor.r, root.peakColor.g, root.peakColor.b, level))
            : root.fillColor
    }

    function syncSubscription(): void {
        if (root.hearing === root.subscribed)
            return
        root.subscribed = root.hearing
        if (root.hearing)
            CavaService.subscribe()
        else
            CavaService.release()
    }

    onHearingChanged: root.syncSubscription()
    Component.onCompleted: root.syncSubscription()
    Component.onDestruction: {
        if (root.subscribed)
            CavaService.release()
    }

    Shape {
        anchors.fill: parent
        visible: root.style === "wave"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.colorFor(0.8)
            fillRule: ShapePath.WindingFill
            strokeColor: root.fillColor
            strokeWidth: 1.5
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline { path: root.wavePoints }
        }
    }

    Repeater {
        model: root.style === "wave" ? 0 : root.count

        delegate: Item {
            id: bar
            required property int index

            readonly property real position: (bar.index + 0.5) / Math.max(1, root.count)
            readonly property real bandPosition: root.lowsAt === "along"
                ? bar.position : 1 - Math.abs(2 * bar.position - 1)
            readonly property int sourceIndex: Math.round(bar.bandPosition * Math.max(0, CavaService.bandCount - 1))
            readonly property real level: root.hearing
                ? Math.max(0.02, Math.min(1, CavaService.bands[bar.sourceIndex] ?? 0))
                : 0.03 + 0.3 * Math.abs(Math.sin((bar.index + 1) * 2.17))
            readonly property real peak: root.showPeaks && root.hearing
                ? Math.max(bar.level, Math.min(1, CavaService.peaks[bar.sourceIndex] ?? 0)) : 0
            readonly property real barHeight: Math.max(2, bar.height * bar.level)
            readonly property int segmentCount: Math.max(1,
                Math.floor(bar.barHeight / Math.max(3, root.barWidth * 1.4)))

            x: (root.width - root.count * root.barWidth - (root.count - 1) * root.gap) / 2
                + bar.index * (root.barWidth + root.gap)
            width: root.barWidth
            height: root.height

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: bar.barHeight
                radius: root.style === "square" ? 0 : width / 2
                color: root.colorFor(bar.level)
                opacity: root.style === "dots" ? 0.28
                    : root.fillStyle === "fade" ? 0.5 + bar.level * 0.5 : 1
                visible: root.style !== "segments"
            }

            Repeater {
                model: root.style === "segments"
                    ? Math.max(1, Math.floor(bar.height / Math.max(3, root.barWidth * 1.4))) : 0

                delegate: Rectangle {
                    required property int index
                    visible: index < bar.segmentCount
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: index * Math.max(3, root.barWidth * 1.4)
                    width: parent.width
                    height: Math.max(2, root.barWidth)
                    radius: Math.min(width / 2, height / 2)
                    color: root.colorFor(bar.level)
                    opacity: root.fillStyle === "fade" ? 0.5 + bar.level * 0.5 : 1
                }
            }

            Rectangle {
                visible: root.style === "dots"
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * (1 - bar.level) - width / 2
                width: root.barWidth * 1.5
                height: width
                radius: width / 2
                color: root.fillColor
            }

            Rectangle {
                visible: root.showPeaks && root.hearing && bar.peak > bar.level
                y: parent.height * (1 - bar.peak) - height
                width: parent.width
                height: Math.max(2, root.barWidth * 0.35)
                radius: root.style === "square" ? 0 : height / 2
                color: root.peakColor
            }
        }
    }
}