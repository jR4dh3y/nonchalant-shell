// Desktop context menu from Impasto (andreumassanet/impasto), revision
// 6d759aa3fe16e3b40641beeb9b24e3c4afcfeefe. GPL-3.0 source; Niri actions adapted.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.services
import qs.modules.services.desktop as Data
import qs.modules.widgets.desktop.impasto.theme as Impasto
import qs.modules.widgets.desktop.impasto.components as ImpastoUI

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    required property Item board
    readonly property string screenName: root.targetScreen?.name ?? ""
    readonly property var menu: DesktopWidgetService.menu
    readonly property var row: root.menu?.key ? DesktopWidgetService.entryOf(root.menu.key) : null
    readonly property bool onNote: root.row !== null && root.row.id === "notes"
    readonly property var insets: DesktopWidgetService.insetsFor(root.screenName)

    screen: root.targetScreen
    visible: root.menu !== null && root.menu.screen === root.screenName
        && !DesktopWidgetService.editing
    color: "transparent"
    anchors { top: true; right: true; bottom: true; left: true }
    WlrLayershell.namespace: "nonchalant:desktop-menu"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    mask: Region { width: root.width; height: root.height }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: DesktopWidgetService.closeMenu()
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: DesktopWidgetService.closeMenu()
    }

    ImpastoUI.PopMenu {
        x: root.insets.left + (root.menu
            ? Math.max(Impasto.Theme.desktopGutter, Math.min(
                root.board.width - Impasto.Theme.desktopGutter - width, root.menu.x)) : 0)
        y: root.insets.top + (root.menu
            ? Math.max(Impasto.Theme.desktopGutter, Math.min(
                root.board.height - Impasto.Theme.desktopGutter - height, root.menu.y)) : 0)

        rows: {
            if (!root.menu)
                return []
            if (root.menu.key === "") {
                return [
                    { id: "arrange", label: "Arrange widgets", icon: "󰆾", warn: false },
                    { id: "note", label: "New note", icon: "󰎞", warn: false },
                    { id: "wallpaper", label: "Wallpaper", icon: "󰸉", warn: false },
                    { id: "palette", label: "Palette", icon: "󰏘", warn: false },
                    { id: "settings", label: "Settings", icon: "󰒓", warn: false }
                ]
            }
            const rows = []
            if (root.onNote)
                rows.push({ id: "open", label: "Open", icon: "󰏫", warn: false })
            rows.push({ id: "edit", label: "Edit", icon: "󰆾", warn: false })
            rows.push({ id: "remove", label: "Remove", icon: "󰆴", warn: true })
            return rows
        }

        onChosen: id => {
            const menu = root.menu
            const row = root.row
            DesktopWidgetService.closeMenu()
            switch (id) {
            case "arrange":
                DesktopWidgetService.openEditor(root.screenName)
                break
            case "note": {
                const key = Data.NotesService.create()
                DesktopWidgetService.openDetail("notes", { id: "notes", screen: root.screenName, note: key })
                break
            }
            case "wallpaper":
                GlobalStates.openSettings("theme", "general")
                break
            case "palette":
                GlobalStates.openSettings("theme", "colors")
                break
            case "settings":
                GlobalStates.openSettings()
                break
            case "open": {
                const note = Data.NotesService.noteFor(row)
                DesktopWidgetService.openDetail("notes", Object.assign({}, row, { note: note?.key ?? "" }))
                break
            }
            case "edit":
                if (DesktopWidgetService.openEditor(root.screenName))
                    DesktopWidgetService.selected = menu.key
                break
            case "remove":
                DesktopWidgetService.remove(menu.key)
                break
            }
        }
    }
}
