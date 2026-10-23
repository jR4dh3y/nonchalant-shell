pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.components
import qs.modules.theme

// A named group of related controls, inset from the drawer surface.
Pane {
    id: root
    default property alias sectionData: body.data
    property string title: ""
    padding: Styling.fontSize(0) * 0.6
    background: StyledRect {
        variant: "internalbg"
        radius: Styling.radius(-6)
        enableBorder: false
    }
    contentItem: ColumnLayout {
        spacing: Styling.fontSize(0) * 0.5
        StyledText {
            visible: root.title !== ""
            text: root.title
            Layout.fillWidth: true
            color: Colors.overSurfaceVariant
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.DemiBold
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: Styling.fontSize(0) * 0.2
        }
    }
}
