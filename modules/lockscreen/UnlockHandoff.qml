pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.services

// Brief post-unlock cover using the same pre-lock freeze frame.
// Session lock surfaces are destroyed instantly on unlock; this overlay
// bridges that compositor handoff so the desktop does not flash black.
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Transparent window; fade is on the content item (PanelWindow has no opacity).
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nonchalant:unlock-handoff"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Stay mounted so the freeze texture is ready; only the surface visibility
    // is toggled around unlock.
    visible: GlobalStates.lockscreenHandoff

    readonly property string freezeSource: LockscreenService.freezeSourceFor(modelData.name)

    Item {
        anchors.fill: parent
        opacity: GlobalStates.lockscreenHandoffOpacity

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
            smooth: true
            source: root.freezeSource
            visible: status === Image.Ready
        }
    }
}
