pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services
import qs.modules.theme

// Battery flyout: charge, then power profiles, then the way to session actions.
ColumnLayout {
    id: root
    signal powerRequested()
    spacing: Styling.fontSize(0) * 0.5
    DeckCard {
        objectName: "deckBatteryCharge"
        Layout.fillWidth: true
        order: 0
        RowLayout {
            Layout.fillWidth: true
            spacing: Styling.fontSize(0) * 0.6
            StyledText { text: Battery.getBatteryIcon(); font.family: Icons.font; font.pixelSize: Styling.fontSize(6); color: Colors.primary }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText { text: Math.round(Battery.percentage) + "%"; font.pixelSize: Styling.fontSize(5); font.weight: Font.DemiBold }
                StyledText {
                    Layout.fillWidth: true
                    text: Battery.isCharging ? "Charging" + (Battery.timeToFull ? " · " + Battery.timeToFull + " to full" : "")
                        : Battery.isPluggedIn ? "Plugged in" : "On battery" + (Battery.timeToEmpty ? " · " + Battery.timeToEmpty + " left" : "")
                    wrapMode: Text.WordWrap
                    color: Colors.overSurfaceVariant
                    font.pixelSize: Styling.fontSize(-2)
                }
            }
        }
    }
    DeckCard {
        objectName: "deckBatteryProfiles"
        Layout.fillWidth: true
        title: "Power profile"
        glyph: Icons.lightning
        order: 1
        visible: PowerProfile.availableProfiles.length > 0
        Repeater {
            model: PowerProfile.availableProfiles
            DeckAction {
                required property string modelData
                objectName: "deckProfile-" + modelData
                Layout.fillWidth: true
                accent: true
                label: PowerProfile.getProfileDisplayName(modelData)
                glyph: selected ? Icons.check : Icons.lightning
                selected: PowerProfile.currentProfile === modelData
                onClicked: PowerProfile.setProfile(modelData)
            }
        }
    }
    Item { Layout.fillHeight: true }
    DeckAction {
        objectName: "deckBatteryPower"
        Layout.fillWidth: true
        kind: DeckAction.Action
        labelAlignment: Text.AlignLeft
        label: "Power and session"
        glyph: Icons.power
        onClicked: root.powerRequested()
    }
}
