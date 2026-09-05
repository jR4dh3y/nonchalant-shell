pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    implicitWidth: 400
    implicitHeight: Math.min(480, mainColumn.implicitHeight + 28)

    signal backRequested()

    readonly property real micVolume: Audio.source?.audio?.volume ?? 0.0
    readonly property bool isMuted: Audio.source?.audio?.muted ?? false
    readonly property string activeSourceId: Audio.source?.id ? String(Audio.source.id) : ""

    readonly property var inputDevices: {
        const nodes = Pipewire.nodes.values;
        if (!nodes)
            return [];
        return nodes.filter(node => node && !node.isSink && !node.isStream && node.audio && (!node.name || !node.name.endsWith(".monitor")));
    }

    readonly property var appNodes: {
        const nodes = Pipewire.nodes.values;
        if (!nodes)
            return [];
        return nodes.filter(node => node && !node.isSink && node.isStream && node.audio);
    }

    ColumnLayout {
        id: mainColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 10

        // Header: Back button + Title
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: backMouse.containsMouse ? "focus" : "common"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowLeft
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: Colors.overBackground
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }

                StyledToolTip {
                    show: backMouse.containsMouse
                    tooltipText: "Back to dashboard"
                }
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Microphone"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
            }

            Item { Layout.fillWidth: true }
        }

        // Master Mic Volume Slider row
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                implicitWidth: 22
                implicitHeight: 22
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: root.isMuted ? Icons.micSlash : Icons.mic
                    font.family: Icons.font
                    font.pixelSize: 18
                    color: root.isMuted ? Colors.red : Colors.overBackground
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.toggleMicMute()
                }
            }

            // Slider track
            StyledSlider {
                id: micSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                value: root.micVolume
                progressColor: root.isMuted ? Colors.outlineVariant : Colors.primary
                onValueChanged: {
                    if (Audio.source?.audio && Math.abs(value - root.micVolume) > 0.01) {
                        Audio.setMicVolume(value);
                    }
                }
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: Math.round(root.micVolume * 100) + "%"
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: Colors.overBackground
            }
        }

        // Scrollable content area for input devices and recording apps
        Item {
            Layout.fillWidth: true
            implicitHeight: Math.min(320, scrollContent.implicitHeight)

            Flickable {
                anchors.fill: parent
                contentHeight: scrollContent.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: scrollContent
                    width: parent.width
                    spacing: 8

                    // Section 1: Input Devices
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: "INPUT DEVICE"
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-2)
                        font.bold: true
                        color: Colors.overSurfaceVariant
                        Layout.topMargin: 4
                    }

                    Repeater {
                        model: root.inputDevices

                        delegate: Item {
                            id: delegateRoot
                            required property PwNode modelData

                            PwObjectTracker {
                                objects: [delegateRoot.modelData]
                            }

                            Layout.fillWidth: true
                            implicitHeight: 38

                            readonly property bool isCurrent: delegateRoot.modelData === Audio.source || String(delegateRoot.modelData.id) === root.activeSourceId

                            StyledRect {
                                anchors.fill: parent
                                radius: Styling.radius(2)
                                variant: delegateRoot.isCurrent ? "primary" : (devMouse.containsMouse ? "pane" : "internalbg")
                                enableBorder: delegateRoot.isCurrent

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text {
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        text: Icons.mic
                                        font.family: Icons.font
                                        font.pixelSize: 16
                                        color: delegateRoot.isCurrent ? Colors.overPrimary : Colors.overBackground
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        text: Audio.friendlyDeviceName(delegateRoot.modelData)
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        font.bold: delegateRoot.isCurrent
                                        color: delegateRoot.isCurrent ? Colors.overPrimary : Colors.overBackground
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: delegateRoot.isCurrent
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        text: Icons.check
                                        font.family: Icons.font
                                        font.pixelSize: 16
                                        color: Colors.overPrimary
                                    }
                                }

                                MouseArea {
                                    id: devMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Audio.setDefaultSource(delegateRoot.modelData);
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.inputDevices.length === 0
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: "No input devices found"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                        opacity: 0.6
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                    }

                    // Section 2: Application Recording Streams
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: "APPLICATIONS USING MIC"
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-2)
                        font.bold: true
                        color: Colors.overSurfaceVariant
                        Layout.topMargin: 8
                    }

                    Repeater {
                        model: root.appNodes

                        delegate: Item {
                            id: appDelegate
                            required property PwNode modelData

                            PwObjectTracker {
                                objects: [appDelegate.modelData]
                            }

                            Layout.fillWidth: true
                            implicitHeight: 60

                            readonly property bool isAppMuted: appDelegate.modelData?.audio?.muted ?? false
                            readonly property real appVolume: appDelegate.modelData?.audio?.volume ?? 0.0

                            StyledRect {
                                anchors.fill: parent
                                radius: Styling.radius(2)
                                variant: "internalbg"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    anchors.topMargin: 9
                                    anchors.bottomMargin: 10
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Item {
                                            implicitWidth: 16
                                            implicitHeight: 16
                                            Layout.alignment: Qt.AlignVCenter

                                            Text {
                                                anchors.centerIn: parent
                                                renderType: Text.NativeRendering
                                                font.hintingPreference: Font.PreferFullHinting
                                                text: appDelegate.isAppMuted ? Icons.micSlash : Icons.mic
                                                font.family: Icons.font
                                                font.pixelSize: 13
                                                color: appDelegate.isAppMuted ? Colors.red : Colors.overBackground
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (appDelegate.modelData?.audio) {
                                                        appDelegate.modelData.audio.muted = !appDelegate.modelData.audio.muted;
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            renderType: Text.NativeRendering
                                            font.hintingPreference: Font.PreferFullHinting
                                            text: Audio.appNodeDisplayName(appDelegate.modelData)
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.bold: true
                                            color: Colors.overBackground
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            renderType: Text.NativeRendering
                                            font.hintingPreference: Font.PreferFullHinting
                                            text: Math.round(appDelegate.appVolume * 100) + "%"
                                            font.family: Config.theme.monoFont
                                            font.pixelSize: Styling.fontSize(-2)
                                            color: Colors.overSurfaceVariant
                                        }
                                    }

                                    StyledSlider {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 16
                                        Layout.leftMargin: 2
                                        Layout.rightMargin: 2
                                        value: appDelegate.appVolume
                                        progressColor: appDelegate.isAppMuted ? Colors.outlineVariant : Colors.primary
                                        onValueChanged: {
                                            if (appDelegate.modelData?.audio && Math.abs(value - appDelegate.appVolume) > 0.01) {
                                                appDelegate.modelData.audio.volume = value;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.appNodes.length === 0
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: "No applications using microphone"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                        opacity: 0.6
                        Layout.topMargin: 2
                        Layout.bottomMargin: 4
                    }
                }
            }
        }
    }
}
