pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.globals
import qs.modules.theme
import qs.modules.widgets.dashboard.wallpapers

ColumnLayout {
    id: root
    required property ShellScreen screen
    readonly property Wallpaper manager: GlobalStates.wallpaperManager
    readonly property list<string> paths: (manager?.wallpaperPaths ?? []).filter(path =>
        search.text === "" || path.split("/").pop().toLowerCase().includes(search.text.toLowerCase()))
    readonly property string selectedPath: manager?.perScreenWallpapers?.[screen.name] || manager?.currentWallpaper || ""
    spacing: Styling.fontSize(0) * 0.5
    DeckCard {
        objectName: "deckWallpaperHeader"
        Layout.fillWidth: true
        order: 0
        padding: Styling.fontSize(0) * 0.3
        RowLayout {
            Layout.fillWidth: true
            spacing: Styling.fontSize(0) * 0.3
            StyledText {
                Layout.leftMargin: Styling.fontSize(0) * 0.5
                text: Icons.magnifyingGlass
                font.family: Icons.font
                color: Colors.overSurfaceVariant
            }
            TextField {
                id: search
                objectName: "deckWallpaperSearch"
                Layout.fillWidth: true
                placeholderText: "Find a wallpaper…"
                placeholderTextColor: Colors.overSurfaceVariant
                Accessible.name: "Find a wallpaper"
                color: Colors.overBackground
                font.family: Config.theme.font
                background: null
            }
        }
    }
    DeckCard {
        objectName: "deckWallpaperBody"
        Layout.fillWidth: true
        Layout.fillHeight: true
        order: 1
        ScrollView {
            id: list
            objectName: "deckWallpaperList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ColumnLayout {
                width: list.availableWidth
                spacing: Styling.fontSize(0) * 0.6
                GridLayout {
                    objectName: "deckWallpaperGrid"
                    Layout.fillWidth: true
                    columns: Math.max(2, Math.floor(list.availableWidth / (Styling.fontSize(0) * 10)))
                    uniformCellWidths: true
                    columnSpacing: Styling.fontSize(0) * 0.4
                    rowSpacing: columnSpacing
                    Repeater {
                        model: root.paths
                        DeckAction {
                            required property string modelData
                            objectName: "deckWallpaper-" + modelData.split("/").pop()
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            kind: DeckAction.Tile
                            padding: Styling.fontSize(0) * 0.3
                            label: modelData.split("/").pop()
                            description: "Use " + label + " on " + (root.screen.name || "this display")
                            maximumLabelWidth: width
                            textElide: Text.ElideMiddle
                            imageSource: root.manager ? "file://" + (root.manager.getThumbnailPath(modelData) || modelData) : ""
                            selected: root.selectedPath === modelData
                            onClicked: root.manager?.setWallpaper(modelData, root.screen.name)
                        }
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.paths.length === 0
                    wrapMode: Text.WordWrap
                    text: !root.manager ? "Wallpaper service is unavailable." : search.text !== "" ? "No wallpapers match your search." : "No wallpapers found in your wallpaper folder."
                    color: Colors.overSurfaceVariant
                }
            }
        }
    }
}
