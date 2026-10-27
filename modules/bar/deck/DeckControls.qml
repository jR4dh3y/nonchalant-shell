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

// Level channels in one card; quick toggles, playback, and output beside them.
// Pages narrower than the three channels and the rack stack the rack below them.
GridLayout {
    id: root
    required property ShellScreen screen
    // The dash's settled page width; the rack needs about thirty font sizes beside the levels.
    required property real pageWidth
    signal menuRequested(string page)
    signal settingsRequested(string page)
    readonly property bool stacked: pageWidth < Styling.fontSize(0) * 30
    columns: stacked ? 1 : 2
    rowSpacing: Styling.fontSize(0) * 0.5
    columnSpacing: rowSpacing

    DeckCard {
        objectName: "deckChannels"
        Layout.fillWidth: root.stacked
        Layout.fillHeight: !root.stacked
        title: "Levels"
        glyph: Icons.faders
        order: 0
        RowLayout {
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
    }

    ColumnLayout {
        objectName: "deckRack"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Styling.fontSize(0) * 0.5

        DeckCard {
            objectName: "deckQuickToggles"
            Layout.fillWidth: true
            order: 1
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                uniformCellWidths: true
                rowSpacing: Styling.fontSize(0) * 0.4
                columnSpacing: rowSpacing
                DeckAction {
                    objectName: "deckToggleWifi"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    kind: DeckAction.Action
                    labelAlignment: Text.AlignLeft
                    accent: true
                    controlHeight: Styling.fontSize(0) * 2.6
                    glyph: NetworkService.wifiEnabled ? Icons.wifiHigh : Icons.wifiOff
                    label: NetworkService.wifiConnected ? NetworkService.activeSsid : "Wi-Fi"
                    maximumLabelWidth: width
                    selected: NetworkService.wifiEnabled
                    enabled: !NetworkService.isUpdating
                    description: "Wi-Fi · Click to turn " + (selected ? "off" : "on") + " · Right-click for networks"
                    onClicked: NetworkService.toggleWifi()
                    onSecondaryClicked: root.menuRequested("wifi")
                }
                DeckAction {
                    objectName: "deckToggleBluetooth"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    kind: DeckAction.Action
                    labelAlignment: Text.AlignLeft
                    accent: true
                    controlHeight: Styling.fontSize(0) * 2.6
                    glyph: BluetoothService.enabled ? Icons.bluetooth : Icons.bluetoothOff
                    label: BluetoothService.firstConnectedDeviceName || "Bluetooth"
                    maximumLabelWidth: width
                    selected: BluetoothService.enabled
                    enabled: !BluetoothService.isUpdating
                    description: "Bluetooth · Click to turn " + (selected ? "off" : "on") + " · Right-click for devices"
                    onClicked: BluetoothService.toggle()
                    onSecondaryClicked: root.menuRequested("bluetooth")
                }
                DeckAction {
                    objectName: "deckToggleDnd"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    kind: DeckAction.Action
                    labelAlignment: Text.AlignLeft
                    accent: true
                    controlHeight: Styling.fontSize(0) * 2.6
                    glyph: Notifications.silent ? Icons.bellSlash : Icons.bell
                    label: "Do not disturb"
                    maximumLabelWidth: width
                    selected: Notifications.silent
                    onClicked: Notifications.toggleSilent()
                }
                DeckAction {
                    objectName: "deckToggleNight"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    kind: DeckAction.Action
                    labelAlignment: Text.AlignLeft
                    accent: true
                    controlHeight: Styling.fontSize(0) * 2.6
                    glyph: Icons.nightLight
                    label: "Night light"
                    maximumLabelWidth: width
                    selected: NightLightService.active
                    onClicked: NightLightService.toggle()
                }
            }
        }

        DeckCard {
            objectName: "deckPlaybackSection"
            Layout.fillWidth: true
            visible: MprisController.activePlayer !== null
            title: "Now playing"
            glyph: Icons.player
            order: 2
            DeckMedia {
                objectName: "deckMedia"
                Layout.fillWidth: true
            }
        }

        DeckCard {
            objectName: "deckDeviceSection"
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "Output"
            glyph: Icons.speakerHigh
            order: 3
            headerData: DeckAction {
                objectName: "deckMixer"
                kind: DeckAction.Icon
                controlHeight: Styling.fontSize(0) * 1.7
                glyph: Icons.faders
                description: "Per-app volume"
                onClicked: root.settingsRequested("audio")
            }
            // Only the device list scrolls; the heading and mixer stay put.
            ScrollView {
                objectName: "deckOutputDevices"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Styling.fontSize(0) * 2
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
                            controlHeight: Styling.fontSize(0) * 1.9
                            label: Audio.friendlyDeviceName(modelData)
                            glyph: modelData === Audio.sink ? Icons.check : Icons.speakerHigh
                            selected: modelData === Audio.sink
                            accent: true
                            maximumLabelWidth: width
                            onClicked: if (modelData) Audio.setDefaultSink(modelData)
                        }
                    }
                    StyledText {
                        visible: Audio.outputDevices.length === 0
                        text: "No output devices"
                        color: Colors.overSurfaceVariant
                        font.pixelSize: Styling.fontSize(-1)
                    }
                }
            }
        }
    }
}
