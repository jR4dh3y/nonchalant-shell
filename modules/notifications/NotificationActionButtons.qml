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
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                text: modelData.text
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                font.weight: Font.Bold
                hoverEnabled: true
                scale: pressed ? 0.93 : 1.0

                Behavior on scale {
                    enabled: (Config.animDuration ?? 0) > 0
                    NumberAnimation {
                        duration: pressed ? 80 : 250
                        easing.type: pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.5
                    }
                }

                background: StyledRect {
                    id: buttonBg
                    readonly property color textColor: root.urgency === NotificationUrgency.Critical
                        ? Colors.shadow
                        : buttonBg.item

                    variant: root.urgency === NotificationUrgency.Critical
                        ? "error"
                        : (parent.pressed ? "primary" : (parent.hovered ? "focus" : "common"))
                    radius: Styling.radius(4)
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
