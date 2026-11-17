import QtQuick
import qs.modules.theme

// One left dock droplet that turns into a power action. The droplet's own
// control stays in place and fades out; the action grows out of the same
// circle. Without a mode, or before the mode reveals, the slot is just the
// droplet.
Item {
    id: root

    required property LeftPowerMode mode
    required property int actionIndex
    required property real restSize
    required property real outerRadius
    property real delay: 0
    // The wrapped droplet.
    default property alias content: face.data

    readonly property real t: mode ? Math.max(0, (mode.reveal - delay) / (1 - delay)) : 0
    readonly property bool powered: mode?.active ?? false

    implicitWidth: restSize
    implicitHeight: restSize

    Item {
        id: face
        anchors.fill: parent
        enabled: !root.powered
        opacity: Math.max(0, 1 - root.t * 2)
        visible: opacity > 0
        scale: 1 - 0.15 * Math.min(1, root.t)
    }

    // Under the fading droplet, so the shared circle never dims. The action
    // keeps its own press scale; the reveal scales this wrapper.
    Item {
        z: -1
        anchors.fill: parent
        visible: root.powered && root.t > 0
        enabled: root.mode?.open ?? false
        opacity: Math.min(1, root.t * 4)
        scale: 0.85 + 0.15 * root.t

        LeftPowerAction {
            key: root.mode?.actions[root.actionIndex] ?? ""
            label: root.mode?.labels[root.actionIndex] ?? ""
            glyph: root.mode?.glyphs[root.actionIndex] ?? ""
            restSize: root.restSize
            outerRadius: root.outerRadius
            detached: true
            selected: root.mode?.currentIndex === root.actionIndex
            armed: key !== "" && root.mode?.armedAction === key
            onEntered: {
                if (root.mode)
                    root.mode.currentIndex = root.actionIndex;
            }
            onActivated: root.mode?.choose(root.actionIndex)
        }
    }
}
