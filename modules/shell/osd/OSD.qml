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
    WlrLayershell.margins.bottom: 0

    color: "transparent"
    // Headroom above the card for the spring stretch.
    implicitHeight: cardHeight + bottomOffset + 16
    mask: Region {
        item: osdSurface.body
    }

    readonly property bool isIsland: (Config.bar?.style ?? "default") === "island"
    // The island embeds its own OSD banner.
    readonly property bool showing: GlobalStates.osdVisible && !isIsland

    visible: showing || !osdSurface.fullyHidden

    // Internal state for responsiveness
    property real osdValue: 0
    property bool osdMuted: false

    // Pinches out into a pill from a round nub, like the island's OSD.
    MorphSurface {
        id: osdSurface

        shown: root.showing
        contentWidth: 220
        contentHeight: root.cardHeight
        originWidth: root.cardHeight
        fromBottom: true
        padding: 0
        radius: Styling.radius(16)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomOffset

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 24
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 14

            DynamicSunIcon {
                visible: GlobalStates.osdIndicator === "brightness"
                size: 24
                value: root.osdValue
                color: Colors.overBackground
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                visible: GlobalStates.osdIndicator !== "brightness"
                id: iconText
                text: {
                    if (GlobalStates.osdIndicator === "volume") {
                        return Audio.volumeIcon(root.osdValue, root.osdMuted);
                    } else if (GlobalStates.osdIndicator === "mic") {
                        return root.osdMuted ? Icons.micSlash : Icons.mic;
                    }
                    return "";
                }
                font.family: Icons.font
                font.pixelSize: 22
                color: Colors.overBackground
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
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

                    StyledText {
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

        // Hovering the card dismisses it.
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

    Timer {
        id: hideTimer
        interval: 2500
        onTriggered: GlobalStates.osdVisible = false
    }

    Connections {
        target: GlobalStates
        function onOsdVisibleChanged() {
            if (root.showing)
                hideTimer.restart();
        }
    }

    // Services connections - Direct and responsive
    Connections {
        target: Audio
        function onVolumeChanged(volume, muted, node) {
            if (root.isIsland)
                return;
            root.osdValue = volume;
            root.osdMuted = muted;
            GlobalStates.osdIndicator = "volume";
            GlobalStates.osdVisible = true;
            hideTimer.restart();
        }
        function onMicVolumeChanged(volume, muted, node) {
            if (root.isIsland)
                return;
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
            if (root.isIsland)
                return;
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
