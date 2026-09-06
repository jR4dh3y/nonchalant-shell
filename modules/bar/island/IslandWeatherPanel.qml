pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.widgets.dashboard.widgets
import qs.config

Item {
    id: root

    implicitWidth: 420
    implicitHeight: mainColumn.implicitHeight + 28

    signal backRequested()

    Component.onCompleted: {
        if (!WeatherService.dataAvailable && !WeatherService.isLoading) {
            WeatherService.updateWeather();
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ═══════════════════════════════════════════════════════════════
        // HEADER: Back button + Title (with capitalized city) + Refresh
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            id: headerRow
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
                    tooltipText: "Back"
                }
            }

            RowLayout {
                spacing: 6

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: "Weather"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    font.bold: true
                    color: Colors.overBackground
                }

                Text {
                    readonly property string loc: Config.weather?.location || ""
                    visible: loc.length > 0
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: {
                        const raw = loc.split(",")[0].trim();
                        return raw ? ("· " + raw.charAt(0).toUpperCase() + raw.slice(1)) : "";
                    }
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurfaceVariant
                    elide: Text.ElideRight
                    Layout.maximumWidth: 180
                }
            }

            Item { Layout.fillWidth: true }

            // Refresh button
            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: refreshMouse.containsMouse ? "focus" : "common"
                scale: refreshMouse.pressed ? 0.88 : (refreshMouse.containsMouse ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowsClockwise
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: WeatherService.isLoading ? Colors.primary : Colors.overBackground

                    RotationAnimation on rotation {
                        running: WeatherService.isLoading
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WeatherService.updateWeather()
                }

                StyledToolTip {
                    show: refreshMouse.containsMouse
                    tooltipText: "Refresh weather"
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // 1. SKY VIEW CARD: Celestial Arc, Sun/Moon, Temp & Condition
        // ═══════════════════════════════════════════════════════════════
        ClippingRectangle {
            id: skyCardItem
            Layout.fillWidth: true
            implicitHeight: 140
            radius: Styling.radius(2)
            clip: true

            WeatherWidget {
                anchors.fill: parent
                showDebugControls: false
                animationsEnabled: root.visible
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // 2. 5-DAY FORECAST CARD: Clean, mathematically equal 5 columns
        // ═══════════════════════════════════════════════════════════════
        StyledRect {
            id: forecastCard
            Layout.fillWidth: true
            implicitHeight: 96
            radius: Styling.radius(2)
            variant: "internalbg"
            clip: true

            Row {
                anchors.fill: parent
                anchors.margins: 8

                Repeater {
                    model: (WeatherService.forecast && WeatherService.forecast.length > 0) ? WeatherService.forecast.slice(0, 5) : []

                    Item {
                        id: dayCol
                        required property var modelData
                        required property int index
                        width: parent.width / 5
                        height: parent.height

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            // Day name ("Today", "Mon", "Tue", etc.)
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: dayCol.index === 0 ? "Today" : (dayCol.modelData.dayName || "")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overBackground
                            }

                            // Weather condition emoji
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: dayCol.modelData.emoji || "☀️"
                                font.family: Config.theme.font
                                font.pixelSize: 18
                            }

                            // Max temperature (+30°)
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: (Math.round(dayCol.modelData.maxTemp) >= 0 ? "+" : "") + Math.round(dayCol.modelData.maxTemp) + "°"
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-1)
                                font.bold: true
                                color: Colors.overBackground
                            }

                            // Min temperature (+24°)
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: (Math.round(dayCol.modelData.minTemp) >= 0 ? "+" : "") + Math.round(dayCol.modelData.minTemp) + "°"
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overSurfaceVariant
                            }
                        }

                        // Vertical separator between forecast days
                        Rectangle {
                            visible: dayCol.index < 4
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            width: 1
                            color: Colors.outlineVariant ?? Qt.rgba(1, 1, 1, 0.12)
                            opacity: 0.35
                        }
                    }
                }
            }
        }
    }
}
