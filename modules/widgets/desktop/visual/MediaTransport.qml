pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    property bool showSkipButtons: true
    property real buttonSize: Styling.fontSize(6)
    property real spacing: Styling.fontSize(-3)
    property color foregroundColor: Colors.overBackground
    property color accentColor: Colors.primary
    property color accentTextColor: Colors.overPrimary
    property color surfaceColor: Colors.surfaceContainerHigh

    implicitWidth: root.buttonSize * (root.showSkipButtons ? 3 : 1)
        + root.spacing * (root.showSkipButtons ? 2 : 0)
    implicitHeight: root.buttonSize
    width: root.implicitWidth
    height: root.implicitHeight

    Row {
        anchors.fill: parent
        spacing: root.spacing

        FaceActionButton {
            visible: root.showSkipButtons
            controlWidth: root.buttonSize
            controlHeight: root.buttonSize
            text: Icons.previous
            accessibleName: "Previous track"
            foregroundColor: root.foregroundColor
            backgroundColor: root.surfaceColor
            enabled: MprisController.canGoPrevious
            opacity: enabled ? 1 : 0.45
            onClicked: MprisController.previous()
        }

        FaceActionButton {
            controlWidth: root.buttonSize
            controlHeight: root.buttonSize
            text: MprisController.isPlaying ? Icons.pause : Icons.play
            accessibleName: MprisController.isPlaying ? "Pause playback" : "Start playback"
            foregroundColor: root.accentTextColor
            backgroundColor: root.accentColor
            enabled: MprisController.canTogglePlaying
            opacity: enabled ? 1 : 0.45
            onClicked: MprisController.togglePlaying()
        }

        FaceActionButton {
            visible: root.showSkipButtons
            controlWidth: root.buttonSize
            controlHeight: root.buttonSize
            text: Icons.next
            accessibleName: "Next track"
            foregroundColor: root.foregroundColor
            backgroundColor: root.surfaceColor
            enabled: MprisController.canGoNext
            opacity: enabled ? 1 : 0.45
            onClicked: MprisController.next()
        }
    }
}
