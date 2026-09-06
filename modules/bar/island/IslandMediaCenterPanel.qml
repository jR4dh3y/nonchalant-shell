pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

StyledRect {
    id: root

    implicitWidth: 420
    implicitHeight: mainCol.implicitHeight + 28
    variant: "pane"
    radius: Styling.radius(3)
    clip: true

    signal backRequested()
    signal closeRequested()

    readonly property bool hasPlayer: MprisController.activePlayer !== null
    readonly property bool isPlaying: MprisController.isPlaying
    readonly property string trackTitle: MprisController.trackTitle || "No media playing"
    readonly property string trackArtist: MprisController.trackArtists || ""
    readonly property string trackArt: MprisController.activePlayer?.trackArtUrl || ""
    readonly property bool hasArtwork: root.trackArt !== ""
    readonly property string wallpaperUrl: {
        const mgr = GlobalStates.wallpaperManager;
        if (!mgr) return "";
        let path = mgr.currentWallpaper;
        let frame = (mgr.getLockscreenFramePath && path) ? mgr.getLockscreenFramePath(path) : path;
        return frame ? "file://" + frame : (path ? "file://" + path : "");
    }

    // ═══════════════════════════════════════════════════════════════
    // ATMOSPHERIC BACKGROUND (Blurred album art + dark vignette)
    // ═══════════════════════════════════════════════════════════════
    Image {
        id: bgArt
        anchors.fill: parent
        source: root.hasArtwork ? root.trackArt : root.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: bgArt
        blurEnabled: root.hasArtwork || root.wallpaperUrl !== ""
        blurMax: 36
        blur: 0.8
        opacity: root.hasArtwork ? 0.35 : (root.wallpaperUrl !== "" ? 0.18 : 0.0)
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#55000000" }
            GradientStop { position: 0.5; color: "#77000000" }
            GradientStop { position: 1.0; color: "#aa000000" }
        }
    }

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // ═══════════════════════════════════════════════════════════════
        // HEADER: Back button + Title + Player Badge + Close button
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

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

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Media Center"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
            }

            // Player identity badge
            StyledRect {
                implicitHeight: 24
                implicitWidth: playerRow.implicitWidth + 14
                radius: 12
                variant: "internalbg"

                RowLayout {
                    id: playerRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.disc
                        font.family: Icons.font
                        font.pixelSize: 12
                        color: Colors.primary
                    }

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: MprisController.activePlayer?.identity || "Player"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.bold: true
                        color: Colors.overBackground
                    }

                    Text {
                        visible: MprisController.filteredPlayers.length > 1
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.caretRight
                        font.family: Icons.font
                        font.pixelSize: 10
                        color: Colors.overSurfaceVariant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: MprisController.filteredPlayers.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: MprisController.filteredPlayers.length > 1
                    onClicked: MprisController.cyclePlayer(1)
                }
            }

            Item { Layout.fillWidth: true }

            // Close button
            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: closeMouse.containsMouse ? "focus" : "common"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.x
                    font.family: Icons.font
                    font.pixelSize: 13
                    color: Colors.overBackground
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // HERO: Rotating Vinyl Face Disc + Track Typography
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            // ── ROTATING VINYL DISC CONTAINER ──
            Item {
                implicitWidth: 96
                implicitHeight: 96
                Layout.alignment: Qt.AlignVCenter

                // Shadow ring for 3D depth
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 4
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.rgba(0, 0, 0, 0.45)
                    border.width: 3
                }

                // Rotating Vinyl Disc body
                Item {
                    id: vinylDisc
                    anchors.fill: parent

                    RotationAnimation on rotation {
                        id: discRotation
                        running: root.isPlaying
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 8000
                    }

                    // Vinyl base record
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#0e0e12"
                        border.color: "#252530"
                        border.width: 1.5

                        // Concentric vinyl microgrooves
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.88
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: Qt.rgba(1, 1, 1, 0.07)
                            border.width: 1
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.76
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.64
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                        }

                        // Vinyl specular reflection cones (dual opposing highlights)
                        Canvas {
                            anchors.fill: parent
                            antialiasing: true
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const cx = width / 2;
                                const cy = height / 2;
                                const r = width / 2;

                                ctx.fillStyle = "rgba(255, 255, 255, 0.05)";

                                // Cone 1
                                ctx.beginPath();
                                ctx.moveTo(cx, cy);
                                ctx.arc(cx, cy, r, -0.45, 0.45);
                                ctx.closePath();
                                ctx.fill();

                                // Cone 2
                                ctx.beginPath();
                                ctx.moveTo(cx, cy);
                                ctx.arc(cx, cy, r, Math.PI - 0.45, Math.PI + 0.45);
                                ctx.closePath();
                                ctx.fill();
                            }
                        }

                        // ── THE FACE DISC: Center Album Artwork ──
                        ClippingRectangle {
                            id: faceArtworkDisc
                            anchors.centerIn: parent
                            width: parent.width * 0.52
                            height: width
                            radius: width / 2
                            color: Colors.surfaceBright

                            Image {
                                id: coverImage
                                anchors.fill: parent
                                source: {
                                    if (root.trackArt !== "") return root.trackArt;
                                    if (root.wallpaperUrl !== "") return root.wallpaperUrl;
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
                                font.pixelSize: 20
                                color: Colors.overBackground
                            }

                            // Center spindle hole
                            Rectangle {
                                anchors.centerIn: parent
                                width: 10
                                height: 10
                                radius: 5
                                color: "#0a0a0d"
                                border.color: "#c0c0c8"
                                border.width: 1.5
                            }
                        }
                    }
                }
            }

            // ── TRACK TYPOGRAPHY & ARTIST ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: root.trackTitle
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(2)
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
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: Colors.primary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: MprisController.activePlayer?.identity || "Now Playing"
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // WAVEFORM PROGRESS BAR
        // ═══════════════════════════════════════════════════════════════
        IslandWaveformBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
        }

        // ═══════════════════════════════════════════════════════════════
        // PLAYBACK CONTROLS ROW
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            // Shuffle button
            StyledRect {
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                variant: MprisController.hasShuffle ? "primary" : (shuffleMouse.containsMouse ? "focus" : "common")
                opacity: MprisController.shuffleSupported ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.shuffle
                    font.family: Icons.font
                    font.pixelSize: 15
                    color: MprisController.hasShuffle ? Colors.overPrimary : Colors.overBackground
                }

                MouseArea {
                    id: shuffleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: MprisController.shuffleSupported
                    onClicked: MprisController.setShuffle(!MprisController.hasShuffle)
                }
            }

            Item { Layout.fillWidth: true }

            // Previous track button
            StyledRect {
                implicitWidth: 38
                implicitHeight: 38
                radius: 19
                variant: prevMouse.containsMouse ? "focus" : "common"
                opacity: MprisController.canGoPrevious ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.previous
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: Colors.overBackground
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: MprisController.canGoPrevious
                    onClicked: MprisController.previous()
                }
            }

            // Play / Pause HERO button
            StyledRect {
                implicitWidth: 46
                implicitHeight: 46
                radius: 23
                variant: "primary"
                opacity: playMouse.containsMouse ? 0.9 : 1.0

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: root.isPlaying ? Icons.pause : Icons.play
                    font.family: Icons.font
                    font.pixelSize: 20
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

            // Next track button
            StyledRect {
                implicitWidth: 38
                implicitHeight: 38
                radius: 19
                variant: nextMouse.containsMouse ? "focus" : "common"
                opacity: MprisController.canGoNext ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.next
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: Colors.overBackground
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: MprisController.canGoNext
                    onClicked: MprisController.next()
                }
            }

            Item { Layout.fillWidth: true }

            // Loop / Repeat button
            StyledRect {
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                variant: MprisController.loopState !== 0 ? "primary" : (loopMouse.containsMouse ? "focus" : "common")
                opacity: MprisController.loopSupported ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: MprisController.loopState === 2 ? Icons.repeatOnce : Icons.repeat
                    font.family: Icons.font
                    font.pixelSize: 15
                    color: MprisController.loopState !== 0 ? Colors.overPrimary : Colors.overBackground
                }

                MouseArea {
                    id: loopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: MprisController.loopSupported
                    onClicked: {
                        // None (0) -> Playlist (1) -> Track (2) -> None (0)
                        const nextState = (MprisController.loopState + 1) % 3;
                        MprisController.setLoopState(nextState);
                    }
                }
            }
        }
    }
}
