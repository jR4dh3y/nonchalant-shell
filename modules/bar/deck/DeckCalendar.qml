pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.services
import qs.modules.components
import qs.modules.theme

// Today: the date and weather as their own cards beside a month card whose
// weeks share the card's full height.
RowLayout {
    id: root
    objectName: "deckCalendar"
    required property date today
    property int monthOffset: 0
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    readonly property int leadingDays: (month.getDay() + 6) % 7
    readonly property int daysInMonth: new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
    readonly property int previousMonthDays: new Date(month.getFullYear(), month.getMonth(), 0).getDate()
    readonly property int rowCount: Math.ceil((leadingDays + daysInMonth) / 7)
    readonly property bool showingToday: month.getMonth() === today.getMonth() && month.getFullYear() === today.getFullYear()
    readonly property int todayIndex: showingToday ? leadingDays + today.getDate() - 1 : -1
    spacing: Styling.fontSize(0) * 0.5

    function isoWeek(date: date): int {
        const target = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        target.setDate(target.getDate() + 3 - (target.getDay() + 6) % 7);
        const firstThursday = new Date(target.getFullYear(), 0, 4);
        return 1 + Math.round(((target - firstThursday) / 86400000 - 3 + (firstThursday.getDay() + 6) % 7) / 7);
    }

    ColumnLayout {
        Layout.preferredWidth: Styling.fontSize(0) * 12
        Layout.fillHeight: true
        spacing: Styling.fontSize(0) * 0.5

        DeckCard {
            objectName: "deckTodayDate"
            Layout.fillWidth: true
            Layout.fillHeight: true
            order: 0
            Item { Layout.fillHeight: true }
            StyledText {
                text: root.today.getDate()
                color: Colors.primary
                font.pixelSize: Styling.fontSize(0) * 3.6
                font.weight: Font.Bold
            }
            StyledText {
                Layout.fillWidth: true
                text: Qt.formatDateTime(root.today, "dddd")
                font.pixelSize: Styling.fontSize(2)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: Qt.formatDateTime(root.today, "MMMM yyyy") + " · Week " + root.isoWeek(root.today)
                color: Colors.overSurfaceVariant
                font.pixelSize: Styling.fontSize(-2)
                elide: Text.ElideRight
            }
            Item { Layout.fillHeight: true }
        }
        DeckCard {
            objectName: "deckTodayWeather"
            Layout.fillWidth: true
            order: 1
            title: "Weather"
            RowLayout {
                Layout.fillWidth: true
                visible: WeatherService.dataAvailable
                spacing: Styling.fontSize(0) * 0.5
                StyledText {
                    text: WeatherService.weatherSymbol
                    visible: text !== ""
                    font.pixelSize: Styling.fontSize(6)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        text: Math.round(WeatherService.currentTemp) + "°"
                        font.pixelSize: Styling.fontSize(4)
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: WeatherService.weatherDescription
                        color: Colors.overSurfaceVariant
                        font.pixelSize: Styling.fontSize(-2)
                        elide: Text.ElideRight
                    }
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: WeatherService.dataAvailable
                text: "H " + Math.round(WeatherService.maxTemp) + "° · L " + Math.round(WeatherService.minTemp) + "°"
                    + (WeatherService.sunset !== "" ? " · Sunset " + WeatherService.sunset : "")
                color: Colors.overSurfaceVariant
                font.pixelSize: Styling.fontSize(-3)
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: !WeatherService.dataAvailable
                text: WeatherService.isLoading ? "Fetching weather…" : "Weather unavailable"
                color: Colors.overSurfaceVariant
                font.pixelSize: Styling.fontSize(-1)
            }
        }
    }

    DeckCard {
        objectName: "deckMonth"
        Layout.fillWidth: true
        Layout.fillHeight: true
        order: 1
        spacing: Styling.fontSize(0) * 0.3
        RowLayout {
            Layout.fillWidth: true
            spacing: Styling.fontSize(0) * 0.2
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Styling.fontSize(0) * 0.3
                text: Qt.formatDateTime(root.month, "MMMM yyyy")
                font.pixelSize: Styling.fontSize(0)
                font.weight: Font.DemiBold
            }
            DeckAction {
                objectName: "deckCalendarToday"
                kind: DeckAction.Action
                quiet: true
                label: "Today"
                visible: root.monthOffset !== 0
                onClicked: root.monthOffset = 0
            }
            DeckAction { kind: DeckAction.Icon; glyph: Icons.caretLeft; description: "Previous month"; onClicked: root.monthOffset-- }
            DeckAction { kind: DeckAction.Icon; glyph: Icons.caretRight; description: "Next month"; onClicked: root.monthOffset++ }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                StyledText {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: modelData
                    horizontalAlignment: Text.AlignHCenter
                    color: Colors.overSurfaceVariant
                    font.pixelSize: Styling.fontSize(-3)
                    font.weight: index > 4 ? Font.Bold : Font.Medium
                }
            }
        }
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(1, Styling.fontSize(0) / 14)
            variant: "internalbg"
            enableBorder: false
            radius: 0
        }
        Repeater {
            model: root.rowCount
            Item {
                id: week
                required property int index
                readonly property bool current: root.todayIndex >= index * 7 && root.todayIndex < index * 7 + 7
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Styling.fontSize(0) * 1.6
                StyledRect {
                    anchors.fill: parent
                    visible: week.current
                    variant: "internalbg"
                    radius: height / 2
                    enableBorder: false
                }
                RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    Repeater {
                        model: 7
                        Item {
                            id: day
                            required property int index
                            readonly property int cell: week.index * 7 + index
                            readonly property int number: cell - root.leadingDays + 1
                            readonly property bool inMonth: number > 0 && number <= root.daysInMonth
                            readonly property int shownNumber: inMonth ? number : number <= 0 ? root.previousMonthDays + number : number - root.daysInMonth
                            readonly property bool current: cell === root.todayIndex
                            objectName: inMonth ? "deckCalendarDay-" + number : ""
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            StyledRect {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) * 0.92
                                height: width
                                variant: "primary"
                                radius: width / 2
                                enableBorder: false
                                visible: day.current
                            }
                            StyledText {
                                anchors.centerIn: parent
                                text: day.shownNumber
                                color: day.current ? Styling.srItem("primary") : day.inMonth ? Colors.overBackground : Colors.overSurfaceVariant
                                opacity: day.inMonth ? 1 : 0.55
                                font.weight: day.current || day.inMonth ? Font.DemiBold : Font.Normal
                                font.pixelSize: Styling.fontSize(-2)
                            }
                        }
                    }
                }
            }
        }
    }
}
