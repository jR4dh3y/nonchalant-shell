pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme

StyledRect {
    id: root

    required property int buttonSize
    required property real maximumHeight
    signal activated()

    readonly property int inset: Math.max(2, Math.round(buttonSize / 9))
    readonly property string title: MprisController.trackTitle || "Media"

    objectName: "verticalMediaWidget"
    implicitWidth: buttonSize
    implicitHeight: Math.min(Math.max(buttonSize, maximumHeight),
        Math.max(buttonSize, trackTitle.implicitWidth + inset * 2))
    visible: MprisController.activePlayer !== null
    variant: "common"
    radius: Styling.radius(-4)
    scale: mediaMouse.pressed ? 0.96 : 1
    Accessible.role: Accessible.Button
    Accessible.name: root.title

    PressBehavior on scale {
        pressed: mediaMouse.pressed
    }

    HoverTint {
        hovered: mediaMouse.containsMouse
        pressed: mediaMouse.pressed
    }

    MouseArea {
        id: mediaMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                MprisController.togglePlaying();
            else
                root.activated();
        }
        onWheel: wheel => {
            const delta = wheel.angleDelta.y || wheel.angleDelta.x;
            if (delta > 0)
                MprisController.previous();
            else if (delta < 0)
                MprisController.next();
            wheel.accepted = true;
        }
    }

    FluidTextProgress {
        id: trackTitle
        objectName: "verticalMediaTitle"
        anchors.centerIn: parent
        width: root.height - root.inset * 2
        height: root.width - root.inset * 2
        rotation: -90
        text: root.title
        pixelSize: Styling.fontSize(-1)
        horizontalAlignment: Text.AlignHCenter
        progress: MprisController.progress
        isPlaying: MprisController.isPlaying
    }

    StyledToolTip {
        x: root.width + root.inset * 2
        y: (root.height - height) / 2
        show: mediaMouse.containsMouse
        tooltipText: root.title
        description: MprisController.trackArtists
    }
}
