// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T O G G L E   S W I T C H                                              │
// │   an on/off control for a settings row                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import Quickshell
import qs.modules.widgets.desktop.impasto.theme

// The knob slides rather than jumping, so the switch shows which way it
// went. Disabled, it fades instead of turning grey.
Rectangle {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    opacity: root.enabled ? 1 : 0.45

    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

    color: root.checked ? Theme.accent : Theme.surfaceHoverIn(QsWindow.window)
    border.color: root.checked ? Theme.accent : Theme.borderIn(QsWindow.window)
    border.width: 1

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

    Rectangle {
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        width: root.height - 6
        height: width
        radius: width / 2
        color: root.checked ? Theme.accentText : Theme.textMuted

        Behavior on x {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggled(!root.checked)
    }
}
