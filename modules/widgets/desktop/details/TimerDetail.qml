pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services.desktop
import qs.modules.theme
import qs.config

Item {
    id: root

    required property var row
    property string durationText: "5m"
    property string labelText: ""
    readonly property real gap: Styling.fontSize(-2)
    readonly property bool validDuration: TimerService.parse(root.durationText) > 0

    ColumnLayout {
        anchors.fill: parent
        spacing: root.gap

        Text {
            Layout.fillWidth: true
            text: TimerService.running
                ? (TimerService.paused ? "Timer paused" : "Counting down")
                : "Set a countdown"
            color: Colors.overSurfaceVariant
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            text: TimerService.running ? TimerService.display : "—:—"
            color: Colors.overSurface
            font.family: Config.theme.monoFont
            font.pixelSize: Styling.fontSize(12)
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: Styling.fontSize(0)
            variant: "common"
            clip: true

            StyledRect {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * (TimerService.running ? TimerService.progress : 0)
                variant: "primary"
                enableBorder: false
            }
        }

        Text {
            Layout.fillWidth: true
            text: TimerService.running
                ? (TimerService.label !== "" ? TimerService.label : "Countdown")
                : "Duration format: 5m, 1h30, 90s or 1:30"
            color: Colors.overSurfaceVariant
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.gap
            visible: !TimerService.running

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: Styling.fontSize(0) * 3
                variant: "internalbg"
                TextInput {
                    id: durationField
                    anchors.fill: parent
                    anchors.margins: root.gap
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.durationText
                    color: Colors.overSurface
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.overPrimary
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(1)
                    clip: true
                    onTextEdited: root.durationText = text
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: Styling.fontSize(0) * 3
                variant: "internalbg"
                TextInput {
                    id: labelField
                    anchors.fill: parent
                    anchors.margins: root.gap
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.labelText
                    color: Colors.overSurface
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.overPrimary
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    clip: true
                    onTextEdited: root.labelText = text
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: labelField.text === ""
                        text: "Label (optional)"
                        color: Colors.overSurfaceVariant
                        font: labelField.font
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: root.gap

            DetailButton {
                text: TimerService.running
                    ? (TimerService.paused ? "Resume" : "Pause") : "Start timer"
                icon: TimerService.running && !TimerService.paused ? "Ⅱ" : "▶"
                highlighted: true
                enabled: TimerService.running || root.validDuration
                onClicked: {
                    if (!TimerService.running) {
                        TimerService.start(TimerService.parse(root.durationText), root.labelText.trim())
                    } else if (TimerService.paused) {
                        TimerService.resume()
                    } else {
                        TimerService.pause()
                    }
                }
            }

            DetailButton {
                text: "Cancel"
                enabled: TimerService.running
                onClicked: TimerService.cancel()
            }
        }
    }
}