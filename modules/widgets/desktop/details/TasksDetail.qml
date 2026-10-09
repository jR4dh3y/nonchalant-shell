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
    readonly property string initialTaskKey: {
        const routed = typeof root.row?.task === "string" ? root.row.task : ""
        if (routed !== "" && TasksService.entry(routed))
            return routed
        const opened = TasksService.opened
        return opened !== "" && TasksService.entry(opened)
            ? opened : (TasksService.tasks[0]?.key ?? "")
    }
    property string selectedKey: root.initialTaskKey
    readonly property var task: TasksService.entry(root.selectedKey)
    readonly property real gap: Styling.fontSize(-2)
    onSelectedKeyChanged: TasksService.open(root.selectedKey)
    onRowChanged: {
        root.selectedKey = root.initialTaskKey
    }
    Component.onCompleted: TasksService.open(root.selectedKey)
    Component.onDestruction: TasksService.leave()

    RowLayout {
        anchors.fill: parent
        spacing: root.gap

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.gap

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: `${TasksService.pending} to do · ${TasksService.count} total`
                    color: Colors.overSurfaceVariant
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                }
                DetailButton {
                    text: "New task"
                    icon: "+"
                    highlighted: true
                    onClicked: root.selectedKey = TasksService.create()
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: lanes.implicitWidth
                contentHeight: lanes.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                RowLayout {
                    id: lanes
                    spacing: root.gap

                    Repeater {
                        model: TasksService.states

                        ColumnLayout {
                            id: lane
                            required property var modelData
                            Layout.fillHeight: true
                            Layout.preferredWidth: Math.max(Styling.fontSize(0) * 11, (root.width - root.gap * 2) / 3)
                            spacing: root.gap / 2

                            Text {
                                Layout.fillWidth: true
                                text: `${lane.modelData.label} · ${TasksService.countIn(lane.modelData.id)}`
                                color: Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Repeater {
                                model: TasksService.inState(lane.modelData.id)

                                Item {
                                    id: taskCard
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: Styling.fontSize(0) * 3.5

                                    StyledRect {
                                        anchors.fill: parent
                                        variant: root.selectedKey === taskCard.modelData.key ? "focus" : "common"
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: root.gap
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: taskCard.modelData.text || "Untitled task"
                                            color: Colors.overSurface
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: taskCard.modelData.due !== ""
                                            text: TasksService.dueLabel(taskCard.modelData.due)
                                            color: TasksService.isOverdue(taskCard.modelData) ? Colors.error : Colors.overSurfaceVariant
                                            font.family: Config.theme.monoFont
                                            font.pixelSize: Styling.fontSize(-3)
                                            elide: Text.ElideRight
                                        }
                                    }

                                    TapHandler {
                                        gesturePolicy: TapHandler.ReleaseWithinBounds
                                        onTapped: {
                                            root.selectedKey = taskCard.modelData.key
                                            TasksService.open(taskCard.modelData.key)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        StyledRect {
            Layout.preferredWidth: root.width * 0.42
            Layout.fillHeight: true
            variant: "internalbg"
            visible: root.task !== null

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.gap
                spacing: root.gap

                RowLayout {
                    Layout.fillWidth: true
                    TextInput {
                        id: taskText
                        Layout.fillWidth: true
                        text: root.task ? root.task.text : ""
                        color: Colors.overSurface
                        selectionColor: Colors.primary
                        selectedTextColor: Colors.overPrimary
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(1)
                        font.weight: Font.DemiBold
                        clip: true
                        onTextEdited: if (root.task) TasksService.update(root.task.key, { text: text })
                    }
                    DetailButton {
                        text: "Remove"
                        onClicked: {
                            if (!root.task)
                                return
                            const old = root.task.key
                            TasksService.remove(old)
                            root.selectedKey = TasksService.queue[0]?.key ?? ""
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: Styling.fontSize(0) * 2.8
                    variant: "common"

                    TextInput {
                        id: dueInput
                        anchors.fill: parent
                        anchors.margins: root.gap
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.task ? root.task.due : ""
                        color: Colors.overSurface
                        selectionColor: Colors.primary
                        selectedTextColor: Colors.overPrimary
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-1)
                        clip: true
                        onEditingFinished: {
                            if (!root.task)
                                return
                            const due = TasksService.parseDue(text)
                            if (text.trim() === "" || due !== "")
                                TasksService.setDue(root.task.key, due)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: dueInput.text === ""
                            text: "Due date (e.g. tomorrow, fri)"
                            color: Colors.overSurfaceVariant
                            font: dueInput.font
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Details"
                    color: Colors.overSurfaceVariant
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    variant: "common"

                    TextEdit {
                        id: taskBody
                        anchors.fill: parent
                        anchors.margins: root.gap
                        text: root.task ? root.task.body : ""
                        color: Colors.overSurface
                        selectionColor: Colors.primary
                        selectedTextColor: Colors.overPrimary
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        clip: true
                        onTextChanged: {
                            if (activeFocus && root.task && text !== root.task.body)
                                TasksService.update(root.task.key, { body: text })
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: root.gap
                        visible: taskBody.text === "" && !taskBody.activeFocus
                        text: "Add a description…"
                        color: Colors.overSurfaceVariant
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.gap / 2
                    Repeater {
                        model: TasksService.states
                        delegate: DetailButton {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.label
                            highlighted: !!root.task && root.task.state === modelData.id
                            onClicked: if (root.task) TasksService.setState(root.task.key, modelData.id)
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.task === null
            text: "Select a task or create one to edit its details."
            color: Colors.overSurfaceVariant
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
        }
    }
}