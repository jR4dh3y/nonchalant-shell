import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Io
import qs.config
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

    Process {
        id: ocrProcess
    }

    Process {
        id: qrProcess
    }

    Process {
        id: openFolderProcess
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
                        Layout.preferredHeight: toolsInner.implicitHeight + 8

                        StyledRect {
                            id: toolsInner
                            anchors.fill: parent
                            anchors.margins: 4
                            variant: "internalbg"
                            radius: Styling.radius(0)
                            implicitHeight: toolsColumn.implicitHeight + 8

                            ColumnLayout {
                                id: toolsColumn
                                anchors.centerIn: parent
                                spacing: 4

                                // Primary tools
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
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

                                // Secondary tools
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 4

                                    ControlButton {
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        iconName: Icons.textT
                                        isActive: ocrProcess.running
                                        tooltipText: "OCR"
                                        onClicked: {
                                            const scriptPath = Qt.resolvedUrl("../../../../scripts/ocr.sh").toString().replace("file://", "");
                                            const ocrConfig = Config.system.ocr;
                                            let langs = [];
                                            if (ocrConfig) {
                                                if (ocrConfig.eng !== false) langs.push("eng");
                                                if (ocrConfig.spa !== false) langs.push("spa");
                                                if (ocrConfig.lat === true) langs.push("lat");
                                                if (ocrConfig.jpn === true) langs.push("jpn");
                                                if (ocrConfig.chi_sim === true) langs.push("chi_sim");
                                                if (ocrConfig.chi_tra === true) langs.push("chi_tra");
                                                if (ocrConfig.kor === true) langs.push("kor");
                                            } else {
                                                langs = ["eng", "spa"];
                                            }
                                            if (langs.length === 0)
                                                langs.push("eng");
                                            ocrProcess.command = ["bash", "-c", "nohup \"" + scriptPath + "\" \"" + langs.join("+") + "\" > /dev/null 2>&1 &"];
                                            ocrProcess.running = true;
                                        }
                                    }

                                    ControlButton {
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        iconName: Icons.qrCode
                                        isActive: qrProcess.running
                                        tooltipText: "QR Code"
                                        onClicked: {
                                            const scriptPath = Qt.resolvedUrl("../../../../scripts/qr_scan.sh").toString().replace("file://", "");
                                            qrProcess.command = ["bash", "-c", "nohup \"" + scriptPath + "\" > /dev/null 2>&1 &"];
                                            qrProcess.running = true;
                                        }
                                    }

                                    ControlButton {
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        iconName: Icons.google
                                        isActive: false
                                        tooltipText: "Google Lens"
                                        onClicked: {
                                            Screenshot.captureMode = "lens";
                                            GlobalStates.screenshotToolVisible = true;
                                        }
                                    }

                                    ControlButton {
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        iconName: GlobalStates.mirrorWindowVisible ? Icons.webcamSlash : Icons.webcam
                                        isActive: GlobalStates.mirrorWindowVisible
                                        tooltipText: "Mirror"
                                        onClicked: GlobalStates.mirrorWindowVisible = !GlobalStates.mirrorWindowVisible
                                    }

                                    ControlButton {
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        iconName: Icons.screenshots
                                        isActive: false
                                        tooltipText: "Open Screenshots"
                                        onClicked: {
                                            openFolderProcess.command = ["bash", "-c", "dir=\"$(xdg-user-dir PICTURES)/Screenshots\"; mkdir -p \"$dir\"; nohup xdg-open \"$dir\" > /dev/null 2>&1 &"];
                                            openFolderProcess.running = true;
                                        }
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
