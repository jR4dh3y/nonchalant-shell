import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.globals
import qs.modules.services

// Lock transition on a normal overlay layer, composited by niri over the live
// desktop. niri shows nothing but the lock surface while locked, so the fade
// cannot happen inside the lock itself:
// - Lock: the curtain fades the backdrop in over the desktop, then the session
//   lock engages. Its first frame is the same backdrop, so the switch is
//   invisible.
// - Unlock: the curtain stays opaque (unseen) for the whole lock. Releasing the
//   lock reveals it over the real desktop, and it fades out.
// No screenshot is involved in either direction.
PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nonchalant:lockcurtain"
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool shown: GlobalStates.lockCurtainShown

    // Swallow input while fading in so keys and clicks cannot reach a window
    // that is about to be locked. On the way out, input passes straight through.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        item: root.shown ? inputBlocker : null
    }

    // Mapped only around a lock, so it stacks above the rest of the shell.
    visible: shown || backdrop.opacity > 0

    LockBackdrop {
        id: backdrop
        anchors.fill: parent
        screenName: root.targetScreen.name
        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            enabled: LockscreenService.curtainFadeMs > 0
            NumberAnimation {
                duration: LockscreenService.curtainFadeMs
                easing.type: Easing.InOutCubic
            }
        }
    }

    MouseArea {
        id: inputBlocker
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
    }
}
