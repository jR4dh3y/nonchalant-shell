pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    required property int controlSize
    property string selectedMode: ""
    readonly property bool soundMuted: Audio.sink?.audio?.muted ?? false
    readonly property bool micMuted: Audio.source?.audio?.muted ?? false
    readonly property real soundLevel: Math.max(0, Math.min(1, Audio.value))
    readonly property real micLevel: Math.max(0, Math.min(1, Audio.source?.audio?.volume ?? 0))
    signal menuRequested(string mode)

    implicitWidth: controlSize
    implicitHeight: controlSize
    scale: soundMouse.pressed || micMouse.pressed ? 0.94 : 1
    PressBehavior on scale { pressed: soundMouse.pressed || micMouse.pressed }

    BarRadialMeter {
        anchors.fill: parent
        controlSize: root.controlSize
        foregroundColor: soundHalf.foregroundColor
        value: root.soundMuted ? 0 : root.soundLevel
        startAngle: 188
        spanAngle: 164
    }
    BarRadialMeter {
        anchors.fill: parent
        controlSize: root.controlSize
        foregroundColor: micHalf.foregroundColor
        value: root.micMuted ? 0 : root.micLevel
        startAngle: 8
        spanAngle: 164
    }

    component AudioHalf: Item {
        id: half
        required property bool microphone
        readonly property bool muted: microphone ? root.micMuted : root.soundMuted
        readonly property real level: microphone ? root.micLevel : root.soundLevel
        readonly property string title: microphone ? "Microphone" : "Volume"
        readonly property string mode: microphone ? "mic" : "sound"
        readonly property bool selected: root.selectedMode === mode
        readonly property color foregroundColor: selected ? halfSurface.item : Colors.overBackground
        readonly property alias mouse: halfMouse
        // Keep each half's fill and icon beneath the shared radial meters.
        z: -1
        width: root.width
        height: root.height / 2
        Accessible.role: Accessible.Button
        Accessible.name: title + (muted ? " muted" : " " + Math.round(level * 100) + "%")
        Accessible.onPressAction: root.menuRequested(mode)

        Item {
            anchors.fill: parent
            clip: true

            StyledRect {
                id: halfSurface
                width: root.width
                height: root.height
                y: half.microphone ? -root.height / 2 : 0
                radius: width / 2
                variant: half.selected ? "focus" : "pane"
                enableBorder: false
                enableShadow: false
                HoverTint {
                    hovered: halfMouse.containsMouse
                    pressed: halfMouse.pressed
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: parent.microphone ? -root.height * 0.07 : root.height * 0.07
            text: parent.microphone ? (root.micMuted ? Icons.micSlash : Icons.mic)
                : (root.soundMuted ? Icons.speakerSlash : Icons.speakerHigh)
            font.family: Icons.font
            font.pixelSize: root.controlSize * 0.29
            color: parent.muted ? Colors.red : half.foregroundColor
        }

        MouseArea {
            id: halfMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => {
                if (event.button === Qt.RightButton) {
                    if (parent.microphone) Audio.toggleMicMute();
                    else Audio.toggleMute();
                } else {
                    root.menuRequested(parent.mode);
                }
            }
            onWheel: event => {
                const delta = event.angleDelta.y || event.angleDelta.x;
                if (delta === 0) return;
                const value = Math.max(0, Math.min(1, parent.level + (delta > 0 ? 0.05 : -0.05)));
                if (parent.microphone) Audio.setMicVolume(value);
                else Audio.setVolume(value);
                event.accepted = true;
            }
        }
        StyledToolTip {
            x: root.width + root.controlSize / 5
            show: halfMouse.containsMouse
            tooltipText: parent.Accessible.name
            description: "Click for " + parent.title.toLowerCase() + " · Right-click to mute · Scroll to adjust"
        }
    }

    AudioHalf {
        id: soundHalf
        objectName: "verticalSoundControl"
        microphone: false
    }
    AudioHalf {
        id: micHalf
        objectName: "verticalMicControl"
        y: root.height / 2
        microphone: true
    }
    readonly property MouseArea soundMouse: soundHalf.mouse
    readonly property MouseArea micMouse: micHalf.mouse
}
