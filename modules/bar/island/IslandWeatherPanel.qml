pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    implicitWidth: 480
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

        // Main Weather Card: Current Temperature & Condition
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: currentCondCol.implicitHeight + 24
            radius: Styling.radius(3)
            variant: "internalbg"

            ColumnLayout {
                id: currentCondCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // Top: Big Emoji + Temperature + Description + High/Low
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    // Weather Symbol / Icon
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: WeatherService.weatherSymbol || Icons.sun
                        font.family: WeatherService.weatherSymbol ? Config.theme.font : Icons.font
                        font.pixelSize: 42
                        color: Colors.yellow
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Temperature Readout
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: WeatherService.currentTemp > 0 ? (Math.round(WeatherService.currentTemp) + "°" + (Config.weather?.unit || "C")) : "—"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(8)
                        font.bold: true
                        color: Colors.overBackground
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    // Description and High/Low Column
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: WeatherService.weatherDescription || "Clear"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.overBackground
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignRight
                        }

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: "H: " + Math.round(WeatherService.maxTemp) + "°  L: " + Math.round(WeatherService.minTemp) + "°"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overSurfaceVariant
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }

                Separator {
                    Layout.fillWidth: true
                }

                // Metrics row: Wind, Sunrise, Sunset
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Wind
                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: Styling.radius(2)
                        variant: "pane"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: "💨"
                                font.family: Config.theme.font
                                font.pixelSize: 14
                            }

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: Math.round(WeatherService.windSpeed) + " km/h"
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: true
                                color: Colors.overBackground
                            }
                        }
                    }

                    // Sunrise
                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: Styling.radius(2)
                        variant: "pane"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: Icons.sun
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: Colors.yellow
                            }

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: WeatherService.sunrise || "—"
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: true
                                color: Colors.overBackground
                            }
                        }
                    }

                    // Sunset
                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: Styling.radius(2)
                        variant: "pane"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: Icons.moon
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: Colors.tertiary
                            }

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                text: WeatherService.sunset || "—"
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: true
                                color: Colors.overBackground
                            }
                        }
                    }
                }
            }
        }

        // Section: 7-Day Forecast
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            text: "FORECAST"
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            font.bold: true
            color: Colors.overSurfaceVariant
            Layout.leftMargin: 4
        }

        // Forecast Cards Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: (WeatherService.forecast && WeatherService.forecast.length > 0) ? WeatherService.forecast.slice(0, 5) : []

                StyledRect {
                    id: forecastCard
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 88
                    radius: Styling.radius(2)
                    variant: "internalbg"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: forecastCard.modelData.dayName || ""
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.bold: true
                            color: Colors.overBackground
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: forecastCard.modelData.emoji || "☀️"
                            font.family: Config.theme.font
                            font.pixelSize: 18
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: Math.round(forecastCard.modelData.maxTemp) + "°"
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(-2)
                            font.bold: true
                            color: Colors.overBackground
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: Math.round(forecastCard.modelData.minTemp) + "°"
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.overSurfaceVariant
                        }
                    }
                }
            }
        }
    }
}
