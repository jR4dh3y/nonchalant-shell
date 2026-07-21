import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import "calendar"

Rectangle {
    id: root

    color: "transparent"
    implicitWidth: 544
    implicitHeight: 750

    property int leftPanelWidth: 0

    Process {
        id: colorPickerProcess
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        FullPlayer {
            Layout.preferredWidth: 216
            Layout.fillHeight: true
        }

        ClippingRectangle {
            id: widgetsContainer
            Layout.preferredWidth: controlButtonsContainer.implicitWidth
            Layout.fillHeight: true
            radius: Styling.radius(4)
            color: "transparent"

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: columnLayout.implicitHeight
                clip: true

                ColumnLayout {
                    id: columnLayout
                    width: parent.width
                    spacing: 8

                    QuickControls {
                        id: controlButtonsContainer
                    }

                    Calendar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width
                    }

                    StyledRect {
                        variant: "pane"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64

                        StyledRect {
                            anchors.fill: parent
                            anchors.margins: 4
                            variant: "internalbg"
                            radius: Styling.radius(0)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                ControlButton {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    iconName: Icons.wallpapers
                                    isActive: GlobalStates.dashboardCurrentTab === 1
                                    tooltipText: "Wallpapers"
                                    onClicked: GlobalStates.dashboardCurrentTab = 1
                                }

                                ControlButton {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    iconName: Icons.gear
                                    isActive: GlobalStates.settingsWindowVisible
                                    tooltipText: "Settings"
                                    onClicked: GlobalShortcuts.toggleSettings()
                                }

                                ControlButton {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    iconName: Icons.camera
                                    isActive: GlobalStates.screenshotToolVisible
                                    tooltipText: "Screenshot"
                                    onClicked: {
                                        Screenshot.initialize();
                                        GlobalStates.screenshotToolVisible = true;
                                    }
                                }

                                ControlButton {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    iconName: ScreenRecorder.isRecording ? Icons.stop : Icons.recordScreen
                                    isActive: ScreenRecorder.isRecording || GlobalStates.screenRecordToolVisible
                                    tooltipText: ScreenRecorder.isRecording ? "Stop Recording" : "Screen Recorder"
                                    onClicked: {
                                        if (ScreenRecorder.isRecording) {
                                            ScreenRecorder.toggleRecording();
                                        } else {
                                            ScreenRecorder.initialize();
                                            GlobalStates.screenRecordToolVisible = true;
                                        }
                                    }
                                }

                                ControlButton {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    iconName: Icons.picker
                                    isActive: colorPickerProcess.running
                                    tooltipText: "Color Picker"
                                    onClicked: {
                                        const scriptPath = Qt.resolvedUrl("../../../../scripts/colorpicker.py").toString().replace("file://", "");
                                        colorPickerProcess.command = ["bash", "-c", "nohup python3 \"" + scriptPath + "\" > /dev/null 2>&1 &"];
                                        colorPickerProcess.running = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        NotificationHistory {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
