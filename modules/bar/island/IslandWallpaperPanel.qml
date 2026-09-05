pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

Item {
    id: root

    implicitWidth: 480
    implicitHeight: 460

    signal backRequested()

    property ShellScreen screen: null
    property int selectedScreenIndex: 0
    readonly property var allScreens: Quickshell.screens
    readonly property ShellScreen targetScreen: (allScreens && allScreens.length > 0) ? allScreens[selectedScreenIndex % allScreens.length] : root.screen
    readonly property string currentScreenName: targetScreen?.name ?? (root.screen?.name ?? (NiriService.focusedMonitor ? NiriService.focusedMonitor.name : ""))

    property string searchText: ""

    readonly property string currentWallpaper: {
        if (!GlobalStates.wallpaperManager) return "";
        let perScreen = GlobalStates.wallpaperManager.perScreenWallpapers || {};
        if (root.currentScreenName !== "" && perScreen[root.currentScreenName] !== undefined) {
            return perScreen[root.currentScreenName];
        }
        return GlobalStates.wallpaperManager.currentWallpaper || "";
    }

    readonly property var filteredWallpapers: {
        if (!GlobalStates.wallpaperManager)
            return [];
        let wallpapers = GlobalStates.wallpaperManager.wallpaperPaths || [];
        if (root.searchText.length > 0) {
            const query = root.searchText.toLowerCase();
            wallpapers = wallpapers.filter(path => {
                const name = path.split("/").pop().toLowerCase();
                return name.includes(query);
            });
        }
        return wallpapers;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ═══════════════════════════════════════════════════════════════
        // UNIFIED HEADER: Back + Title + Screen Pill + Spacer + Search
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 8

            // Back button
            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: backMouse.containsMouse ? "focus" : "common"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowLeft
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: Colors.overBackground
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }

            // Title
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Wallpapers"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
            }

            // Screen Pill (clickable to switch screen if multi-monitor)
            StyledRect {
                implicitWidth: screenRow.implicitWidth + 14
                implicitHeight: 22
                radius: 11
                variant: (root.allScreens && root.allScreens.length > 1 && screenMouse.containsMouse) ? "focus" : "common"

                RowLayout {
                    id: screenRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        id: screenText
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: root.currentScreenName || "Display"
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-3)
                        font.bold: true
                        color: Colors.overBackground
                    }

                    Text {
                        visible: root.allScreens && root.allScreens.length > 1
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.caretDown
                        font.family: Icons.font
                        font.pixelSize: 10
                        color: Colors.overSurfaceVariant
                    }
                }

                MouseArea {
                    id: screenMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: (root.allScreens && root.allScreens.length > 1) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.allScreens && root.allScreens.length > 1) {
                            root.selectedScreenIndex = (root.selectedScreenIndex + 1) % root.allScreens.length;
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Compact native search input with clear button
            StyledRect {
                implicitWidth: 140
                implicitHeight: 28
                radius: Styling.radius(1)
                variant: searchInput.activeFocus ? "focus" : "internalbg"
                enableBorder: searchInput.activeFocus

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.magnifyingGlass
                        font.family: Icons.font
                        font.pixelSize: 13
                        color: Colors.overSurfaceVariant
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "Search..."
                        placeholderTextColor: Colors.outline
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.hintingPreference: Font.PreferFullHinting
                        color: Colors.overBackground
                        background: null
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: root.searchText = text
                    }

                    Text {
                        visible: searchInput.text.length > 0
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.cancel
                        font.family: Icons.font
                        font.pixelSize: 12
                        color: clearSearchMouse.containsMouse ? Colors.overBackground : Colors.overSurfaceVariant

                        MouseArea {
                            id: clearSearchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                root.searchText = "";
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // WALLPAPERS GRID (Balanced 4-column edge-to-edge grid)
        // ═══════════════════════════════════════════════════════════════
        StyledRect {
            id: gridContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Styling.radius(2)
            variant: "internalbg"
            clip: true

            readonly property int columns: 3
            readonly property real itemMargin: 6

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: root.filteredWallpapers.length === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.image
                    font.family: Icons.font
                    font.pixelSize: 32
                    color: Colors.overSurfaceVariant
                    opacity: 0.5
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: "No wallpapers found"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overSurfaceVariant
                }
            }

            GridView {
                id: wallGrid
                anchors.fill: parent
                anchors.margins: gridContainer.itemMargin
                cellWidth: Math.floor(width / gridContainer.columns)
                readonly property real itemW: cellWidth - gridContainer.itemMargin
                readonly property real itemH: Math.round(itemW * 0.625)
                cellHeight: itemH + gridContainer.itemMargin
                flow: GridView.FlowLeftToRight
                boundsBehavior: Flickable.StopAtBounds
                model: root.filteredWallpapers
                clip: true
                visible: root.filteredWallpapers.length > 0

                delegate: Item {
                    id: delegateItem
                    required property int index
                    required property string modelData

                    readonly property bool isCurrent: root.currentWallpaper === delegateItem.modelData
                    property bool isHovered: false

                    width: wallGrid.itemW
                    height: wallGrid.itemH

                    StyledRect {
                        anchors.fill: parent
                        radius: Styling.radius(2)
                        variant: delegateItem.isCurrent ? "primary" : "common"
                        enableBorder: delegateItem.isCurrent
                        clip: true

                        scale: delegateItem.isHovered ? 0.96 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        // Thumbnail image
                        Image {
                            anchors.fill: parent
                            mipmap: true
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            cache: false
                            sourceSize.width: wallGrid.itemW
                            sourceSize.height: wallGrid.itemH
                            source: {
                                if (!GlobalStates.wallpaperManager) return "";
                                const thumb = GlobalStates.wallpaperManager.getThumbnailPath(delegateItem.modelData);
                                const ver = GlobalStates.wallpaperManager.thumbnailsVersion;
                                return "file://" + thumb + "?v=" + ver;
                            }
                        }

                        // Current badge indicator
                        StyledRect {
                            visible: delegateItem.isCurrent
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 18
                            variant: "primary"
                            radius: 0

                            Text {
                                anchors.centerIn: parent
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: "CURRENT"
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-4)
                                font.bold: true
                                color: Colors.overPrimary
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: delegateItem.isHovered = true
                            onExited: delegateItem.isHovered = false
                            onClicked: {
                                if (GlobalStates.wallpaperManager) {
                                    if (root.currentScreenName !== "") {
                                        GlobalStates.wallpaperManager.setWallpaper(delegateItem.modelData, root.currentScreenName);
                                    } else {
                                        GlobalStates.wallpaperManager.setWallpaper(delegateItem.modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
