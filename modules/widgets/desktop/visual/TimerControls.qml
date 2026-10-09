pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services.desktop
import qs.modules.theme

Item {
    id: root

    property real buttonSize: Styling.fontSize(6)
    property real spacing: Styling.fontSize(-3)
    property color foregroundColor: Colors.overBackground
    property color accentColor: Colors.primary
    property color accentTextColor: Colors.overPrimary
    property color surfaceColor: Colors.surfaceContainerHigh

    readonly property real actionWidth: Math.max(root.buttonSize * 2.6, Styling.fontSize(14))
    implicitWidth: root.actionWidth + root.spacing + root.buttonSize
    implicitHeight: root.buttonSize
    width: root.implicitWidth
    height: root.implicitHeight

    Row {
        anchors.fill: parent
        spacing: root.spacing

        FaceActionButton {
            controlWidth: root.actionWidth
            controlHeight: root.buttonSize
            iconOnly: false
            text: !TimerService.running ? "5 min" : TimerService.paused ? "Resume" : "Hold"
            accessibleName: !TimerService.running ? "Start five minute timer"
                : TimerService.paused ? "Resume timer" : "Pause timer"
            foregroundColor: root.accentTextColor
            backgroundColor: root.accentColor
            onClicked: {
                if (!TimerService.running)
                    TimerService.start(5 * 60 * 1000, "")
                else
                    TimerService.toggle()
            }
        }

        FaceActionButton {
            controlWidth: root.buttonSize
            controlHeight: root.buttonSize
            text: Icons.cancel
            accessibleName: "Cancel timer"
            foregroundColor: root.foregroundColor
            backgroundColor: root.surfaceColor
            enabled: TimerService.running
            opacity: enabled ? 1 : 0.45
            onClicked: TimerService.cancel()
        }
    }
}
