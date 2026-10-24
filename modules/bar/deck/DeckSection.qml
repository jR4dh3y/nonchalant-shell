pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.components
import qs.modules.theme

// A titled group inside a card or scrolling list.
Pane {
    id: root
    default property alias sectionData: body.data
    property string title: ""
    padding: 0
    background: null
    contentItem: ColumnLayout {
        spacing: Styling.fontSize(0) * 0.35
        StyledText {
            visible: root.title !== ""
            text: root.title
            Layout.fillWidth: true
            Layout.leftMargin: Styling.fontSize(0) * 0.3
            color: Colors.overSurfaceVariant
            font.pixelSize: Styling.fontSize(-3)
            font.weight: Font.DemiBold
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: Styling.fontSize(0) * 0.2
        }
    }
}
