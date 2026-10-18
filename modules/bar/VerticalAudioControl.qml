pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    required property int controlSize
    property string selectedMode: ""
    readonly property bool selected: root.selectedMode === "sound" || root.selectedMode === "mic"
    readonly property bool soundMuted: Audio.sink?.audio?.muted ?? false
    readonly property bool micMuted: Audio.source?.audio?.muted ?? false
    readonly property real soundLevel: Math.max(0, Math.min(1, Audio.value))
    readonly property real micLevel: Math.max(0, Math.min(1, Audio.source?.audio?.volume ?? 0))
    readonly property color foregroundColor: root.selected ? surface.item : Colors.overBackground
    signal menuRequested(string mode)

    implicitWidth: controlSize
    implicitHeight: controlSize
    scale: soundMouse.pressed || micMouse.pressed ? 0.94 : 1
    PressBehavior on scale { pressed: soundMouse.pressed || micMouse.pressed }

    StyledRect {
        id: surface
        anchors.fill: parent
        variant: root.selected ? "focus" : "pane"
        radius: width / 2
        enableBorder: false
        enableShadow: false
        HoverTint {
            hovered: soundMouse.containsMouse || micMouse.containsMouse
            pressed: soundMouse.pressed || micMouse.pressed
        }
    }

    BarRadialMeter {
        anchors.fill: parent
        controlSize: root.controlSize
        foregroundColor: root.foregroundColor
        value: root.soundMuted ? 0 : root.soundLevel
        startAngle: 188
        spanAngle: 164
    }
    BarRadialMeter {
        anchors.fill: parent
        controlSize: root.controlSize
        foregroundColor: root.foregroundColor
        value: root.micMuted ? 0 : root.micLevel
        startAngle: 8
        spanAngle: 164
    }

    component AudioHalf: Item {
        required property bool microphone
        readonly property bool muted: microphone ? root.micMuted : root.soundMuted
        readonly property real level: microphone ? root.micLevel : root.soundLevel
        readonly property string title: microphone ? "Microphone" : "Volume"
        readonly property string mode: microphone ? "mic" : "sound"
        readonly property alias mouse: halfMouse
        width: root.width
        height: root.height / 2
        Accessible.role: Accessible.Button
        Accessible.name: title + (muted ? " muted" : " " + Math.round(level * 100) + "%")
        Accessible.onPressAction: root.menuRequested(mode)

        StyledText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: parent.microphone ? -root.height * 0.07 : root.height * 0.07
            text: parent.microphone ? (root.micMuted ? Icons.micSlash : Icons.mic)
                : (root.soundMuted ? Icons.speakerSlash : Icons.speakerHigh)
            font.family: Icons.font
            font.pixelSize: root.controlSize * 0.29
            color: parent.muted ? Colors.red : root.foregroundColor
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
