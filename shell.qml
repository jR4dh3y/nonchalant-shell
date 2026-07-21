//@ pragma UseQApplication
//@ pragma ShellId nonchalant
//@ pragma DataDir $BASE/nonchalant
//@ pragma StateDir $BASE/nonchalant

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.services
import qs.modules.lockscreen
import qs.modules.globals
import qs.modules.shell
import qs.modules.shell.osd
import qs.modules.notifications
import qs.modules.widgets.dashboard.wallpapers
import qs.config

ShellRoot {
    id: root

    // Keep the inherited wallpaper owner: it also provides the wallpaper
    // manager used by the lockscreen.
    Variants {
        model: Quickshell.screens

        Loader {
            id: wallpaperLoader
            active: true
            required property ShellScreen modelData
            sourceComponent: Wallpaper {
                screen: wallpaperLoader.modelData
            }
        }
    }

    // The shell owns one panel per configured screen. Transient UI such as the
    // run menu is rendered inside this same panel instead of separate windows.
    Variants {
        model: Quickshell.screens

        Item {
            id: screenShellContainer
            required property ShellScreen modelData

            UnifiedShellPanel {
                id: unifiedPanel
                targetScreen: screenShellContainer.modelData
            }

            // Exclusive zone reservations
            ReservationWindows {
                screen: screenShellContainer.modelData

                // Bar status for reservations. Drop the exclusive zone while
                // niri overview is open so the bar leaves the desktop only.
                barEnabled: {
                    if (NiriService.overviewOpen)
                        return false;
                    const list = (Config.bar && Config.bar.screenList !== undefined ? Config.bar.screenList : []);
                    return (!list || list.length === 0 || list.indexOf(screen.name) !== -1);
                }
                barPosition: unifiedPanel.barPosition
                barPinned: unifiedPanel.pinned
                barSize: (unifiedPanel.barPosition === "left" || unifiedPanel.barPosition === "right") ? unifiedPanel.barTargetWidth : unifiedPanel.barTargetHeight
                barOuterMargin: unifiedPanel.barOuterMargin

                dockEnabled: false
                frameEnabled: false
                sidebarEnabled: false
            }

            // Volume / mic / brightness OSD for keyboard media keys
            OSD {
                targetScreen: screenShellContainer.modelData
            }
        }
    }

    // Secure WlSessionLock lockscreen
    WlSessionLock {
        id: sessionLock
        locked: GlobalStates.lockscreenVisible

        // Surface auto-created per screen
        LockScreen {}
    }

    // Post-unlock freeze bridge (one per screen). Covers the black flash
    // between session-lock teardown and the live desktop redraw.
    Variants {
        model: Quickshell.screens

        UnlockHandoff {}
    }

    // Transient notification toasts (history lives in the dashboard popup).
    NotificationPopup {}

    // Initialize only the services needed by the bar, run menu, and lockscreen.
    QtObject {
        id: serviceInitializer

        Component.onCompleted: {
            Qt.callLater(() => {
                let _ = IdleService.lockCmd;
                _ = GlobalShortcuts.appId;
                _ = LockscreenService.freezePathBase;
                // Keep compositor + OSD services hot for overview hide and media keys.
                _ = NiriService.overviewOpen;
                _ = Audio.value;
                _ = Brightness.monitors;
                // Own org.freedesktop.Notifications and load history early.
                _ = Notifications.appNameList;
            });
        }
    }
}
