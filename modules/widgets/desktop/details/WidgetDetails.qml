pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.components
import qs.modules.theme
import qs.modules.widgets.desktop.visual
import qs.modules.services
import qs.config

Item {
    id: root

    required property ShellScreen screen
    required property string moduleId
    required property var row
    signal closeRequested()

    readonly property string title: ({
        notes: "Notes",
        calendar: "Calendar",
        tasks: "Tasks",
        timer: "Timer",
        pet: "Pet",
        games: "Arcade"
    })[root.moduleId] ?? "Widget"

    implicitWidth: Styling.fontSize(0) * 42
    implicitHeight: Styling.fontSize(0) * 34
    focus: true

    StyledRect {
        anchors.fill: parent
        variant: "popup"
        enableShadow: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Styling.fontSize(0)
            spacing: Styling.fontSize(-2)

            RowLayout {
                Layout.fillWidth: true
                spacing: Styling.fontSize(-2)

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Colors.overSurface
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(3)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                DetailButton {
                    text: "Close"
                    onClicked: root.closeRequested()
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 1
                variant: "transparent"
                enableBorder: false
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: {
                    switch (root.moduleId) {
                    case "notes": return notesDetails
                    case "tasks": return taskDetails
                    case "calendar": return calendarDetails
                    case "timer": return timerDetails
                    case "pet": return petDetails
                    case "games": return gamesDetails
                    default: return unsupportedDetails
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: root.closeRequested()

    Component {
        id: notesDetails
        NotesDetail { row: root.row }
    }
    Component {
        id: taskDetails
        TasksDetail { row: root.row }
    }
    Component {
        id: calendarDetails
        CalendarTasksView {
            family: "4x4"
            theme: DesktopWidgetService.themeOf(root.row)
            fullMonth: true
            ink: DesktopWidgetService.inkFor(root.row)
            row: root.row
            interactive: true
        }
    }
    Component {
        id: timerDetails
        TimerDetail { row: root.row }
    }
    Component {
        id: petDetails
        PetDetail { row: root.row }
    }
    Component {
        id: gamesDetails
        GamesDetail { row: root.row; onCloseRequested: root.closeRequested() }
    }
    Component {
        id: unsupportedDetails
        Text {
            text: "This widget has no interactive detail view."
            color: Colors.overSurfaceVariant
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
        }
    }
}