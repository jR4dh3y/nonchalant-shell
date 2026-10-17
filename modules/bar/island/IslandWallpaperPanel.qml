pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.widgets.dashboard.wallpapers
import qs.config

Item {
    id: root

    implicitWidth: 540
    implicitHeight: 520

    property bool compact: false
    property ShellScreen screen: null
    readonly property string currentScreenName: root.screen?.name ?? CompositorService.focusedMonitor?.name ?? ""

    property bool isPerScreen: {
        if (!GlobalStates.wallpaperManager || currentScreenName === "") return false;
        let perScreen = GlobalStates.wallpaperManager.perScreenWallpapers || {};
        return perScreen[currentScreenName] !== undefined;
    }

    function togglePerScreenMode() {
        if (!GlobalStates.wallpaperManager || currentScreenName === "") return;
        
        if (isPerScreen) {
            GlobalStates.wallpaperManager.clearPerScreenWallpaper(currentScreenName);
        } else {
            let currentWall = GlobalStates.wallpaperManager.currentWallpaper;
            if (currentWall) {
                GlobalStates.wallpaperManager.setWallpaper(currentWall, currentScreenName);
            }
        }
    }

    readonly property string currentWallpaper: {
        if (!GlobalStates.wallpaperManager) return "";
        let perScreen = GlobalStates.wallpaperManager.perScreenWallpapers || {};
        if (root.isPerScreen && root.currentScreenName !== "" && perScreen[root.currentScreenName] !== undefined) {
            return perScreen[root.currentScreenName];
        }
        return GlobalStates.wallpaperManager.currentWallpaper || "";
    }

    readonly property list<string> wallpapers: GlobalStates.wallpaperManager?.wallpaperPaths ?? []

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? 8 : 14
        spacing: root.compact ? 6 : 10

        // ═══════════════════════════════════════════════════════════════
        // OPTIONS TOOLBAR: Per-Screen Toggle + Mode Selector + Scheme Selector
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            id: controlsRow
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            spacing: 8
            z: 100

            // Per-Screen Monitor toggle
            Item {
                id: perScreenCheckboxContainer
                Layout.preferredWidth: root.compact ? 96 : 120
                Layout.preferredHeight: 48
                Layout.alignment: Qt.AlignVCenter

                StyledRect {
                    anchors.fill: parent
                    radius: Styling.radius(4)
                    variant: perScreenMouse.containsMouse ? "focus" : "pane"
                    scale: perScreenMouse.pressed ? 0.94 : 1.0

                    PressBehavior on scale {
                        pressed: perScreenMouse.pressed
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        StyledRect {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            variant: "internalbg"
                            color: Colors.background
                            radius: Styling.radius(0)

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                anchors.centerIn: parent
                                width: parent.width
                                text: root.currentScreenName || "Screen"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                        }

                        StyledRect {
                            Layout.preferredWidth: root.compact ? 24 : 40
                            Layout.preferredHeight: 40
                            radius: Styling.radius(0)
                            variant: root.isPerScreen ? "primary" : "transparent"

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                anchors.centerIn: parent
                                text: Icons.accept
                                color: root.isPerScreen ? Styling.srItem("primary") : Colors.overSurfaceVariant
                                font.family: Icons.font
                                font.pixelSize: 20
                                opacity: root.isPerScreen ? 1.0 : 0.2
                            }
                        }
                    }

                    MouseArea {
                        id: perScreenMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePerScreenMode()
                    }
                }

                StyledToolTip {
                    show: perScreenMouse.containsMouse
                    tooltipText: root.isPerScreen ? `Targeting ${root.currentScreenName} only (click for global)` : `Applying globally (click to target ${root.currentScreenName} only)`
                }
            }

            // Wallpaper display mode selector (crop / fit / stretch / center)
            WallpaperModeSelector {
                id: wallpaperModeSelector
                Layout.preferredWidth: root.compact ? 80 : 140
                Layout.preferredHeight: implicitHeight
                Layout.alignment: Qt.AlignVCenter
                z: 101

                onModeListExpandedChanged: {
                    if (modeListExpanded) {
                        schemeSelector.keyboardNavigationActive = false;
                        schemeSelector.schemeListExpanded = false;
                    }
                }
            }

            // Color scheme selector + Light/Dark mode switch
            SchemeSelector {
                id: schemeSelector
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                Layout.alignment: Qt.AlignVCenter
                z: 101

                onSchemeListExpandedChanged: {
                    if (schemeListExpanded) {
                        wallpaperModeSelector.keyboardNavigationActive = false;
                        wallpaperModeSelector.modeListExpanded = false;
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

            readonly property int columns: root.compact ? 2 : 3
            readonly property real itemMargin: 6

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: root.wallpapers.length === 0

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
                model: root.wallpapers
                clip: true
                visible: root.wallpapers.length > 0

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

                        scale: gridItemMouse.pressed ? 0.91 : (delegateItem.isHovered ? 0.96 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: gridItemMouse.pressed ? 80 : 160
                                easing.type: gridItemMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                easing.overshoot: 1.4
                            }
                        }

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"

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
                            id: gridItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: delegateItem.isHovered = true
                            onExited: delegateItem.isHovered = false
                            onClicked: {
                                if (GlobalStates.wallpaperManager) {
                                    if (root.isPerScreen && root.currentScreenName !== "") {
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
