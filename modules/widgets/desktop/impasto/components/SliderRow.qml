// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S L I D E R   R O W                                                    │
// │   a level control · icon, track and reading                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Layouts
import QtQuick.Controls

import qs.modules.widgets.desktop.impasto.theme

// The track is the control: it is dragged directly, and the icon sitting
// inside it is the target for muting rather than a separate button.
Item {
    id: root

    property string icon: ""
    property int value: 0
    property int from: 0
    property int to: 100

    // What the reading is counted in.
    property string unit: "%"
    property bool available: true
    property bool dimmed: false

    // A chevron at the end that opens more, as Wi-Fi's tile does. The drag
    // stops short of it.
    property bool expandable: false

    signal moved(int value)
    signal iconClicked()
    signal expandClicked()

    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceIn(QsWindow.window)
        border.color: slider.hovered ? Theme.borderIn(QsWindow.window) : "transparent"
        border.width: 1
        opacity: root.available ? 1 : 0.45

        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

        // Fill behind everything: the whole row is the track.
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(parent.height, parent.width * slider.position)
            radius: parent.radius
            color: root.dimmed ? Theme.surfaceHoverIn(QsWindow.window) : Theme.accent
            opacity: root.dimmed ? 1 : 0.9

            Behavior on width {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 13
            anchors.rightMargin: 14
            spacing: 10

            Text {
                text: root.icon
                font.family: Theme.fontMono
                font.pixelSize: 15
                color: root.dimmed ? Theme.textMuted : Theme.accentText

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.iconClicked()
                }
            }

            Item { Layout.fillWidth: true }

            // Theme.text rather than accentText: the fill only reaches the
            // reading at 100%.
            Text {
                text: `${root.value}${root.unit}`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: root.dimmed ? Theme.textMuted : Theme.text
            }

            Text {
                visible: root.expandable
                text: "󰅂"
                font.family: Theme.fontMono
                font.pixelSize: 13
                color: more.containsMouse ? Theme.text : Theme.textMuted

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }
        }

        // Invisible; supplies only the drag behaviour.
        Slider {
            id: slider
            anchors.fill: parent
            anchors.rightMargin: root.expandable ? 32 : 0
            from: root.from
            to: root.to
            value: root.value
            enabled: root.available
            opacity: 0
            onMoved: root.moved(Math.round(slider.value))
        }

        MouseArea {
            id: more

            anchors.right: parent.right
            width: 32
            height: parent.height
            visible: root.expandable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandClicked()
        }
    }
}
