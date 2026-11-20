pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme

// The three-dot instrumental marker occupies a lyric row, never an underline.
Item {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)

    property real progress: 0
    property real phase: 0
    property bool playing: false
    readonly property real dotSize: Styling.fontSize(-1) * 0.45
    implicitWidth: dotSize * 5
    implicitHeight: Styling.fontSize(1)
    Accessible.name: "Instrumental break"
    Accessible.role: Accessible.StaticText

    Row {
        anchors.centerIn: parent
        spacing: root.dotSize
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: root.dotSize
                height: width
                radius: width / 2
                color: root.progress * 3 > index ? root.shellPalette.primary : root.shellPalette.overSurfaceVariant
                opacity: root.playing ? 0.65 + 0.35 * Math.sin(root.phase * 2 - index * 0.6) : 0.65
            }
        }
    }
}
