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
    property string barPosition: "top"

    property bool sidebarEnabled: false
    property bool sidebarPinned: false
    property int sidebarWidth: 0
    property string sidebarPosition: "right"

    readonly property int sidebarMargin: 4

    readonly property string barStyle: Config.bar?.style ?? "default"
    // Only a visible, space-taking bar reserves an edge. Unpinned island and
    // pills layouts float over content and reserve nothing.
    readonly property bool barReserves: Config.barReady && root.barEnabled
        && ((root.barStyle !== "island" && root.barStyle !== "pills") || (Config.bar?.pinned ?? false))
    readonly property int barZone: root.barSize + root.barOuterMargin

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

        exclusiveZone: root.barReserves && root.barStyle !== "left" && root.barPosition === "top"
            ? root.barZone
            : 0
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        screen: root.screen
        visible: true
        implicitHeight: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            left: true
            right: true
            bottom: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "nonchalant:reservation:bottom"

        exclusiveZone: root.barReserves && root.barStyle !== "left" && root.barPosition === "bottom"
            ? root.barZone
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

        // The left sidebar begins beside the dock, so reserve their combined
        // footprint in one exclusive zone.
        exclusiveZone: Math.max(
            root.barReserves && root.barStyle === "left" ? root.barZone : 0,
            root.sidebarEnabled && root.sidebarPinned && root.sidebarPosition === "left"
                ? root.sidebarWidth + root.sidebarMargin
                    + (root.barReserves && root.barStyle === "left" ? root.barZone : 0)
                : 0)
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
