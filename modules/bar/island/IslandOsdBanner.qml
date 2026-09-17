pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services

Item {
    id: root

    property string indicator: "volume" // "volume" | "mic" | "brightness"
    property real value: 0.0
    property bool muted: false

    implicitWidth: 260
    implicitHeight: 48

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 12

        // Left Icon
        Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter

            DynamicSunIcon {
                anchors.centerIn: parent
                visible: root.indicator === "brightness"
                size: 20
                value: root.value
                color: Colors.overBackground
            }

            DynamicVolumeIcon {
                anchors.centerIn: parent
                visible: root.indicator === "volume"
                size: 20
                value: root.value
                muted: root.muted
                color: root.muted ? Colors.error : Colors.overBackground
            }

            Text {
                anchors.centerIn: parent
                visible: root.indicator === "mic"
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: root.muted ? Icons.micSlash : Icons.mic
                font.family: Icons.font
                font.pixelSize: 20
                color: root.muted ? Colors.error : Colors.overBackground
            }
        }

        // Center / Right Column: Label + Percent on Top, Slider Bar on Bottom
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: {
                        if (root.indicator === "volume")
                            return root.muted ? "Muted" : "Volume";
                        if (root.indicator === "mic")
                            return root.muted ? "Mic Muted" : "Microphone";
                        if (root.indicator === "brightness")
                            return "Brightness";
                        return "";
                    }
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.bold: true
                    color: Colors.overBackground
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Math.round(root.value * 100)
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-1)
                    font.bold: true
                    color: Colors.overBackground
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            StyledSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: 10
                value: root.value
                wavy: false
                enabled: false
                thickness: 3
                handleSpacing: 0
                progressColor: root.muted ? Colors.outline : Styling.srItem("overprimary")
                backgroundColor: Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.2)
            }
        }
    }
}
