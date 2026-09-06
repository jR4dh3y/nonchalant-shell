pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
        spacing: 12

        // Header: Back button + Title + Location badge + Refresh button
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: backMouse.containsMouse ? "focus" : "common"

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
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Weather"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
            }

            Item { Layout.fillWidth: true }

            // Location badge
            StyledRect {
                implicitHeight: 26
                implicitWidth: locRow.implicitWidth + 14
                radius: 13
                variant: "internalbg"

                RowLayout {
                    id: locRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Icons.mapPin
                        font.family: Icons.font
                        font.pixelSize: 12
                        color: Colors.primary
                    }

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: Config.weather?.location || "Local"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.bold: true
                        color: Colors.overBackground
                    }
                }
            }

            // Refresh button
            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                variant: refreshMouse.containsMouse ? "focus" : "common"

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
            }
        }

        // 1. Sky View Card: Celestial Arc, Sun/Moon position, Current Temp & Condition
        ClippingRectangle {
            Layout.fillWidth: true
            implicitHeight: 140
            radius: Styling.radius(3)
            clip: true

            WeatherWidget {
                anchors.fill: parent
                showDebugControls: false
                animationsEnabled: root.visible
            }
        }

        // 2. 5-Day Forecast Card Strip with vertical column dividers
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 88
            radius: Styling.radius(3)
            variant: "internalbg"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 0

                Repeater {
                    model: (WeatherService.forecast && WeatherService.forecast.length > 0) ? WeatherService.forecast.slice(0, 5) : []

                    RowLayout {
                        id: dayContainer
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: parent.height
                        spacing: 0

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 3

                            // Day name ("Today", "Sun", "Mon", etc.)
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: dayContainer.index === 0 ? "Today" : (dayContainer.modelData.dayName || "")
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
                                text: dayContainer.modelData.emoji || "☀️"
                                font.family: Config.theme.font
                                font.pixelSize: 18
                            }

                            // Max temperature (+30°)
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: (Math.round(dayContainer.modelData.maxTemp) >= 0 ? "+" : "") + Math.round(dayContainer.modelData.maxTemp) + "°"
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
                                text: (Math.round(dayContainer.modelData.minTemp) >= 0 ? "+" : "") + Math.round(dayContainer.modelData.minTemp) + "°"
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overSurfaceVariant
                            }
                        }

                        // Vertical separator between forecast days
                        Rectangle {
                            visible: dayContainer.index < 4
                            Layout.fillHeight: true
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                            width: 1
                            color: Colors.outlineVariant ?? Qt.rgba(1, 1, 1, 0.12)
                            opacity: 0.4
                        }
                    }
                }
            }
        }
    }
}
