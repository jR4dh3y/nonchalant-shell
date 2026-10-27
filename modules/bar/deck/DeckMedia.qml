pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services
import qs.modules.theme

ColumnLayout {
    id: root
    spacing: Styling.fontSize(0) * 0.3
    RowLayout {
        Layout.fillWidth: true
        spacing: Styling.fontSize(0) * 0.6
        Image {
            Layout.preferredWidth: Styling.fontSize(0) * 2.6
            Layout.preferredHeight: width
            source: MprisController.activePlayer?.trackArtUrl ?? ""
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            fillMode: Image.PreserveAspectCrop
            visible: source.toString() !== "" && status !== Image.Error
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: MprisController.trackTitle || "Nothing playing"
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: MprisController.trackArtists
                visible: text !== ""
                color: Colors.overSurfaceVariant
                font.pixelSize: Styling.fontSize(-3)
                elide: Text.ElideRight
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 0
        DeckAction {
            objectName: "deckMediaPrevious"
            glyph: Icons.previous
            kind: DeckAction.Icon
            description: "Previous track"
            enabled: MprisController.canGoPrevious
            onClicked: MprisController.previous()
        }
        DeckAction {
            objectName: "deckMediaPlay"
            glyph: MprisController.isPlaying ? Icons.pause : Icons.play
            kind: DeckAction.Icon
            selected: MprisController.isPlaying
            description: MprisController.isPlaying ? "Pause" : "Play"
            enabled: MprisController.canTogglePlaying
            onClicked: MprisController.togglePlaying()
        }
        DeckAction {
            objectName: "deckMediaNext"
            glyph: Icons.next
            kind: DeckAction.Icon
            description: "Next track"
            enabled: MprisController.canGoNext
            onClicked: MprisController.next()
        }
        DeckFader {
            objectName: "deckMediaSeek"
            Layout.fillWidth: true
            Layout.leftMargin: Styling.fontSize(0) * 0.4
            visible: (MprisController.activePlayer?.canSeek ?? false) && MprisController.length > 0
            label: "Playback position"
            value: MprisController.progress
            available: visible
            onEdited: value => {
                if (MprisController.activePlayer?.canSeek)
                    MprisController.activePlayer.position = value * MprisController.length;
            }
        }
    }
}
