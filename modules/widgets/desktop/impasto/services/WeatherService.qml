pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services as Nonchalant

Singleton {
    readonly property bool available: Nonchalant.WeatherService.dataAvailable
    readonly property int temperature: Math.round(Nonchalant.WeatherService.currentTemp)
    readonly property real feelsLike: Nonchalant.WeatherService.feelsLike
    readonly property int high: Math.round(Nonchalant.WeatherService.maxTemp)
    readonly property int low: Math.round(Nonchalant.WeatherService.minTemp)
    readonly property string place: Nonchalant.WeatherService.resolvedLocation
    readonly property string description: Nonchalant.WeatherService.weatherDescription
    readonly property string glyph: Nonchalant.WeatherService.weatherGlyph
    readonly property var hourly: Nonchalant.WeatherService.hourly
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: Nonchalant.WeatherService.watchers > 0
    }

    function subscribe(): void { Nonchalant.WeatherService.subscribe() }
    function release(): void { Nonchalant.WeatherService.release() }
}
