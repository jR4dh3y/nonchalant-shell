pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.config

Item {
    id: root

    property string icon: ""
    property string label: ""
    property color barColor: Styling.srItem("overprimary")

    implicitHeight: 24

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // Icon
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            text: root.icon
            font.family: Icons.font
            font.pixelSize: 18
            color: Colors.overBackground
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 20
        }

        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            text: root.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.DemiBold
            color: root.barColor
            elide: Text.ElideMiddle
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
