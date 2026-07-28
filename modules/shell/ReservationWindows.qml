import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

Item {
    id: root

    required property ShellScreen screen

    property bool barEnabled: true
    property int barSize: 0
    property int barOuterMargin: 0

    property bool sidebarEnabled: false
    property bool sidebarPinned: false
    property int sidebarWidth: 0
    property string sidebarPosition: "right"

    readonly property int sidebarMargin: 4

    Item {
        id: noInputRegion
        width: 0
        height: 0
        visible: false
    }

    PanelWindow {
        screen: root.screen
        visible: true
        implicitHeight: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            left: true
            right: true
            top: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "nonchalant:reservation:top"

        exclusiveZone: Config.barReady && root.barEnabled
            ? root.barSize + root.barOuterMargin
            : 0
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        screen: root.screen
        visible: true
        implicitWidth: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "nonchalant:reservation:left"

        exclusiveZone: root.sidebarEnabled
            && root.sidebarPinned
            && root.sidebarPosition === "left"
            ? root.sidebarWidth + root.sidebarMargin
            : 0
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        screen: root.screen
        visible: true
        implicitWidth: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            top: true
            bottom: true
            right: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "nonchalant:reservation:right"

        exclusiveZone: root.sidebarEnabled
            && root.sidebarPinned
            && root.sidebarPosition === "right"
            ? root.sidebarWidth + root.sidebarMargin
            : 0
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }
}
