import QtQuick
import qs.config
import qs.modules.components
import qs.modules.theme

Item {
    id: root

    default property alias content: contentContainer.data

    readonly property real bgOpacity: Config.theme.srBarBg.opacity
    readonly property int padding: bgOpacity < 0.01 ? 0 : 4
    readonly property int outerMargin: 4

    StyledRect {
        anchors.fill: parent
        variant: "barbg"
        visible: Config.showBackground
        radius: Styling.radius(0)
        enableBorder: true
        enableShadow: false
    }

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
