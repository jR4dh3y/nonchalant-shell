pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.components
import qs.modules.theme

// One console channel: live readout, vertical fader or meter, and its own switch.
// Faders and read-only meters share this strip so levels read the same everywhere.
ColumnLayout {
    id: root
    required property string label
    property string glyph: ""
    property real value: 0
    property bool available: true
    property bool muted: false
    property bool muteCapable: false
    property bool interactive: true
    property string readout: !available ? "—" : String(Math.round(value * 100))
    property string unit: !available ? "" : muted ? " muted" : "%"
    signal edited(real value)
    signal muteRequested()
    spacing: Styling.fontSize(0) * 0.5

    Row {
        objectName: root.objectName + "-readout"
        Layout.alignment: Qt.AlignHCenter
        StyledText {
            id: readoutValue
            text: root.readout
            font.pixelSize: Styling.fontSize(6)
            font.weight: Font.DemiBold
            color: root.available && !root.muted ? Colors.overBackground : Colors.overSurfaceVariant
        }
        StyledText {
            text: root.unit
            anchors.baseline: readoutValue.baseline
            font.pixelSize: Styling.fontSize(-3)
            color: Colors.overSurfaceVariant
        }
    }
    Slider {
        id: slider
        objectName: root.objectName + "-slider"
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: Styling.fontSize(0) * 3
        orientation: Qt.Vertical
        padding: 0
        from: 0
        to: 1
        stepSize: 0.01
        value: root.value
        enabled: root.available && root.interactive
        focusPolicy: root.interactive ? Qt.StrongFocus : Qt.NoFocus
        Accessible.name: root.label + (root.available ? "" : ", unavailable")
        Accessible.ignored: !root.interactive
        onMoved: root.edited(value)
        background: StyledRect {
            objectName: root.objectName + "-track"
            x: (slider.width - width) / 2
            width: Styling.fontSize(0) * 1.6
            height: slider.height
            radius: Styling.radius(-8)
            variant: "internalbg"
            backgroundOpacity: 1
            enableBorder: true
            Repeater {
                model: 3
                StyledRect {
                    required property int index
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * (index + 1) / 4
                    width: parent.width * 0.3
                    height: Math.max(1, Styling.fontSize(0) / 14)
                    variant: "pane"
                    backgroundOpacity: 1
                    enableBorder: false
                    radius: 0
                }
            }
            StyledRect {
                objectName: root.objectName + "-level"
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * Math.max(0, Math.min(1, slider.position))
                radius: parent.radius
                variant: "focus"
                color: root.muted || !root.available ? Colors.overSurfaceVariant : Colors.primary
                opacity: root.muted || !root.available ? 0.35 : 1
                enableBorder: false
                Behavior on height { enabled: Motion.enabled && !slider.pressed; NumberAnimation { duration: Motion.fadeOutDuration; easing.type: Easing.OutCubic } }
            }
        }
        handle: StyledRect {
            visible: root.interactive && root.available
            x: (slider.width - width) / 2
            y: slider.visualPosition * (slider.availableHeight - height)
            width: Styling.fontSize(0) * 2.4
            height: Styling.fontSize(0) * (slider.pressed ? 0.75 : 0.55)
            radius: height / 2
            variant: "focus"
            color: Colors.overBackground
            enableBorder: slider.visualFocus
        }
        WheelHandler {
            enabled: root.interactive && root.available
            onWheel: event => {
                const delta = event.angleDelta.y || event.angleDelta.x;
                if (delta !== 0) root.edited(Math.max(0, Math.min(1, root.value + (delta > 0 ? 0.02 : -0.02))));
                event.accepted = true;
            }
        }
    }
    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Styling.fontSize(0) * 2
        Layout.preferredHeight: Styling.fontSize(0) * 2
        DeckAction {
            anchors.fill: parent
            objectName: root.objectName + "-mute"
            kind: DeckAction.Icon
            glyph: root.glyph
            description: root.muted ? "Unmute " + root.label : "Mute " + root.label
            visible: root.muteCapable
            enabled: root.available && root.muteCapable
            selected: root.muted
            onClicked: root.muteRequested()
        }
        StyledText {
            objectName: root.objectName + "-icon"
            anchors.centerIn: parent
            visible: !root.muteCapable
            text: root.glyph
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(3)
            color: Colors.overSurfaceVariant
            Accessible.ignored: true
        }
    }
    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: Styling.fontSize(0) * 5.5
        text: root.label
        elide: Text.ElideRight
        font.pixelSize: Styling.fontSize(-3)
        font.weight: Font.Medium
        color: root.available ? Colors.overBackground : Colors.overSurfaceVariant
    }
}
