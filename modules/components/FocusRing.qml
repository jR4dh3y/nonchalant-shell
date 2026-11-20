import QtQuick
import qs.modules.theme

// Keyboard focus outline. Separate from the HoverTint lift and from the
// selection fill so the three states never read as one another. Matches each
// corner of its parent like HoverTint.
Rectangle {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)

    property bool shown: false

    anchors.fill: parent
    visible: root.shown
    color: "transparent"
    border.width: 2
    border.color: root.shellPalette.primary
    radius: parent?.radius ?? 0
    topLeftRadius: parent?.topLeftRadius ?? root.radius
    topRightRadius: parent?.topRightRadius ?? root.radius
    bottomLeftRadius: parent?.bottomLeftRadius ?? root.radius
    bottomRightRadius: parent?.bottomRightRadius ?? root.radius
}
