pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.services
import qs.modules.components
import qs.modules.theme

// A compact month grid; the flyout fits the number of weeks being displayed.
ColumnLayout {
    id: root
    objectName: "deckCalendar"
    required property date today
    property int monthOffset: 0
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    readonly property int leadingDays: (month.getDay() + 6) % 7
    readonly property int daysInMonth: new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
    readonly property int rowCount: Math.ceil((leadingDays + daysInMonth) / 7)
    spacing: Styling.fontSize(0) * 0.5
    StyledText {
        Layout.fillWidth: true
        text: Qt.formatDateTime(root.today, "dddd, d MMMM")
            + (WeatherService.dataAvailable ? " · " + Math.round(WeatherService.currentTemp) + "° " + WeatherService.weatherDescription : "")
        elide: Text.ElideRight
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overSurfaceVariant
    }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Styling.fontSize(0) * 0.6
        RowLayout {
            Layout.fillWidth: true
            spacing: Styling.fontSize(0) * 0.2
            StyledText {
                Layout.fillWidth: true
                text: Qt.formatDateTime(root.month, "MMMM yyyy")
                font.pixelSize: Styling.fontSize(0)
                font.weight: Font.DemiBold
            }
            DeckAction { kind: DeckAction.Icon; glyph: Icons.caretLeft; description: "Previous month"; onClicked: root.monthOffset-- }
            DeckAction {
                objectName: "deckCalendarToday"
                kind: DeckAction.Action
                quiet: true
                label: "Today"
                visible: root.monthOffset !== 0
                onClicked: root.monthOffset = 0
            }
            DeckAction { kind: DeckAction.Icon; glyph: Icons.caretRight; description: "Next month"; onClicked: root.monthOffset++ }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: Styling.fontSize(0) * 0.15
            columnSpacing: Styling.fontSize(0) * 0.15
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                StyledText {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    text: modelData
                    horizontalAlignment: Text.AlignHCenter
                    color: index > 4 ? Colors.overSurfaceVariant : Colors.overBackground
                    font.pixelSize: Styling.fontSize(-3)
                    font.weight: Font.DemiBold
                }
            }
            Repeater {
                model: root.rowCount * 7
                Item {
                    id: day
                    required property int index
                    objectName: inMonth ? "deckCalendarDay-" + number : ""
                    readonly property int number: index - root.leadingDays + 1
                    readonly property bool inMonth: number > 0 && number <= root.daysInMonth
                    readonly property bool weekend: index % 7 > 4
                    readonly property bool current: inMonth && number === root.today.getDate()
                        && root.month.getMonth() === root.today.getMonth() && root.month.getFullYear() === root.today.getFullYear()
                    Layout.fillWidth: true
                    Layout.preferredHeight: Styling.fontSize(0) * 2.1
                    StyledRect {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        variant: "focus"
                        radius: Styling.radius(-8)
                        visible: day.current
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: day.inMonth ? day.number : ""
                        color: day.current ? Styling.srItem("focus") : day.weekend ? Colors.overSurfaceVariant : Colors.overBackground
                        font.weight: day.current ? Font.Bold : Font.Normal
                        font.pixelSize: Styling.fontSize(-2)
                    }
                }
            }
        }
    }
}
