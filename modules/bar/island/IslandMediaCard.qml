pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

StyledRect {
    id: root

    implicitWidth: 460
    implicitHeight: 110
    variant: "pane"
    radius: Styling.radius(2)
    clip: true

    readonly property bool hasPlayer: MprisController.activePlayer !== null
    readonly property bool isPlaying: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: MprisController.activePlayer?.trackTitle || "No media playing"
    readonly property string trackArtist: MprisController.activePlayer?.trackArtists || ""
    readonly property string trackArt: MprisController.activePlayer?.trackArtUrl || ""
    readonly property string wallpaperUrl: {
        const mgr = GlobalStates.wallpaperManager;
        if (!mgr) return "";
        let path = mgr.currentWallpaper;
        let frame = (mgr.getLockscreenFramePath && path) ? mgr.getLockscreenFramePath(path) : path;
        return frame ? "file://" + frame : (path ? "file://" + path : "");
    }

    // Wallpaper background with darkening overlay
    Image {
        id: bgWallpaper
        anchors.fill: parent
        source: root.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        visible: root.wallpaperUrl !== ""
        asynchronous: true
        opacity: 0.35
    }

    // Gradient overlay for contrast
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#44000000" }
            GradientStop { position: 1.0; color: "#88000000" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Top row: Circular photo + metadata + playback buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Inline circular face / album artwork photo
            Item {
                implicitWidth: 40
                implicitHeight: 40
                Layout.alignment: Qt.AlignVCenter

                StyledRect {
                    id: photoFrame
                    anchors.fill: parent
                    radius: width / 2
                    variant: "focus"
                    clip: true

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: width / 2
                        color: "transparent"

                        Image {
                            id: coverImage
                            anchors.fill: parent
                            source: {
                                if (root.trackArt !== "")
                                    return root.trackArt;
                                if (root.wallpaperUrl !== "")
                                    return root.wallpaperUrl;
                                return "";
                            }
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: source !== ""
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !coverImage.visible
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: Icons.player
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: Colors.overBackground
                        }
                    }
                }
            }

            // Track metadata
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: root.trackTitle
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: Colors.overBackground
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: root.trackArtist !== ""
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: root.trackArtist
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurfaceVariant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Playback controls
            RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                // Previous button
                StyledRect {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: width / 2
                    variant: prevMouse.containsMouse ? "focus" : "common"

                    Text {
                        anchors.centerIn: parent
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.previous
                        font.family: Icons.font
                        font.pixelSize: 15
                        color: Colors.overBackground
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.previous()
                    }
                }

                // Play / Pause circular hero button
                StyledRect {
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: width / 2
                    variant: "primary"
                    opacity: playMouse.containsMouse ? 0.9 : 1.0

                    Text {
                        anchors.centerIn: parent
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: root.isPlaying ? Icons.pause : Icons.play
                        font.family: Icons.font
                        font.pixelSize: 18
                        color: Colors.overPrimary
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.togglePlaying()
                    }
                }

                // Next button
                StyledRect {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: width / 2
                    variant: nextMouse.containsMouse ? "focus" : "common"

                    Text {
                        anchors.centerIn: parent
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.next
                        font.family: Icons.font
                        font.pixelSize: 15
                        color: Colors.overBackground
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.next()
                    }
                }
            }
        }

        // Bottom row: Interactive Waveform progress bar
        IslandWaveformBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
        }
    }
}
