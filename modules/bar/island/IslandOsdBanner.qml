pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services

Item {
    id: root

    property Item bar: null
    property string indicator: "volume" // "volume" | "mic" | "brightness"
    property real value: 0.0
    property bool muted: false

    implicitWidth: 300
    implicitHeight: 48

    function adjustValue(delta: real) {
        if (root.indicator === "volume") {
            const audioDevice = Audio.sink?.audio;
            if (audioDevice) {
                const currentVal = audioDevice.volume ?? root.value;
                const newVal = Math.max(0.0, Math.min(1.0, currentVal + delta));
                if (delta > 0 && audioDevice.muted) {
                    audioDevice.muted = false;
                }
                Audio.setVolume(newVal);
                if (root.bar) {
                    root.bar.triggerOsd("volume", newVal, audioDevice.muted ?? false);
                }
            }
        } else if (root.indicator === "brightness") {
            const currentMonitor = (root.bar?.screen)
                ? Brightness.getMonitorForScreen(root.bar.screen)
                : (Brightness.monitors.length > 0 ? Brightness.monitors[0] : null);
            const mon = currentMonitor ?? (Brightness.monitors.length > 0 ? Brightness.monitors[0] : null);
            const currentVal = mon?.brightness ?? root.value;
            const newVal = Math.max(0.05, Math.min(1.0, currentVal + delta));
            if (Brightness.syncBrightness) {
                for (let i = 0; i < Brightness.monitors.length; i++) {
                    const m = Brightness.monitors[i];
                    if (m?.ready)
                        m.setBrightness(newVal);
                }
            } else if (mon?.ready) {
                mon.setBrightness(newVal);
            }
            if (root.bar) {
                root.bar.triggerOsd("brightness", newVal, false);
            }
        } else if (root.indicator === "mic") {
            const micDevice = Audio.source?.audio;
            if (micDevice) {
                const currentVal = micDevice.volume ?? root.value;
                const newVal = Math.max(0.0, Math.min(1.0, currentVal + delta));
                if (delta > 0 && micDevice.muted) {
                    micDevice.muted = false;
                }
                Audio.setMicVolume(newVal);
                if (root.bar) {
                    root.bar.triggerOsd("mic", newVal, micDevice.muted ?? false);
                }
            }
        }
    }

    function adjustToExplicitValue(newVal: real) {
        if (root.indicator === "volume") {
            const audioDevice = Audio.sink?.audio;
            if (audioDevice) {
                Audio.setVolume(newVal);
                if (root.bar) {
                    root.bar.triggerOsd("volume", newVal, audioDevice.muted ?? false);
                }
            }
        } else if (root.indicator === "brightness") {
            const currentMonitor = (root.bar?.screen)
                ? Brightness.getMonitorForScreen(root.bar.screen)
                : (Brightness.monitors.length > 0 ? Brightness.monitors[0] : null);
            const mon = currentMonitor ?? (Brightness.monitors.length > 0 ? Brightness.monitors[0] : null);
            if (Brightness.syncBrightness) {
                for (let i = 0; i < Brightness.monitors.length; i++) {
                    const m = Brightness.monitors[i];
                    if (m?.ready)
                        m.setBrightness(newVal);
                }
            } else if (mon?.ready) {
                mon.setBrightness(newVal);
            }
            if (root.bar) {
                root.bar.triggerOsd("brightness", newVal, false);
            }
        } else if (root.indicator === "mic") {
            const micDevice = Audio.source?.audio;
            if (micDevice) {
                Audio.setMicVolume(newVal);
                if (root.bar) {
                    root.bar.triggerOsd("mic", newVal, micDevice.muted ?? false);
                }
            }
        }
    }

    WheelHandler {
        id: bannerWheelHandler
        target: root
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.angleDelta.y === 0)
                return;
            const delta = event.angleDelta.y > 0 ? 0.05 : -0.05;
            root.adjustValue(delta);
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 12

        // Left Icon (clickable for mute/unmute)
        Item {
            id: iconContainer
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            scale: iconMouse.pressed ? 0.90 : 1.0

            Behavior on scale {
                enabled: (Config.animDuration ?? 0) > 0
                NumberAnimation {
                    duration: iconMouse.pressed ? 80 : 250
                    easing.type: iconMouse.pressed ? Easing.OutQuad : Easing.OutBack
                    easing.overshoot: 1.4
                }
            }

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

            MouseArea {
                id: iconMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: (root.indicator === "volume" || root.indicator === "mic") ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.indicator === "volume" && Audio.sink?.audio) {
                        Audio.sink.audio.muted = !Audio.sink.audio.muted;
                        if (root.bar) {
                            root.bar.triggerOsd("volume", Audio.sink.audio.volume, Audio.sink.audio.muted);
                        }
                    } else if (root.indicator === "mic" && Audio.source?.audio) {
                        Audio.source.audio.muted = !Audio.source.audio.muted;
                        if (root.bar) {
                            root.bar.triggerOsd("mic", Audio.source.audio.volume, Audio.source.audio.muted);
                        }
                    }
                }
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
                scroll: false
                thickness: 3
                handleSpacing: 0
                progressColor: root.muted ? Colors.outline : Styling.srItem("overprimary")
                backgroundColor: Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.2)
                onValueChanged: {
                    if (isDragging) {
                        root.adjustToExplicitValue(value);
                    }
                }
            }
        }
    }
}
