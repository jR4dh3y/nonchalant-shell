import QtQuick
import qs.modules.theme
import qs.config

Item {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)

    property string text: ""
    property font font: Qt.font({
        family: Config.theme.monoFont,
        pixelSize: Styling.fontSize(-1),
        bold: true
    })
    property color color: root.shellPalette.overBackground
    property bool animated: Motion.enabled

    TextMetrics {
        id: fullMetrics
        font: root.font
        text: root.text.length > 0 ? root.text : "00:00"
    }

    implicitWidth: fullMetrics.advanceWidth
    implicitHeight: fullMetrics.height
    height: implicitHeight
    width: implicitWidth

    Row {
        id: digitsRow
        anchors.centerIn: parent
        height: root.implicitHeight

        Repeater {
            model: root.text.length

            Item {
                id: digit
                required property int index
                property string value: root.text.charAt(index)
                property string shown: value
                property string outgoing: ""
                property real progress: 1.0
                property bool ready: false

                width: metrics.advanceWidth
                implicitWidth: metrics.advanceWidth
                height: root.implicitHeight
                implicitHeight: root.implicitHeight
                clip: true

                TextMetrics {
                    id: metrics
                    font: root.font
                    text: /\d/.test(digit.value) ? "0" : digit.value
                }

                function update() {
                    if (!ready || motion.running || value === shown) return;
                    if (!root.animated || !visible || !/\d/.test(value)) {
                        shown = value;
                        outgoing = "";
                        progress = 1.0;
                        return;
                    }
                    outgoing = shown;
                    shown = value;
                    progress = 0.0;
                    motion.start();
                }

                onValueChanged: update()
                onVisibleChanged: if (!visible) {
                    motion.stop();
                    shown = value;
                    outgoing = "";
                    progress = 1.0;
                }
                Component.onCompleted: {
                    shown = value;
                    outgoing = "";
                    progress = 1.0;
                    ready = true;
                }

                NumberAnimation {
                    id: motion
                    target: digit
                    property: "progress"
                    to: 1.0
                    duration: 220
                    easing.type: Easing.OutCubic
                    onFinished: {
                        digit.outgoing = "";
                        Qt.callLater(digit.update);
                    }
                }

                Text {
                    width: parent.width
                    height: parent.height
                    y: -parent.height * digit.progress
                    visible: digit.outgoing !== ""
                    text: digit.outgoing
                    font: root.font
                    color: root.color
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.NativeRendering
                }

                Text {
                    width: parent.width
                    height: parent.height
                    y: parent.height * (1.0 - digit.progress)
                    text: digit.shown
                    font: root.font
                    color: root.color
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
