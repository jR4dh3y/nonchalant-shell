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

    property bool showHeader: false
    signal backRequested()

    variant: "pane"
    backgroundOpacity: 0
    enableBorder: false
    radius: Styling.radius(0)

    implicitWidth: 420
    implicitHeight: squareArtwork ? width : mainCol.implicitHeight + 28

    property bool lyricsActive: false
    property bool squareArtwork: false
    readonly property real contentHeightLimit: squareArtwork ? height : maximumHeight
    property real maximumHeight: 0
    readonly property real fixedContentHeight: heroRow.implicitHeight
        + waveformRow.Layout.preferredHeight + playbackRow.implicitHeight
        + mainCol.spacing * (squareArtwork ? 3 : 2) + 28
        + (showHeader ? panelHeader.implicitHeight + mainCol.spacing : 0)

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

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        Image {
            id: bgArt
            objectName: "mediaCenterArtwork"
            anchors.fill: parent
            source: root.hasArtwork ? root.trackArt : root.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            clip: true
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: root.hasArtwork || root.wallpaperUrl !== ""
                blurMax: 36
                blur: root.squareArtwork ? 0.4 : 0.8
            }
            opacity: root.hasArtwork ? (root.squareArtwork ? 0.8 : 0.35) : (root.wallpaperUrl !== "" ? 0.18 : 0.0)
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.squareArtwork ? Qt.alpha(Colors.background, 0.45) : "#55000000" }
                GradientStop { position: 0.5; color: root.squareArtwork ? Qt.alpha(Colors.background, 0.25) : "#77000000" }
                GradientStop { position: 1.0; color: root.squareArtwork ? Qt.alpha(Colors.background, 0.85) : "#aa000000" }
            }
        }
    }

    ColumnLayout {
        id: mainCol
        anchors.top: parent.top
        anchors.bottom: root.squareArtwork ? parent.bottom : undefined
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 12

        IslandPanelHeader {
            id: panelHeader
            Layout.fillWidth: true
            visible: root.showHeader
            title: "Media"
            onBackRequested: root.backRequested()
        }

        // ═══════════════════════════════════════════════════════════════
        // HERO: Artwork + Track Typography
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            id: heroRow
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 16

            Item {
                visible: !root.squareArtwork
                implicitWidth: 96
                implicitHeight: 96
                Layout.alignment: Qt.AlignVCenter

                scale: artworkMouse.pressed ? 0.92 : 1.0
                PressBehavior on scale {
                    pressed: artworkMouse.pressed
                }

                StyledRect {
                    anchors.fill: parent
                    variant: "internalbg"
                    radius: width / 2
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"

                    RotationAnimation on rotation {
                        running: coverImage.status === Image.Ready
                        paused: !root.isPlaying
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 8000
                    }

                    Image {
                        id: coverImage
                        anchors.fill: parent
                        source: root.trackArt
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: coverImage.status !== Image.Ready
                        text: Icons.player
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(6)
                        color: Colors.overBackground
                    }
                }

                MouseArea {
                    id: artworkMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: MprisController.togglePlaying()
                }

                StyledToolTip {
                    show: artworkMouse.containsMouse
                    tooltipText: root.isPlaying ? "Click to Pause" : "Click to Play"
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

                    Behavior on opacity { NumberAnimation { duration: 160 } }
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

                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }
            }
        }

        Item {
            visible: root.squareArtwork
            Layout.fillHeight: true
        }

        LyricsView {
            collapseWhenEmpty: true
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: root.contentHeightLimit > 0
                ? Math.max(0, Math.min(implicitHeight, root.contentHeightLimit - root.fixedContentHeight - mainCol.spacing))
                : implicitHeight
            mode: "detail"
            lyricsEnabled: Config.bar?.lyricsEnabled ?? true
            active: root.lyricsActive
        }

        // ═══════════════════════════════════════════════════════════════
        // WAVEFORM PROGRESS BAR
        // ═══════════════════════════════════════════════════════════════
        IslandWaveformBar {
            id: waveformRow
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: 38
        }

        // ═══════════════════════════════════════════════════════════════
        // PLAYBACK CONTROLS ROW
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            id: playbackRow
            objectName: "mediaCenterPlayback"
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            // Shuffle button
            StyledRect {
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                variant: MprisController.hasShuffle ? "primary" : (shuffleMouse.containsMouse ? "focus" : "common")
                opacity: MprisController.shuffleSupported ? 1.0 : 0.4
                scale: shuffleMouse.pressed ? 0.92 : 1.0
                PressBehavior on scale {
                    pressed: shuffleMouse.pressed
                }

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
                scale: prevMouse.pressed ? 0.92 : 1.0
                PressBehavior on scale {
                    pressed: prevMouse.pressed
                }

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
                scale: playMouse.pressed ? 0.92 : 1.0
                PressBehavior on scale {
                    pressed: playMouse.pressed
                }

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
                scale: nextMouse.pressed ? 0.92 : 1.0
                PressBehavior on scale {
                    pressed: nextMouse.pressed
                }

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
                scale: loopMouse.pressed ? 0.92 : 1.0
                PressBehavior on scale {
                    pressed: loopMouse.pressed
                }

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
