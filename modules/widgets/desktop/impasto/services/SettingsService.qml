pragma Singleton

import QtQuick
import Quickshell
import qs.config

Singleton {
    readonly property string desktopTheme: Config.desktop.theme
    readonly property bool widgetShadow: Config.desktop.widgetShadow
    readonly property bool clockShowsSeconds: Config.desktop.clockShowsSeconds
    readonly property string clockFormat: Config.bar.use12hFormat ? "h:mm" : "HH:mm"
    readonly property string githubUser: Config.desktop.githubUser
    readonly property string petStyle: Config.desktop.petStyle

    // The local settings model has no date-display toggle; upstream defaults it off.
    readonly property bool clockShowsDate: false
    readonly property string language: "en"
    readonly property bool lyrics: true
}
