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

    implicitWidth: 480
    implicitHeight: 250

    signal backRequested()

    readonly property real volume: Audio.sink?.audio?.volume ?? 0.0
    readonly property bool isMuted: Audio.sink?.audio?.muted ?? false
    readonly property string activeSinkId: Audio.sink?.id ? String(Audio.sink.id) : ""

    readonly property var sinkNodes: {
        const nodes = Pipewire.nodes.values;
        if (!nodes)
            return [];
        return nodes.filter(node => node && node.isSink);
    }

    ColumnLayout {
        anchors.fill: parent
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
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Sound"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
            }

            Item { Layout.fillWidth: true }

            // Audio Format / Bitrate Badge (Sample rate & bit depth)
            StyledRect {
                visible: AudioFormat.connected
                implicitHeight: 26
                implicitWidth: fmtRow.implicitWidth + 16
                radius: 13
                variant: "internalbg"

                RowLayout {
                    id: fmtRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: AudioFormat.kindIcon
                        font.family: Icons.font
                        font.pixelSize: 13
                        color: Colors.primary
                    }

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: AudioFormat.formatSummary
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-2)
                        font.bold: true
                        color: Colors.overBackground
                    }
                }
            }
        }

        // Volume Slider row
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: root.isMuted ? Icons.speakerSlash : (root.volume > 0.5 ? Icons.speakerHigh : Icons.speakerLow)
                font.family: Icons.font
                font.pixelSize: 18
                color: Colors.overBackground
            }

            // Slider track
            StyledSlider {
                id: volSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                value: root.volume
                onValueChanged: {
                    if (Audio.sink?.audio && Math.abs(value - root.volume) > 0.01) {
                        Audio.sink.audio.volume = value;
                    }
                }
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: Math.round(root.volume * 100) + "%"
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: Colors.overBackground
            }
        }

        // Section header
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            text: "OUTPUT DEVICE"
            font.family: Config.theme.monoFont
            font.pixelSize: Styling.fontSize(-2)
            font.bold: true
            color: Colors.overSurfaceVariant
            Layout.topMargin: 4
        }

        // List of output sinks
        ListView {
            id: sinkList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.sinkNodes

            delegate: Item {
                id: delegateRoot
                required property PwNode modelData

                width: sinkList.width
                height: 38

                readonly property bool isCurrent: String(delegateRoot.modelData.id) === root.activeSinkId

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
                            text: Icons.speakerHigh
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: delegateRoot.isCurrent ? Colors.overPrimary : Colors.overBackground
                        }

                        Text {
                            Layout.fillWidth: true
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: delegateRoot.modelData.description || delegateRoot.modelData.name || "Output"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
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
                            Audio.setDefaultSink(delegateRoot.modelData);
                        }
                    }
                }
            }
        }
    }
}
