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
    readonly property real gap: Styling.fontSize(-2)
    readonly property var pet: PetService.pet

    ColumnLayout {
        anchors.fill: parent
        spacing: root.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: root.gap

            StyledRect {
                Layout.preferredWidth: Styling.fontSize(0) * 10
                Layout.preferredHeight: Layout.preferredWidth
                variant: "focus"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.pet ? PetService.speciesOf(root.pet).label.slice(0, 1) : "?"
                        color: Colors.primary
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(14)
                        font.weight: Font.Bold
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: PetService.hatched ? `Lv ${PetService.level}` : "Egg"
                        color: Colors.overSurfaceVariant
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-1)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.gap / 2

                Text {
                    Layout.fillWidth: true
                    text: PetService.name !== "" ? PetService.name : PetService.speciesInfo.label
                    color: Colors.overSurface
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(3)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: PetService.moodLine
                    color: Colors.overSurfaceVariant
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    wrapMode: Text.WordWrap
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
                        width: parent.width * PetService.progress
                        variant: "primary"
                        enableBorder: false
                    }
                }

                TextInput {
                    id: petName
                    Layout.fillWidth: true
                    visible: PetService.hatched
                    text: PetService.name
                    color: Colors.overSurface
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.overPrimary
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    clip: true
                    onTextEdited: PetService.rename(text)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: petName.text === ""
                        text: PetService.speciesInfo.label
                        color: Colors.overSurfaceVariant
                        font: petName.font
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.gap

            DetailButton {
                Layout.fillWidth: true
                text: PetService.canFeed ? "Feed" : "Fed for now"
                icon: "♥"
                highlighted: PetService.canFeed
                enabled: PetService.canFeed
                onClicked: PetService.feed()
            }
            DetailButton {
                Layout.fillWidth: true
                text: PetService.canPlay ? "Play" : "Resting"
                icon: "★"
                enabled: PetService.canPlay
                onClicked: PetService.play()
            }
        }

        Text {
            Layout.fillWidth: true
            text: `Family · ${PetService.family.length} ${PetService.family.length === 1 ? "pet" : "pets"}`
            color: Colors.overSurfaceVariant
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.DemiBold
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: root.gap / 2
            model: PetService.family

            delegate: Item {
                id: familyRow
                required property int index
                required property var modelData
                width: ListView.view.width
                implicitHeight: Styling.fontSize(0) * 3.5

                StyledRect {
                    anchors.fill: parent
                    variant: familyRow.index === PetService.activeIndex ? "focus" : "common"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.gap
                    anchors.rightMargin: root.gap
                    spacing: root.gap

                    Text {
                        text: PetService.speciesOf(familyRow.modelData).label
                        color: Colors.overSurface
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: PetService.titleOf(familyRow.modelData)
                        color: Colors.overSurfaceVariant
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        elide: Text.ElideRight
                    }
                    Text {
                        text: `Lv ${familyRow.modelData.level}`
                        color: Colors.overSurfaceVariant
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-1)
                    }
                    DetailButton {
                        text: familyRow.index === PetService.activeIndex ? "Active" : "Bring out"
                        enabled: familyRow.index !== PetService.activeIndex
                        onClicked: PetService.bringOut(familyRow.index)
                    }
                }
            }
        }
    }
}