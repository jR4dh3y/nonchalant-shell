pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.widgets.dashboard.widgets.calendar
import qs.config

Item {
    id: root

    implicitWidth: 420
    implicitHeight: mainCol.implicitHeight + 28

    signal backRequested()

    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ═══════════════════════════════════════════════════════════════
        // HEADER: Back button + Title
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: backMouse.containsMouse ? "focus" : "common"
                scale: backMouse.pressed ? 0.88 : (backMouse.containsMouse ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowLeft
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: Colors.overBackground
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }

                StyledToolTip {
                    show: backMouse.containsMouse
                    tooltipText: "Back to Dashboard"
                }
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Calendar"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
            }

            Item { Layout.fillWidth: true }
        }

        // ═══════════════════════════════════════════════════════════════
        // CLOCK CARD: Time & Date on top
        // ═══════════════════════════════════════════════════════════════
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: clockCol.implicitHeight + 20
            radius: Styling.radius(2)
            variant: "internalbg"
            clip: true

            ColumnLayout {
                id: clockCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 2

                RowLayout {
                    spacing: 6

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Qt.formatTime(root.now, Config.bar?.use12hFormat ? "hh:mm ap" : "hh:mm")
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(4)
                        font.bold: true
                        color: Colors.overBackground
                    }

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Qt.formatTime(root.now, "ss")
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 4
                    }
                }

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Qt.formatDate(root.now, "dddd, d MMMM yyyy")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    color: Colors.overSurfaceVariant
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // CALENDAR: Reused standard calendar component
        // ═══════════════════════════════════════════════════════════════
        Calendar {
            Layout.fillWidth: true
            Layout.preferredHeight: 265
        }
    }
}
