pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.components
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config

PanelWindow {
    id: root

    property ShellScreen targetScreen
    screen: targetScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nonchalant:osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    readonly property int bottomOffset: 48
    readonly property int cardHeight: 52
    property bool osdShown: false
    property real revealProgress: 0

    Behavior on revealProgress {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: GlobalStates.osdVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    // Include the final gap in this surface so the card can actually enter
    // from the screen boundary instead of materializing above it.
    WlrLayershell.margins.bottom: 0

    color: "transparent"
    implicitHeight: cardHeight + bottomOffset

    visible: osdShown

    // Internal state for responsiveness
    property real osdValue: 0
    property bool osdMuted: false

    // Centering wrapper
    Item {
        anchors.fill: parent
        clip: true

        StyledRect {
            id: osdRect
            variant: "popup"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.bottomOffset
            implicitWidth: 220
            implicitHeight: root.cardHeight
            radius: Styling.radius(16)
            transform: Translate {
                y: (1 - root.revealProgress)
                    * (osdRect.height + root.bottomOffset)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 24
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 14

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    id: iconText
                    text: {
                        if (GlobalStates.osdIndicator === "volume") {
                            return Audio.volumeIcon(root.osdValue, root.osdMuted);
                        } else if (GlobalStates.osdIndicator === "mic") {
                            return root.osdMuted ? Icons.micSlash : Icons.mic;
                        } else {
                            return Icons.sun;
                        }
                    }
                    font.family: Icons.font
                    font.pixelSize: 22
                    color: Colors.overBackground
                    Layout.alignment: Qt.AlignVCenter

                    rotation: GlobalStates.osdIndicator === "brightness" ? (root.osdValue * 180) : 0
                    scale: GlobalStates.osdIndicator === "brightness" ? (0.8 + (root.osdValue * 0.2)) : 1

                    Behavior on rotation {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    Behavior on scale {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: {
                                if (GlobalStates.osdIndicator === "volume")
                                    return "Volume";
                                if (GlobalStates.osdIndicator === "mic")
                                    return "Microphone";
                                if (GlobalStates.osdIndicator === "brightness")
                                    return "Brightness";
                                return "";
                            }
                            font.family: Config.theme.font
                            font.pixelSize: 15
                            font.bold: false
                            color: Colors.overBackground
                            Layout.alignment: Qt.AlignBottom
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: Math.round(root.osdValue * 100)
                            font.family: Config.theme.font
                            font.pixelSize: 15
                            font.bold: false
                            color: Colors.overBackground
                            Layout.alignment: Qt.AlignBottom
                        }
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                        value: root.osdValue
                        wavy: false
                        enabled: false
                        thickness: 3
                        handleSpacing: 0
                        progressColor: root.osdMuted ? Colors.outline : Styling.srItem("overprimary")
                        backgroundColor: Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.2)
                    }
                }
            }

            // Dismiss only when the moving card itself is reached. The extra
            // surface below it exists solely for the screen-edge animation.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: GlobalStates.osdVisible
                onEntered: {
                    hideTimer.stop();
                    hideTimer.triggered();
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 2500
        onTriggered: GlobalStates.osdVisible = false
    }

    Timer {
        id: closeTimer
        interval: Config.animDuration > 0 ? Config.animDuration + 40 : 40
        onTriggered: {
            if (!GlobalStates.osdVisible)
                root.osdShown = false;
        }
    }

    Connections {
        target: GlobalStates
        function onOsdVisibleChanged() {
            if (GlobalStates.osdVisible) {
                closeTimer.stop();
                root.osdShown = true;
                hideTimer.restart();
                Qt.callLater(() => {
                    if (GlobalStates.osdVisible)
                        root.revealProgress = 1;
                });
            } else if (root.osdShown) {
                root.revealProgress = 0;
                closeTimer.restart();
            }
        }
    }

    Component.onCompleted: {
        if (GlobalStates.osdVisible) {
            root.osdShown = true;
            Qt.callLater(() => root.revealProgress = 1);
        }
    }

    // Services connections - Direct and responsive
    Connections {
        target: Audio
        function onVolumeChanged(volume, muted, node) {
            root.osdValue = volume;
            root.osdMuted = muted;
            GlobalStates.osdIndicator = "volume";
            GlobalStates.osdVisible = true;
            hideTimer.restart();
        }
        function onMicVolumeChanged(volume, muted, node) {
            root.osdValue = volume;
            root.osdMuted = muted;
            GlobalStates.osdIndicator = "mic";
            GlobalStates.osdVisible = true;
            hideTimer.restart();
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged(value, screen) {
            // Check if the change happened on THIS screen or if it's a sync change
            if (!screen || !root.targetScreen || screen.name === root.targetScreen.name || Brightness.syncBrightness) {
                root.osdValue = value;
                root.osdMuted = false;
                GlobalStates.osdIndicator = "brightness";
                GlobalStates.osdVisible = true;
                hideTimer.restart();
            }
        }
    }
}
