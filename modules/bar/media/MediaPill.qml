import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import "../../widgets/dashboard/widgets"

// Right-side media section of the center pill. Hides itself while nothing is
// playing and drops in from the top when audio starts. Clicking opens the
// detached dashboard media widget (FullPlayer) for full playback control.
Item {
    id: root

    readonly property bool hasPlayer: MprisController.activePlayer !== null
    readonly property bool audioPlaying: hasPlayer
        && MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property bool anyPopupOpen: mediaPopup.isOpen

    // Behaviors stay disabled until the first frame so a session that already
    // has audio playing does not animate the pill in on startup.
    property bool initialized: false

    Layout.preferredWidth: root.audioPlaying ? root.implicitWidth : 0
    Layout.preferredHeight: 36
    implicitWidth: contentRow.implicitWidth + 24
    implicitHeight: 36

    Behavior on Layout.preferredWidth {
        enabled: root.initialized && Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    clip: true

    // Content drops down from the top edge while the pill expands sideways.
    RowLayout {
        id: contentRow
        anchors.left: parent.left
        anchors.leftMargin: 12
        spacing: 8
        height: 28
        y: root.audioPlaying ? (parent.height - height) / 2 : -height
        opacity: root.audioPlaying ? 1 : 0

        Behavior on y {
            enabled: root.initialized && Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            enabled: root.initialized && Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
            }
        }

        Separator {
            vert: true
        }

        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            id: stateIcon
            text: root.playerIcon(MprisController.activePlayer)
            font.family: Icons.font
            font.pixelSize: Config.theme.fontSize + 2
            color: Colors.overBackground
        }

        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            id: trackInfo
            text: root.trackInfo
            color: Colors.overBackground
            font.pixelSize: Config.theme.fontSize
            font.family: Config.theme.font
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.preferredWidth: Math.min(implicitWidth, 160)
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: mediaPopup.toggle()
    }

    // Expanded view: the media widget detached from the dashboard.
    BarPopup {
        id: mediaPopup
        anchorItem: root
        variant: "transparent"
        popupPadding: 0

        contentWidth: mediaWrapper.width
        contentHeight: mediaWrapper.height

        StyledRect {
            id: mediaWrapper
            variant: "popup"
            radius: Styling.radius(8)
            enableShadow: false
            width: 232
            height: playerLoader.item ? playerLoader.item.implicitHeight + 16 : 416

            Loader {
                id: playerLoader
                anchors.fill: parent
                anchors.margins: 8
                // Create only while the popup is live so the disc rotation and
                // seek timers do not run (or render) while closed.
                active: mediaPopup.isOpen || mediaPopup.visible
                sourceComponent: Component {
                    FullPlayer {
                        width: 216
                    }
                }
            }
        }
    }

    readonly property string trackInfo: {
        const player = MprisController.activePlayer;
        if (!player) return "";
        const title = player.trackTitle ?? "";
        const artist = player.trackArtist ?? "";
        if (title && artist) return title + " · " + artist;
        return title || artist || player.identity || "";
    }

    function playerIcon(player) {
        if (!player)
            return Icons.player;
        const dbusName = (player.dbusName || "").toLowerCase();
        const desktopEntry = (player.desktopEntry || "").toLowerCase();
        const identity = (player.identity || "").toLowerCase();
        if (dbusName.includes("spotify") || desktopEntry.includes("spotify") || identity.includes("spotify"))
            return Icons.spotify;
        if (dbusName.includes("chromium") || dbusName.includes("chrome") || desktopEntry.includes("chromium") || desktopEntry.includes("chrome"))
            return Icons.chromium;
        if (dbusName.includes("firefox") || desktopEntry.includes("firefox"))
            return Icons.firefox;
        if (dbusName.includes("telegram") || desktopEntry.includes("telegram") || identity.includes("telegram"))
            return Icons.telegram;
        return Icons.player;
    }

    onHasPlayerChanged: {
        // A vanished player leaves nothing useful to show in the popup.
        if (!root.hasPlayer && mediaPopup.isOpen)
            mediaPopup.close();
    }

    Component.onCompleted: {
        root.initialized = true;
    }
}
