import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)

    Layout.fillHeight: true

    required property MprisPlayer player

    property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing
    property real position: player?.position ?? 0.0
    property real length: player === MprisController.activePlayer ? MprisController.length
        : player?.lengthSupported ? Math.max(0, player.length) : 0.0
    property bool hasArtwork: (player?.trackArtUrl ?? "") !== ""
    // property var playerColors: hasArtwork ? PlayerColors.getColorsForPlayer(player) : null

    property alias value: slider.value
    property alias isDragging: slider.isDragging

    function playbackProgress(): real {
        return root.length > 0 ? Math.max(0, Math.min(1, root.position / root.length)) : 0;
    }

    // Propiedades opcionales para sobrescribir colores
    property color customProgressColor: Styling.srItem("overprimary", root.shellPalette)
    property color customBackgroundColor: root.shellPalette.shadow
    property bool useCustomColors: false

    StyledSlider {
        id: slider
        anchors.fill: parent
        enabled: root.length > 0 && (root.player?.canSeek ?? false)

        value: root.playbackProgress()
        progressColor: root.useCustomColors ? root.customProgressColor : Styling.srItem("overprimary", root.shellPalette)
        backgroundColor: root.useCustomColors ? root.customBackgroundColor : root.shellPalette.shadow
        wavy: true // Always use WavyLine logic
        playing: root.isPlaying // Control animation state via playing property
        wavyAmplitude: root.isPlaying ? 1 : 0.0
        wavyFrequency: root.isPlaying ? 8 : 0
        heightMultiplier: root.player ? 8 : 4
        smoothDrag: true
        scroll: false
        tooltip: false
        updateOnRelease: true

        onValueEdited: newValue => {
            if (root.length > 0 && root.player && root.player.canSeek) {
                root.player.position = newValue * root.length;
            }
            // StyledSlider assigns value on release; resume following the player.
            slider.value = Qt.binding(() => root.playbackProgress());
        }
    }
}
