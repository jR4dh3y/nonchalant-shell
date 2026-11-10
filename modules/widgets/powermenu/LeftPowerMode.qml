import QtQuick
import qs.modules.theme

// State for the left dock's power mode. PowerMenuHost owns one per screen and
// LeftBar draws it by turning its own controls into actions: the capsule holds
// Lock, Sleep and Hibernate, and three droplets become Log out, Restart and
// Shut down. Destructive actions need a second, separate selection.
Item {
    id: root
    objectName: "leftPowerMode"
    visible: false

    readonly property list<string> actions: ["lock", "suspend", "hibernate", "logout", "reboot", "poweroff"]
    readonly property list<string> labels: ["Lock", "Sleep", "Hibernate", "Log out", "Restart", "Shut down"]
    readonly property list<string> glyphs: [Icons.lock, Icons.suspend, Icons.hibernate, Icons.logout, Icons.reboot, Icons.shutdown]
    readonly property int sessionCount: 3

    property bool open: false
    property int currentIndex: 0
    property string armedAction: ""
    // Drives every transformed control. Springs past 1 on open and falls
    // monotonically on close; reversal continues from the current value.
    property real reveal: 0
    readonly property bool active: open || reveal > 0.001

    signal actionRequested(string action)
    signal closeRequested()

    function reset(): void {
        armedAction = "";
        confirmation.stop();
    }

    function show(): void {
        reset();
        currentIndex = 0;
        open = true;
    }

    function hide(): void {
        reset();
        open = false;
    }

    function choose(index: int): void {
        if (!open || index < 0 || index >= actions.length)
            return;
        currentIndex = index;
        const action = actions[index];
        if (index >= sessionCount && armedAction !== action) {
            armedAction = action;
            confirmation.restart();
            return;
        }
        reset();
        actionRequested(action);
    }

    function handleKey(event: KeyEvent): bool {
        if (!open)
            return false;
        const count = actions.length;
        const backward = event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
            || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier));
        if (backward) {
            currentIndex = (currentIndex + count - 1) % count;
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            currentIndex = (currentIndex + 1) % count;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            // A held key must never arm and then confirm.
            if (!event.isAutoRepeat)
                choose(currentIndex);
        } else if (event.key === Qt.Key_Escape) {
            if (armedAction)
                reset();
            else
                closeRequested();
        } else {
            return false;
        }
        return true;
    }

    // Moving off an armed action disarms it.
    onCurrentIndexChanged: {
        if (armedAction && actions[currentIndex] !== armedAction)
            reset();
    }

    Timer {
        id: confirmation
        interval: 5000
        onTriggered: root.reset()
    }

    NumberAnimation {
        id: openAnim
        target: root
        property: "reveal"
        to: 1
        duration: Motion.expandDuration
        easing.type: Easing.OutBack
        easing.overshoot: Motion.overshoot
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "reveal"
        to: 0
        duration: Motion.collapseDuration
        easing.type: Easing.InCubic
    }

    onOpenChanged: {
        openAnim.stop();
        closeAnim.stop();
        if (!Motion.enabled)
            reveal = open ? 1 : 0;
        else
            (open ? openAnim : closeAnim).start();
    }
}
