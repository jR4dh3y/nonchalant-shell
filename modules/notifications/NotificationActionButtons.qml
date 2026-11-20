import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)
    property var actions: []
    property bool showWhen: true
    property var notificationObject: null
    property int urgency: NotificationUrgency.Normal

    Layout.fillWidth: true
    readonly property var validActions: actions.filter(action => action && String(action.text || "").trim() !== "")
    implicitHeight: showWhen && validActions.length > 0 ? 32 : 0
    height: implicitHeight
    clip: true

    RowLayout {
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: root.validActions

            Button {
                id: actionButton
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                text: modelData.text
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                font.weight: Font.Bold
                hoverEnabled: true
                scale: pressed ? 0.93 : 1.0

                PressBehavior on scale {
                    pressed: actionButton.pressed
                }

                background: StyledRect {
                    id: buttonBg
                    // The fill's paired ink: overError on critical, never shadow.
                    readonly property color textColor: buttonBg.item

                    // Critical actions fill with error; others are a
                    // primaryContainer call to action with a neutral hover lift.
                    variant: root.urgency === NotificationUrgency.Critical ? "error" : "primarycontainer"
                    radius: Styling.radius(4)

                    HoverTint {
                        hovered: actionButton.hovered
                        pressed: actionButton.pressed
                    }
                }

                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: parent.background.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration
                        }
                    }
                }

                onClicked: {
                    if (root.notificationObject) {
                        Notifications.attemptInvokeAction(root.notificationObject.id, modelData.identifier);
                    }
                }
            }
        }
    }
}
