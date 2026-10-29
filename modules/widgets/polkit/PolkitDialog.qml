pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.config

// Session polkit agent. Registers with polkitd and shows one password prompt
// on the focused output for each privileged request (pkexec, NetworkManager,
// systemctl, udisks...). Only one agent can own a session; the Niri profile
// starts polkit-gnome late, so it only takes over if this failed to register.
Scope {
    id: root

    readonly property AuthFlow flow: agent.flow
    readonly property bool requestActive: agent.isActive && root.flow !== null
    // True between submit and the next PAM prompt or completion.
    property bool submitting: false
    property bool showFailure: false
    property ShellScreen targetScreen: null

    function focusedScreen(): ShellScreen {
        const name = CompositorService.focusedMonitor?.name ?? "";
        return Quickshell.screens.find(screen => screen.name === name) ?? Quickshell.screens[0] ?? null;
    }

    function submit() {
        if (!root.flow?.isResponseRequired || passwordInput.text === "")
            return;
        root.submitting = true;
        root.showFailure = false;
        root.flow.submit(passwordInput.text);
        passwordInput.text = "";
    }

    function cancel() {
        passwordInput.text = "";
        root.flow?.cancelAuthenticationRequest();
    }

    onRequestActiveChanged: {
        if (requestActive) {
            Visibilities.closeActiveBarPopup();
            root.targetScreen = root.focusedScreen();
            root.submitting = false;
            root.showFailure = false;
            dialogWindow.visible = true;
            card.shown = true;
            Qt.callLater(() => passwordInput.forceActiveFocus());
        } else {
            passwordInput.text = "";
            root.submitting = false;
            card.shown = false;
        }
    }

    // polkitd queues requests per agent; each one gets a fresh flow.
    onFlowChanged: {
        root.submitting = false;
        root.showFailure = false;
    }

    PolkitAgent {
        id: agent

        onIsRegisteredChanged: console.info("PolkitDialog: registered with polkitd:", isRegistered)
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true

        function onAuthenticationFailed() {
            root.submitting = false;
            root.showFailure = true;
            shakeAnimation.restart();
        }

        function onIsResponseRequiredChanged() {
            if (root.flow?.isResponseRequired) {
                root.submitting = false;
                Qt.callLater(() => passwordInput.forceActiveFocus());
            }
        }
    }

    PanelWindow {
        id: dialogWindow

        screen: root.targetScreen
        visible: false
        color: "transparent"

        WlrLayershell.namespace: "nonchalant:polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.requestActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Shortcut {
            sequence: "Escape"
            enabled: root.requestActive
            onActivated: root.cancel()
        }

        // Dim the desktop so the prompt reads as system-owned, not app UI.
        // Clicks on the backdrop are swallowed: dismissing must be explicit.
        Rectangle {
            anchors.fill: parent
            color: Colors.withAlpha(Colors.scrim, 0.45)
            opacity: card.shown ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: card.shown ? Motion.fadeInDuration : Motion.collapseDuration
                    easing.type: Easing.OutQuad
                }
            }

            MouseArea {
                anchors.fill: parent
            }
        }

        Item {
            id: card

            property bool shown: false
            property real shakeOffset: 0

            anchors.centerIn: parent
            width: 400
            height: cardSurface.implicitHeight
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.92

            transform: Translate {
                x: card.shakeOffset
            }

            onOpacityChanged: {
                if (opacity === 0 && !shown)
                    dialogWindow.visible = false;
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: card.shown ? Motion.fadeInDuration : Motion.collapseDuration
                    easing.type: Easing.OutQuad
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: card.shown ? Motion.expandDuration : Motion.collapseDuration
                    easing.type: card.shown ? Easing.OutBack : Easing.OutQuad
                    easing.overshoot: Motion.overshoot
                }
            }

            FloatingSurface {
                id: cardSurface

                anchors.fill: parent
                implicitHeight: content.implicitHeight + 48
                radius: Styling.radius(16)
                enableShadow: true

                ColumnLayout {
                    id: content

                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        StyledRect {
                            id: shieldBadge

                            variant: "primary"
                            enableBorder: false
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: Styling.radius(8)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.shield
                                font.family: Icons.font
                                font.pixelSize: 22
                                color: shieldBadge.item
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: "Authentication required"
                                font.pixelSize: Styling.fontSize(2)
                                font.weight: Font.DemiBold
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.flow?.actionId ?? ""
                                color: Colors.outline
                                font.pixelSize: Styling.fontSize(-2)
                                elide: Text.ElideMiddle
                                visible: text !== ""
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.flow?.message ?? ""
                        wrapMode: Text.Wrap
                    }

                    StyledRect {
                        id: passwordBox

                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        variant: root.showFailure ? "error" : (passwordInput.activeFocus ? "focus" : "common")
                        radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 8

                            Text {
                                text: root.submitting ? Icons.circleNotch : Icons.key
                                font.family: Icons.font
                                font.pixelSize: 20
                                color: passwordBox.item
                                Layout.alignment: Qt.AlignVCenter

                                RotationAnimation on rotation {
                                    running: root.submitting
                                    from: 0
                                    to: 360
                                    duration: 800
                                    loops: Animation.Infinite
                                    onRunningChanged: {
                                        if (!running)
                                            parent.rotation = 0;
                                    }
                                }
                            }

                            TextField {
                                id: passwordInput

                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                enabled: root.flow?.isResponseRequired ?? false
                                echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                                placeholderText: String(root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                                placeholderTextColor: Colors.withAlpha(passwordBox.item, 0.5)
                                color: passwordBox.item
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                background: null
                                verticalAlignment: TextInput.AlignVCenter
                                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText

                                onTextEdited: root.showFailure = false
                                onAccepted: root.submit()
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        readonly property string supplementary: root.flow?.supplementaryMessage ?? ""
                        text: root.showFailure && supplementary === "" ? "Authentication failed. Try again." : supplementary
                        color: root.showFailure || root.flow?.supplementaryIsError ? Colors.error : Colors.outline
                        font.pixelSize: Styling.fontSize(-1)
                        wrapMode: Text.Wrap
                        visible: text !== ""
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                        }

                        DialogButton {
                            label: "Cancel"
                            variant: "common"
                            onActivated: root.cancel()
                        }

                        DialogButton {
                            label: "Authenticate"
                            variant: "primary"
                            enabled: (root.flow?.isResponseRequired ?? false) && passwordInput.text !== ""
                            onActivated: root.submit()
                        }
                    }
                }
            }
        }

        SequentialAnimation {
            id: shakeAnimation

            NumberAnimation { target: card; property: "shakeOffset"; to: 10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: card; property: "shakeOffset"; to: -10; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: card; property: "shakeOffset"; to: 10; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: card; property: "shakeOffset"; to: 0; duration: 50; easing.type: Easing.InOutQuad }
        }
    }

    component DialogButton: Item {
        id: button

        required property string label
        required property string variant
        signal activated

        implicitWidth: buttonLabel.implicitWidth + 32
        implicitHeight: 36
        opacity: enabled ? 1 : 0.5
        scale: buttonMouse.pressed ? 0.94 : 1

        PressBehavior on scale {
            pressed: buttonMouse.pressed
        }

        StyledRect {
            id: buttonSurface

            anchors.fill: parent
            variant: button.variant
            enableBorder: false
            radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0

            HoverTint {
                hovered: buttonMouse.containsMouse
                pressed: buttonMouse.pressed
            }

            StyledText {
                id: buttonLabel

                anchors.centerIn: parent
                text: button.label
                color: buttonSurface.item
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }
}
