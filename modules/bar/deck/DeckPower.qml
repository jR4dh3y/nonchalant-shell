pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services
import qs.modules.theme

ColumnLayout {
    id: root
    property string armedAction: ""
    signal actionRequested(string action)
    spacing: Styling.fontSize(0) * 0.4

    function actionLabel(action: string): string {
        return ({ lock: "Lock", suspend: "Sleep", hibernate: "Hibernate", logout: "Log out", reboot: "Restart", poweroff: "Shut down" })[action] ?? "";
    }
    function cancelConfirmation(): void {
        root.armedAction = "";
        confirmation.stop();
    }
    function choose(action: string): void {
        if (["logout", "reboot", "poweroff"].includes(action) && root.armedAction !== action) {
            root.armedAction = action;
            confirmation.restart();
            return;
        }
        confirmation.stop();
        root.armedAction = "";
        root.actionRequested(action);
    }
    Timer { id: confirmation; interval: 3000; onTriggered: root.armedAction = "" }
    Keys.onEscapePressed: event => {
        if (root.armedAction !== "") { root.armedAction = ""; confirmation.stop(); event.accepted = true; }
        else event.accepted = false;
    }
    DeckSection {
        Layout.fillWidth: true
        visible: !Battery.available && PowerProfile.availableProfiles.length > 0
        title: "Power profile"
        Repeater {
            model: PowerProfile.availableProfiles
            DeckAction {
                required property string modelData
                Layout.fillWidth: true
                label: PowerProfile.getProfileDisplayName(modelData)
                glyph: selected ? Icons.check : Icons.lightning
                selected: PowerProfile.currentProfile === modelData
                onClicked: PowerProfile.setProfile(modelData)
            }
        }
    }
    Repeater {
        model: ["lock", "suspend", "hibernate", "logout", "reboot", "poweroff"]
        DeckAction {
            required property string modelData
            objectName: "deckPower-" + modelData
            Layout.fillWidth: true
            glyph: ({ lock: Icons.lock, suspend: Icons.suspend, hibernate: Icons.hibernate, logout: Icons.logout, reboot: Icons.reboot, poweroff: Icons.shutdown })[modelData]
            label: root.armedAction === modelData ? "Click again to " + root.actionLabel(modelData).toLowerCase() : root.actionLabel(modelData)
            selected: root.armedAction === modelData
            maximumLabelWidth: root.width
            onClicked: root.choose(modelData)
        }
    }
    Item { Layout.fillHeight: true }
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Styling.fontSize(0) * 2
        StyledText {
            Layout.fillWidth: true
            text: root.armedAction ? "Click again within 3 seconds." : "Confirm session actions with a second click."
            font.pixelSize: Styling.fontSize(-3)
            color: Colors.overSurfaceVariant
            wrapMode: Text.WordWrap
        }
        DeckAction {
            objectName: "deckPowerCancel"
            visible: root.armedAction !== ""
            label: "Cancel"
            onClicked: root.cancelConfirmation()
        }
    }
}
