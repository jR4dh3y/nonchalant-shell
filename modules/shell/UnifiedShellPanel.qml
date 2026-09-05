import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.bar
import qs.modules.services
import qs.modules.globals
import qs.modules.components
import qs.modules.widgets.launcher
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
        if (runMenu.open || barContent.islandActive)
            return WlrKeyboardFocus.Exclusive;
        // Bar popups are child surfaces of this panel. The parent layer must
        // request keyboard focus or input continues to the client underneath.
        if (barContent.timerInputActive || barContent.dashboardInputActive)
            return WlrKeyboardFocus.Exclusive;
        // Request compositor ownership before focusing the assistant input.
        // Requiring activeFocus here is circular: the field cannot gain focus
        // while keyboard events still belong to the client underneath.
        if (assistantSidebar && assistantSidebar.active
                && assistantSidebar.wantsFocus)
            return WlrKeyboardFocus.Exclusive;
        return WlrKeyboardFocus.None;
    }
    WlrLayershell.namespace: "nonchalant"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    // Assistant stays open without eating the whole screen — only its hitbox
    // receives clicks (see mask regions). Run menu / grabs still go full-screen.
    readonly property bool needsFullScreenInput: runMenu.open || barContent.dashboardInputActive || barContent.islandActive || FocusGrabManager.hasActiveGrab

    readonly property bool barEnabled: {
        if (!Config.barReady) return false;
        const list = Config.bar.screenList;
        return (!list || list.length === 0 || list.indexOf(targetScreen.name) !== -1);
    }

    readonly property alias barTargetHeight: barContent.barTargetHeight
    readonly property alias barOuterMargin: barContent.baseOuterMargin
    readonly property alias totalBarHeight: barContent.totalBarHeight
    readonly property string barPosition: Config.bar?.position ?? "top"
    readonly property Item assistantSidebar: assistantSidebarLoader.item


    Component.onCompleted: {
        Visibilities.registerBarPanel(screen.name, unifiedPanel);
    }

    Component.onDestruction: {
        Visibilities.unregisterBarPanel(screen.name);
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
                item: barContent.dashboardHitbox
            },
            Region {
                item: runMenu.hitbox
            },
            Region {
                item: toastStack.hitbox
            },
            Region {
                item: assistantSidebar
                    && (assistantSidebar.active || assistantSidebar.hitbox.visible)
                    ? assistantSidebar.hitbox : null
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

        onClicked: {
            FocusGrabManager.clearTopGrab();
            if (runMenu.open)
                Visibilities.setActiveModule("");
            if (barContent.dashboardInputActive)
                Visibilities.closeActiveBarPopup();
            if (barContent.islandActive)
                barContent.collapseIsland();
            if (assistantSidebar && assistantSidebar.active && assistantSidebar.wantsFocus) {
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
            panel: unifiedPanel
            z: 3
        }

        // Detached popup; it never joins the screen edge or reserves space.
        RunMenuHost {
            id: runMenu
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            barPanel: unifiedPanel
            z: 2
        }

        Loader {
            id: assistantSidebarLoader
            anchors.fill: parent
            active: GlobalStates.assistantAvailable
            z: 1

            sourceComponent: Component {
                AssistantSidebar {
                    targetScreen: unifiedPanel.targetScreen

                    anchors.topMargin: unifiedPanel.barEnabled
                        && unifiedPanel.barPosition === "top"
                        ? unifiedPanel.barTargetHeight + unifiedPanel.barOuterMargin
                        : 0
                    anchors.bottomMargin: unifiedPanel.barEnabled
                        && unifiedPanel.barPosition === "bottom"
                        ? unifiedPanel.barTargetHeight + unifiedPanel.barOuterMargin
                        : 0
                }
            }
        }
    }
}
