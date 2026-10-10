pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.config

Item {
    id: root

    property string currentSection: "modules"
    readonly property int widgetCount: Config.desktop.widgets?.length ?? 0
    readonly property var petStyles: [
        { value: "creature", label: "Creature" },
        { value: "plush", label: "Plush" },
        { value: "paper", label: "Paper" },
        { value: "pixel", label: "Pixel" }
    ]
    readonly property var grounds: [
        { value: "", label: "Follow bar" },
        { value: "solid", label: "Solid" },
        { value: "glass", label: "Glass" }
    ]

    function saveGithubUsername(): void {
        const username = githubUsernameField.text.trim().replace(/^@/, "")
        if (username !== (Config.desktop.githubUser ?? ""))
            Config.desktop.githubUser = username
    }

    function resetScroll(): void {
        contentScroller.contentY = 0
    }

    component ChoiceButton: Button {
        id: choice
        required property string label
        required property string value
        required property string selectedValue
        signal picked(string value)

        activeFocusOnTab: true
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        padding: 0
        Accessible.role: Accessible.Button
        Accessible.name: choice.label

        background: StyledRect {
            variant: choice.value === choice.selectedValue ? "primary"
                : (choice.activeFocus || choice.hovered ? "focus" : "common")
            radius: Styling.radius(-4)
        }

        contentItem: Text {
            text: choice.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: choice.value === choice.selectedValue ? Font.DemiBold : Font.Normal
            color: choice.value === choice.selectedValue ? Styling.srItem("primary") : Colors.overBackground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        onClicked: choice.picked(choice.value)
    }

    component PreferenceToggle: StyledRect {
        id: preference
        required property string label
        property string description: ""
        required property bool checked
        signal toggled(bool checked)

        Layout.fillWidth: true
        Layout.preferredHeight: description === "" ? 58 : 72
        variant: "common"
        radius: Styling.radius(0)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: preference.label
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.Medium
                    color: Colors.overBackground
                    wrapMode: Text.Wrap
                }

                Text {
                    visible: preference.description !== ""
                    Layout.fillWidth: true
                    text: preference.description
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                    wrapMode: Text.Wrap
                }
            }

            Switch {
                checked: preference.checked
                onToggled: preference.toggled(checked)
            }
        }
    }

    Flickable {
        id: contentScroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentColumn
            width: contentScroller.width
            spacing: 10

            ColumnLayout {
                visible: root.currentSection === "modules"
                Layout.fillWidth: true
                spacing: 10

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: githubContent.implicitHeight + 24
                    variant: "common"
                    radius: Styling.radius(0)

                    ColumnLayout {
                        id: githubContent
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "GitHub"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(1)
                            font.weight: Font.DemiBold
                            color: Colors.overBackground
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Username for the desktop contribution widget."
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            variant: "pane"
                            radius: Styling.radius(-4)

                            TextField {
                                id: githubUsernameField
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                placeholderText: "GitHub username"
                                placeholderTextColor: Colors.outline
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overBackground
                                selectByMouse: true
                                background: null

                                onAccepted: {
                                    root.saveGithubUsername()
                                    focus = false
                                }
                                onEditingFinished: root.saveGithubUsername()
                            }

                            Binding {
                                target: githubUsernameField
                                property: "text"
                                value: Config.desktop.githubUser ?? ""
                                when: !githubUsernameField.activeFocus
                            }
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: petContent.implicitHeight + 24
                    variant: "common"
                    radius: Styling.radius(0)

                    ColumnLayout {
                        id: petContent
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "Pet style"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(1)
                            font.weight: Font.DemiBold
                            color: Colors.overBackground
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "The pet uses the same drawing style across desktop and shell surfaces."
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: root.petStyles
                                delegate: ChoiceButton {
                                    required property var modelData
                                    label: modelData.label
                                    value: modelData.value
                                    selectedValue: Config.desktop.petStyle ?? "creature"
                                    onPicked: value => Config.desktop.petStyle = value
                                }
                            }
                        }
                    }
                }

                PreferenceToggle {
                    label: "Handwritten notes"
                    description: "Use the script face for desktop notes."
                    checked: Config.desktop.notesHandwriting ?? true
                    onToggled: checked => Config.desktop.notesHandwriting = checked
                }

                PreferenceToggle {
                    label: "Deck only on an empty workspace"
                    description: "Hide the desktop deck while windows are open."
                    checked: Config.desktop.deckOnEmpty ?? false
                    onToggled: checked => Config.desktop.deckOnEmpty = checked
                }

                PreferenceToggle {
                    label: "Spectrum only on an empty workspace"
                    description: "Hide desktop spectrum bars while windows are open."
                    checked: Config.desktop.spectrumOnEmpty ?? false
                    onToggled: checked => Config.desktop.spectrumOnEmpty = checked
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: clockContent.implicitHeight + 24
                    variant: "common"
                    radius: Styling.radius(0)

                    ColumnLayout {
                        id: clockContent
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "Desktop clock"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(1)
                            font.weight: Font.DemiBold
                            color: Colors.overBackground
                        }

                        PreferenceToggle {
                            label: "Show seconds"
                            description: "Include seconds in the desktop clock."
                            checked: Config.desktop.clockShowsSeconds ?? false
                            onToggled: checked => Config.desktop.clockShowsSeconds = checked
                        }

                        Text {
                            Layout.fillWidth: true
                            text: `Time format follows the bar: ${Config.bar.use12hFormat ? "12-hour" : "24-hour"}.`
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overSurfaceVariant
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            ColumnLayout {
                visible: root.currentSection === "widgets"
                Layout.fillWidth: true
                spacing: 10

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: editorContent.implicitHeight + 24
                    variant: "common"
                    radius: Styling.radius(0)

                    ColumnLayout {
                        id: editorContent
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "Desktop widgets"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(1)
                            font.weight: Font.DemiBold
                            color: Colors.overBackground
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.fillWidth: true
                                text: root.widgetCount === 1 ? "1 widget on the desktop" : `${root.widgetCount} widgets on the desktop`
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overSurfaceVariant
                            }

                            Button {
                                id: editorButton
                                text: DesktopWidgetService.editing ? "Close editor" : "Arrange widgets"
                                implicitHeight: 36
                                padding: 12

                                background: StyledRect {
                                    variant: editorButton.hovered ? "focus" : "primary"
                                    radius: Styling.radius(-4)
                                }

                                contentItem: Text {
                                    text: editorButton.text
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.DemiBold
                                    color: Styling.srItem("primary")
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    if (DesktopWidgetService.editing) {
                                        DesktopWidgetService.closeEditor()
                                    } else {
                                        DesktopWidgetService.openEditor(QsWindow.window?.screen?.name ?? "")
                                    }
                                }
                            }
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: themeContent.implicitHeight + 24
                    variant: "common"
                    radius: Styling.radius(0)

                    ColumnLayout {
                        id: themeContent
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "Widget appearance"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(1)
                            font.weight: Font.DemiBold
                            color: Colors.overBackground
                        }

                        Text {
                            text: "Theme"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: DesktopWidgetService.themes
                                delegate: ChoiceButton {
                                    required property var modelData
                                    label: modelData.label
                                    value: modelData.id
                                    selectedValue: Config.desktop.theme ?? "modern"
                                    onPicked: value => Config.desktop.theme = value
                                }
                            }
                        }

                        Text {
                            text: "Ground"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: root.grounds
                                delegate: ChoiceButton {
                                    required property var modelData
                                    label: modelData.label
                                    value: modelData.value
                                    selectedValue: Config.desktop.ground ?? ""
                                    onPicked: value => Config.desktop.ground = value
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.fillWidth: true
                                text: "Background opacity"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overBackground
                            }

                            Text {
                                text: `${Math.round(Config.desktop.opacity ?? 100)}%`
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overSurfaceVariant
                            }
                        }

                        StyledSlider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            value: Math.max(0, Math.min(100, Config.desktop.opacity ?? 100)) / 100
                            stepSize: 0.05
                            snapMode: "always"
                            tooltipText: `${Math.round(value * 100)}%`
                            onValueChanged: {
                                const opacity = Math.round(value * 100)
                                if (opacity !== Config.desktop.opacity)
                                    Config.desktop.opacity = opacity
                            }
                        }
                    }
                }

                PreferenceToggle {
                    label: "Hide desktop widgets"
                    description: "Keep desktop widgets off the wallpaper until enabled again."
                    checked: Config.desktop.hidden ?? false
                    onToggled: checked => Config.desktop.hidden = checked
                }

                PreferenceToggle {
                    label: "Widget shadows"
                    description: "Draw a shadow behind desktop widgets."
                    checked: Config.desktop.widgetShadow ?? false
                    onToggled: checked => Config.desktop.widgetShadow = checked
                }
            }
        }
    }
}
