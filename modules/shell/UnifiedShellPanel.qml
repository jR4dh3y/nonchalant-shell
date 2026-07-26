import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.bar
import qs.modules.services
import qs.modules.globals
import qs.modules.components
import qs.modules.widgets.launcher
import qs.modules.widgets.projects
import qs.modules.widgets.powermenu
import qs.modules.notifications
import qs.modules.sidebar
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
        if (runMenu.open || projectPicker.open)
            return WlrKeyboardFocus.Exclusive;
        // Only take the keyboard while the assistant input is actively focused.
        // Keeping Exclusive + full-screen grab for the whole open sidebar locked
        // the desktop when a tool call hung (no way to click other apps).
        if (assistantSidebar.active && assistantSidebar.wantsFocus && assistantSidebar.hasActiveFocus)
            return WlrKeyboardFocus.Exclusive;
        return WlrKeyboardFocus.None;
    }
    WlrLayershell.namespace: "nonchalant"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    // Assistant stays open without eating the whole screen — only its hitbox
    // receives clicks (see mask regions). Run menu / grabs still go full-screen.
    readonly property bool needsFullScreenInput: runMenu.open || projectPicker.open || FocusGrabManager.hasActiveGrab

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
    // Toast stack must be in the mask or the full-screen transparent panel
    // swallows clicks meant for the X / dismiss controls.
    mask: Region {
        // Full-screen capture when any module/popup is open
        item: unifiedPanel.needsFullScreenInput ? fullScreenMask : null
        regions: [
            Region {
                item: barContent.visible ? barContent.barHitbox : null
            },
            Region {
                item: runMenu.hitbox
            },
            Region {
                item: projectPicker.hitbox
            },
            Region {
                item: toastStack.hitbox
            },
            Region {
                item: (assistantSidebar.active || assistantSidebar.hitbox.visible) ? assistantSidebar.hitbox : null
            }
        ]
    }

    // Close the run menu / project picker when its focus grab is cleared.
    FocusGrab {
        id: focusGrab
        windows: [unifiedPanel]
        active: runMenu.open || projectPicker.open

        onCleared: {
            Visibilities.setActiveModule("");
        }
    }

    MouseArea {
        id: backdropArea
        anchors.fill: parent
        visible: unifiedPanel.needsFullScreenInput
        z: -1

        onClicked: {
            FocusGrabManager.clearTopGrab();
            if (assistantSidebar.active && assistantSidebar.wantsFocus) {
                assistantSidebar.wantsFocus = false;
                // Defocus the text field so keyboard returns to the session.
                if (assistantSidebar.hasActiveFocus)
                    unifiedPanel.forceActiveFocus();
            }
        }
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

        // Notification toasts live on this panel so they share the bar's
        // input surface (separate layer windows were unclickable under niri).
        NotificationToastStack {
            id: toastStack
        }

        // Power menu host (no bar icon — Super+X / IPC only).
        PowerMenuHost {
            id: powerMenuHost
            bar: barContent
            panel: unifiedPanel
            z: 3
        }

        // Detached popup; it never joins the screen edge or reserves space.
        RunMenuHost {
            id: runMenu
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            z: 2
        }

        ProjectPickerHost {
            id: projectPicker
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            z: 2
        }

        AssistantSidebar {
            id: assistantSidebar
            targetScreen: unifiedPanel.targetScreen
            z: 1

            anchors.topMargin: {
                let margin = 0;
                if (unifiedPanel.barEnabled && unifiedPanel.barPosition === "top" && unifiedPanel.barPinned)
                    margin += unifiedPanel.barTargetHeight + unifiedPanel.barOuterMargin;
                return margin;
            }

            anchors.bottomMargin: {
                let margin = 0;
                if (unifiedPanel.barEnabled && unifiedPanel.barPosition === "bottom" && unifiedPanel.barPinned)
                    margin += unifiedPanel.barTargetHeight + unifiedPanel.barOuterMargin;
                return margin;
            }

            anchors.leftMargin: {
                let margin = 0;
                if (unifiedPanel.barEnabled && unifiedPanel.barPosition === "left" && unifiedPanel.barPinned)
                    margin += unifiedPanel.barTargetWidth + unifiedPanel.barOuterMargin;
                return margin;
            }

            anchors.rightMargin: {
                let margin = 0;
                if (unifiedPanel.barEnabled && unifiedPanel.barPosition === "right" && unifiedPanel.barPinned)
                    margin += unifiedPanel.barTargetWidth + unifiedPanel.barOuterMargin;
                return margin;
            }
        }
    }
}
