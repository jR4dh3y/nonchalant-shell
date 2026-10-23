pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

// Console layout: level channels on the left, the session rack on the right.
RowLayout {
    id: root
    required property ShellScreen screen
    signal menuRequested(string page)
    signal settingsRequested(string page)
    spacing: Styling.fontSize(0)

    RowLayout {
        objectName: "deckChannels"
        Layout.fillHeight: true
        spacing: Styling.fontSize(0) * 0.25
        DeckChannel {
            objectName: "deckOutput"
            Layout.fillHeight: true
            Layout.preferredWidth: Styling.fontSize(0) * 4.4
            muteCapable: true
            label: "Output"
            glyph: Audio.sink?.audio?.muted ? Icons.speakerSlash : Icons.speakerHigh
            value: Audio.sink?.audio?.volume ?? 0
            available: Audio.sink?.audio !== undefined && Audio.sink?.audio !== null
            muted: Audio.sink?.audio?.muted ?? false
            onMuteRequested: Audio.toggleMute()
            onEdited: value => Audio.setVolume(value)
        }
        DeckChannel {
            objectName: "deckInput"
            Layout.fillHeight: true
            Layout.preferredWidth: Styling.fontSize(0) * 4.4
            muteCapable: true
            label: "Mic"
            glyph: Audio.source?.audio?.muted ? Icons.micSlash : Icons.mic
            value: Audio.source?.audio?.volume ?? 0
            available: Audio.source?.audio !== undefined && Audio.source?.audio !== null
            muted: Audio.source?.audio?.muted ?? false
            onMuteRequested: Audio.toggleMicMute()
            onEdited: value => Audio.setMicVolume(value)
        }
        DeckChannel {
            objectName: "deckDisplay"
            Layout.fillHeight: true
            Layout.preferredWidth: Styling.fontSize(0) * 4.4
            label: "Display"
            glyph: Icons.sun
            value: Brightness.getMonitorForScreen(root.screen)?.brightness ?? 0
            available: Brightness.getMonitorForScreen(root.screen)?.ready ?? false
            onEdited: value => Brightness.setBrightnessForScreen(root.screen, value)
        }
    }

    ColumnLayout {
        id: rack
        objectName: "deckRack"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Styling.fontSize(0) * 0.8

        DeckSection {
            objectName: "deckDeviceSection"
            title: "Output device"
            Layout.fillWidth: true
            visible: Audio.outputDevices.length > 1

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(3, Audio.outputDevices.length) * Styling.fontSize(0) * 2
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: parent.width
                    spacing: Styling.fontSize(0) * 0.2
                    Repeater {
                        model: Audio.outputDevices
                        DeckAction {
                            required property PwNode modelData
                            objectName: "deckOutputDevice-" + (modelData?.id ?? "")
                            Layout.fillWidth: true
                            controlHeight: Styling.fontSize(0) * 1.8
                            label: Audio.friendlyDeviceName(modelData)
                            glyph: modelData === Audio.sink ? Icons.check : Icons.speakerHigh
                            selected: modelData === Audio.sink
                            maximumLabelWidth: root.width
                            onClicked: if (modelData) Audio.setDefaultSink(modelData)
                        }
                    }
                }
            }
        }

        DeckSection {
            objectName: "deckPlaybackSection"
            title: "Playback"
            Layout.fillWidth: true
            visible: MprisController.activePlayer !== null

            DeckMedia {
                objectName: "deckMedia"
                Layout.fillWidth: true
            }
        }

        Item { Layout.fillHeight: true }
        DeckAction {
            objectName: "deckMixer"
            Layout.fillWidth: true
            glyph: Icons.faders
            label: "Sound mixer"
            onClicked: root.settingsRequested("audio")
        }
        RowLayout {
            Layout.fillWidth: true
            DeckAction { objectName: "deckControlConnections"; glyph: Icons.wifiHigh; description: "Connections"; onClicked: root.menuRequested("connections") }
            DeckAction { objectName: "deckControlResources"; glyph: Icons.cpu; description: "Resources"; onClicked: root.menuRequested("stats") }
            DeckAction { objectName: "deckControlWallpapers"; glyph: Icons.wallpapers; description: "Wallpapers"; onClicked: root.menuRequested("wallpapers") }
            DeckAction { objectName: "deckControlSettings"; glyph: Icons.gear; description: "Shell settings"; onClicked: root.settingsRequested("shell") }
        }
    }
}
