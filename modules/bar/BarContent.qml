import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.bar.clock
import qs.modules.bar.systray
import qs.modules.bar.workspaces
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    required property ShellScreen screen

    readonly property bool reveal: !NiriService.overviewOpen

    readonly property real outerRadius: Styling.radius(0)
    readonly property real innerRadius: Config.bar?.pillStyle === "squished"
        ? Styling.radius(0) / 2
        : Styling.radius(0)
    readonly property int barPadding: barBg.padding
    readonly property int barTargetHeight: horizontalContent.implicitHeight + 2 * barPadding
    readonly property int totalBarHeight: barTargetHeight + barBg.outerMargin

    // Keep one floating gap at the screen edge and another below the bar so
    // tiled windows do not touch the pills.
    readonly property int baseOuterMargin: barBg.outerMargin * 2
    readonly property bool shadowsEnabled: false

    property alias barHitbox: hitbox

    Item {
        id: hitbox
        width: root.width
        height: root.reveal ? root.totalBarHeight : 0

        Item {
            id: bar
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: barBg.outerMargin
                leftMargin: barBg.outerMargin
                rightMargin: barBg.outerMargin
            }
            height: root.barTargetHeight
            opacity: root.reveal ? 1 : 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            BarBg {
                id: barBg
                anchors.fill: parent

                Item {
                    id: horizontalContent
                    anchors.fill: parent
                    implicitHeight: 36

                    NonchalantTaskbar {
                        id: nonchalantTaskbar
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: implicitWidth
                        height: implicitHeight
                        bar: root
                    }

                    SystemMonitorButton {
                        anchors.left: nonchalantTaskbar.right
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        bar: root
                        startRadius: root.outerRadius
                        endRadius: root.outerRadius
                        enableShadow: root.shadowsEnabled
                    }

                    Clock {
                        anchors.centerIn: parent
                        width: implicitWidth
                        height: implicitHeight
                        bar: root
                        layerEnabled: root.shadowsEnabled
                        startRadius: root.outerRadius
                        endRadius: root.outerRadius
                    }

                    RowLayout {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 36
                        spacing: 4

                        SysTray {
                            enableShadow: root.shadowsEnabled
                            startRadius: root.outerRadius
                            endRadius: root.innerRadius
                        }

                        VolumeSlider {
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }

                        MicSlider {
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }

                        BrightnessSlider {
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }

                        BatteryIndicator {
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.outerRadius
                        }
                    }
                }
            }
        }
    }
}
