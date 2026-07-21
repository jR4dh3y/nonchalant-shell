import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.bar
import qs.modules.services
import qs.modules.components
import qs.modules.widgets.launcher
import qs.config

PanelWindow {
    id: unifiedPanel

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.keyboardFocus: {
        if (runMenu.open)
            return WlrKeyboardFocus.Exclusive;
        return WlrKeyboardFocus.None;
    }
    WlrLayershell.namespace: "nonchalant"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    readonly property bool needsFullScreenInput: runMenu.open || FocusGrabManager.hasActiveGrab

    readonly property bool barEnabled: {
        if (!Config.barReady) return false;
        const list = Config.bar.screenList;
        return (!list || list.length === 0 || list.indexOf(targetScreen.name) !== -1);
    }

    readonly property alias barPosition: barContent.barPosition
    readonly property alias barPinned: barContent.pinned
    readonly property alias barHoverActive: barContent.hoverActive
    readonly property alias barFullscreen: barContent.activeWindowFullscreen
    readonly property bool barReveal: barEnabled && barContent.reveal
    readonly property alias barTargetWidth: barContent.barTargetWidth
    readonly property alias barTargetHeight: barContent.barTargetHeight
    readonly property alias barOuterMargin: barContent.baseOuterMargin

    // Generic names for external compatibility (Visibilities expects these on the panel object)
    readonly property alias pinned: barContent.pinned
    readonly property bool reveal: barEnabled ? barContent.reveal : false
    readonly property alias hoverActive: barContent.hoverActive // Default hoverActive points to bar
    readonly property bool hasFullscreenWindow: barContent.activeWindowFullscreen

    Component.onCompleted: {
        Visibilities.registerBarPanel(screen.name, unifiedPanel);
        Visibilities.registerBar(screen.name, barContent);
    }

    Component.onDestruction: {
        Visibilities.unregisterBarPanel(screen.name);
        Visibilities.unregisterBar(screen.name);
    }

    // Full-screen mask item (used when modules/popups are open)
    Item {
        id: fullScreenMask
        anchors.fill: parent
    }

    // Capture the full screen only while the run menu or a bar popup is open.
    mask: Region {
        // Full-screen capture when any module/popup is open
        item: unifiedPanel.needsFullScreenInput ? fullScreenMask : null
        regions: [
            Region {
                item: barContent.visible ? barContent.barHitbox : null
            },
            Region {
                item: runMenu.hitbox
            }
        ]
    }

    // Close the run menu when its focus grab is cleared.
    FocusGrab {
        id: focusGrab
        windows: [unifiedPanel]
        active: runMenu.open

        onCleared: {
            Visibilities.setActiveModule("");
        }
    }

    MouseArea {
        id: backdropArea
        anchors.fill: parent
        visible: unifiedPanel.needsFullScreenInput
        z: -1

        onClicked: FocusGrabManager.clearTopGrab()
    }

    Item {
        id: visualContent
        anchors.fill: parent

        BarContent {
            id: barContent
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            z: 1
            visible: unifiedPanel.barEnabled
        }

        // Detached popup; it never joins the screen edge or reserves space.
        RunMenuHost {
            id: runMenu
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            z: 2
        }
    }
}
