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
    property string selectedKey: typeof root.row?.note === "string" && root.row.note !== ""
        ? root.row.note : (NotesService.noteFor(root.row)?.key ?? "")
    readonly property var note: NotesService.entry(root.selectedKey)
    readonly property real gap: Styling.fontSize(-2)

    onSelectedKeyChanged: NotesService.open(root.selectedKey)
    onRowChanged: {
        const key = typeof root.row?.note === "string" && root.row.note !== ""
            ? root.row.note : (NotesService.noteFor(root.row)?.key ?? "")
        root.selectedKey = key
    }

    Component.onCompleted: NotesService.open(root.selectedKey)
    Component.onDestruction: NotesService.leave()

    RowLayout {
        anchors.fill: parent
        spacing: root.gap

        ColumnLayout {
            Layout.preferredWidth: parent.width * 0.36
            Layout.fillHeight: true
            spacing: root.gap

            DetailButton {
                Layout.fillWidth: true
                text: "New note"
                icon: "+"
                highlighted: true
                onClicked: root.selectedKey = NotesService.create("yellow")
            }

            Text {
                Layout.fillWidth: true
                text: `${NotesService.live.length} notes`
                color: Colors.overSurfaceVariant
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: root.gap / 2
                model: NotesService.live

                delegate: Item {
                    id: noteRow
                    required property var modelData

                    implicitHeight: Styling.fontSize(0) * 3.2
                    width: ListView.view.width

                    StyledRect {
                        anchors.fill: parent
                        variant: root.selectedKey === noteRow.modelData.key ? "focus" : "common"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.gap
                        anchors.rightMargin: root.gap
                        spacing: root.gap

                        Rectangle {
                            Layout.preferredWidth: Styling.fontSize(-1)
                            Layout.preferredHeight: Styling.fontSize(-1)
                            radius: width / 2
                            color: NotesService.tintColor(noteRow.modelData.tint)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: NotesService.titleOf(noteRow.modelData)
                            color: Colors.overSurface
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            elide: Text.ElideRight
                        }
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.selectedKey = noteRow.modelData.key
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: NotesService.live.length === 0
                    text: "No notes yet. Create one to start writing."
                    color: Colors.overSurfaceVariant
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    wrapMode: Text.WordWrap
                    width: parent.width - 2 * root.gap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.gap
            visible: root.note !== null

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: Styling.fontSize(0) * 3.2
                variant: "internalbg"

                TextInput {
                    id: titleInput
                    anchors.fill: parent
                    anchors.leftMargin: root.gap
                    anchors.rightMargin: root.gap
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.note ? root.note.title : ""
                    color: Colors.overSurface
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.overPrimary
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    font.weight: Font.DemiBold
                    clip: true
                    onTextEdited: if (root.note) NotesService.update(root.note.key, { title: text })
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: titleInput.text === ""
                        text: "Title"
                        color: Colors.overSurfaceVariant
                        font: titleInput.font
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.gap / 2

                Repeater {
                    model: NotesService.tints
                    delegate: Item {
                        id: tintChoice
                        required property string modelData
                        implicitWidth: Styling.fontSize(0) * 2
                        implicitHeight: implicitWidth
                        property bool selected: !!root.note && root.note.tint === tintChoice.modelData

                        Rectangle {
                            anchors.centerIn: parent
                            width: Styling.fontSize(0)
                            height: width
                            radius: width / 2
                            color: NotesService.tintColor(tintChoice.modelData)
                            border.color: tintChoice.selected ? Colors.overSurface : "transparent"
                            border.width: tintChoice.selected ? 2 : 0
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: if (root.note) NotesService.setTint(root.note.key, tintChoice.modelData)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                DetailButton {
                    text: "Archive"
                    enabled: root.note !== null
                    onClicked: {
                        if (!root.note)
                            return
                        NotesService.archive(root.note.key, true)
                        root.selectedKey = NotesService.newest?.key ?? ""
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                variant: "internalbg"

                TextEdit {
                    id: bodyInput
                    anchors.fill: parent
                    anchors.margins: root.gap
                    text: root.note ? root.note.text : ""
                    color: Colors.overSurface
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.overPrimary
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    clip: true
                    onTextChanged: {
                        if (activeFocus && root.note && text !== root.note.text)
                            NotesService.update(root.note.key, { text: text })
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: root.gap
                    visible: bodyInput.text === "" && !bodyInput.activeFocus
                    text: "Write something…"
                    color: Colors.overSurfaceVariant
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.note === null
            text: "Choose a note or create a new one."
            color: Colors.overSurfaceVariant
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Connections {
        target: NotesService
        function onAdded(key: string): void { root.selectedKey = key }
    }
}