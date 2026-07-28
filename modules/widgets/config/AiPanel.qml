import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    property int maxContentWidth: 560
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: Math.max(0, (width - contentWidth) / 2)

    Flickable {
        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight + 40
        clip: true
        bottomMargin: 40

        ColumnLayout {
            id: contentColumn
            width: root.contentWidth
            x: root.sideMargin
            y: 20
            spacing: 20

            Text {
                Layout.fillWidth: true
                text: "AI Agents"
                font.family: Config.theme.font
                font.pixelSize: 24
                font.weight: Font.Bold
                color: Colors.overSurface
            }

            Text {
                Layout.fillWidth: true
                text: "The assistant uses Agent Client Protocol (ACP). Each local agent owns its authentication, models, tools, and billing; Nonchalant only provides the sidebar client."
                font.family: Config.theme.font
                font.pixelSize: 13
                color: Colors.outline
                wrapMode: Text.Wrap
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 64
                variant: "surface"
                radius: Styling.radius(8)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Enable AI"
                            font.family: Config.theme.font
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Colors.overSurface
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Allow ACP agents to start and provide assistant features."
                            font.family: Config.theme.font
                            font.pixelSize: 12
                            color: Colors.outline
                            wrapMode: Text.Wrap
                        }
                    }

                    Switch {
                        checked: Config.ai.enabled ?? true
                        onToggled: Config.ai.enabled = checked
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !(Config.ai.enabled ?? true)
                text: "AI is disabled. No ACP agent processes will be started."
                font.family: Config.theme.font
                font.pixelSize: 13
                color: Colors.outline
                wrapMode: Text.Wrap
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: workingDirectoryColumn.implicitHeight + 32
                variant: "surface"
                radius: Styling.radius(8)
                enabled: Config.ai.enabled ?? true
                opacity: enabled ? 1 : 0.5

                ColumnLayout {
                    id: workingDirectoryColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Text {
                        text: "Working directory"
                        font.family: Config.theme.font
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Colors.overSurface
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "New ACP sessions start here. Leave empty to use your home directory."
                        font.family: Config.theme.font
                        font.pixelSize: 12
                        color: Colors.outline
                        wrapMode: Text.Wrap
                    }

                    TextField {
                        id: workingDirectoryInput
                        Layout.fillWidth: true
                        text: Config.ai && Config.ai.workingDirectory ? Config.ai.workingDirectory : ""
                        placeholderText: "~/code/project"
                        color: Colors.overSurface
                        font.family: Config.theme.font
                        onEditingFinished: {
                            if (Config.ai && Config.ai.workingDirectory !== text)
                                Config.setAiWorkingDirectory(text);
                        }

                        background: StyledRect {
                            variant: "internalbg"
                            radius: Styling.radius(4)
                            border.width: workingDirectoryInput.activeFocus ? 2 : 0
                            border.color: Styling.srItem("primary")
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "ACP agents"
                visible: Config.ai.enabled ?? true
                font.family: Config.theme.font
                font.pixelSize: 18
                font.weight: Font.Bold
                color: Colors.overSurface
            }

            Repeater {
                model: (Config.ai.enabled ?? true) ? Ai.models : []

                delegate: StyledRect {
                    id: agentCard
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: agentColumn.implicitHeight + 32
                    variant: Ai.currentAgentId === modelData.id ? "focus" : "surface"
                    radius: Styling.radius(8)

                    ColumnLayout {
                        id: agentColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Image {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                source: modelData.icon || ""
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.family: Config.theme.font
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                    color: Colors.overSurface
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.description || ""
                                    font.family: Config.theme.font
                                    font.pixelSize: 12
                                    color: Colors.outline
                                    wrapMode: Text.Wrap
                                }
                            }

                            Text {
                                text: Ai.currentAgentId === modelData.id
                                    ? (Ai.sessionReady ? "Connected" : "Selected") : ""
                                font.family: Config.theme.font
                                font.pixelSize: 12
                                color: Ai.sessionReady && Ai.currentAgentId === modelData.id
                                    ? Colors.success : Styling.srItem("overprimary")
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: commandText.implicitHeight + 16
                            variant: "internalbg"
                            radius: Styling.radius(4)

                            Text {
                                id: commandText
                                anchors.fill: parent
                                anchors.margins: 8
                                text: modelData.command.join(" ")
                                font.family: "Monospace"
                                font.pixelSize: 12
                                color: Colors.outline
                                wrapMode: Text.WrapAnywhere
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.installHint || ""
                            font.family: Config.theme.font
                            font.pixelSize: 12
                            color: Colors.outline
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: 8

                            Button {
                                visible: Ai.currentAgentId === modelData.id
                                text: "Reconnect"
                                flat: true
                                onClicked: Ai.reconnectAgent()

                                background: StyledRect {
                                    variant: parent.hovered ? "focus" : "pane"
                                    radius: Styling.radius(4)
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: Colors.overSurface
                                    font.family: Config.theme.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Button {
                                text: Ai.currentAgentId === modelData.id ? "Active" : "Use agent"
                                enabled: Ai.currentAgentId !== modelData.id
                                flat: true
                                onClicked: Ai.setModel(modelData.id)

                                background: StyledRect {
                                    variant: parent.enabled ? "primary" : "pane"
                                    radius: Styling.radius(4)
                                    opacity: parent.enabled ? 1 : 0.6
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? Colors.overPrimary : Colors.outline
                                    font.family: Config.theme.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                visible: (Config.ai.enabled ?? true) && Ai.currentSessionModelId.length > 0
                implicitHeight: activeSessionColumn.implicitHeight + 32
                variant: "surface"
                radius: Styling.radius(8)

                ColumnLayout {
                    id: activeSessionColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6

                    Text {
                        text: "Active ACP session"
                        font.family: Config.theme.font
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Colors.overSurface
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Model: " + (Ai.currentSessionModelId || "agent default")
                            + (Ai.currentModeId ? "\nMode: " + Ai.currentModeId : "")
                        font.family: "Monospace"
                        font.pixelSize: 12
                        color: Colors.outline
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
        }
    }
}
