import QtQuick
import qs.modules.theme

Item {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)

    property real radius: 18
    property bool active: true
    property bool interactive: true
    property real position: hover.hovered ? Math.max(0, Math.min(1, hover.point.position.x / Math.max(1, width))) : 0.5
    readonly property real strength: active ? (hover.hovered ? 0.45 : 0.18) : 0

    opacity: strength
    Behavior on opacity {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    Behavior on position {
        SmoothedAnimation {
            velocity: -1
            duration: 200
        }
    }

    HoverHandler {
        id: hover
        enabled: root.interactive && root.active
        blocking: false
    }

    // Ambient top-edge hairline
    Rectangle {
        x: root.radius
        y: 0
        width: Math.max(0, parent.width - root.radius * 2)
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: root.shellPalette.withAlpha(root.shellPalette.overBackground, 0.20) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Pointer-following accent highlight
    Rectangle {
        width: Math.max(0, Math.min(parent.width - root.radius * 2, parent.width * 0.38))
        height: 1.5
        x: root.radius + Math.max(0, parent.width - root.radius * 2 - width) * root.position
        y: 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: root.shellPalette.primary }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
