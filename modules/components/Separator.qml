import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme

Rectangle {
    id: paletteOwner
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(paletteOwner)
    property bool vert: false

    color: paletteOwner.shellPalette.overBackground
    opacity: 0.1
    radius: Styling.radius(0)

    implicitWidth: vert ? 2 : 20
    implicitHeight: vert ? 20 : 2

    Layout.fillWidth: !vert
    Layout.fillHeight: vert
}
