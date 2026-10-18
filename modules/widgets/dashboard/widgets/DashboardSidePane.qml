pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.bar.island
import qs.modules.components
import qs.modules.theme

Item {
    id: root
    objectName: "dashboardSidePane"

    property string section: "notifications"
    property string screenName: ""
    readonly property real minimumWidth: Styling.fontSize(0) * 26
    implicitWidth: Math.max(minimumWidth, section === "stats"
        ? (statsSection.item?.implicitWidth ?? 0)
        : section === "wallpapers" ? (wallpapers.item?.implicitWidth ?? 0) : 0)
    clip: true

    function focusCurrentSection(): void {
        root.forceActiveFocus();
    }

    component SectionLoader: Loader {
        id: sectionLoader
        required property bool selected
        anchors.fill: parent
        active: selected || opacity > 0
        visible: opacity > 0
        enabled: selected
        opacity: selected ? 1 : 0
        z: selected ? 1 : 0
        transform: Translate { x: (1 - sectionLoader.opacity) * Motion.drift }

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.fadeInDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    SectionLoader {
        objectName: "dashboardNotificationsSection"
        selected: root.section === "notifications"
        active: root.section !== ""
        sourceComponent: NotificationHistory {}
    }

    SectionLoader {
        id: statsSection
        objectName: "dashboardStatsSection"
        selected: root.section === "stats"
        sourceComponent: StyledRect {
            variant: "pane"
            radius: Styling.radius(4)
            implicitWidth: stats.implicitWidth

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: stats.implicitHeight
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                IslandStatsPanel {
                    id: stats
                    width: parent.width
                    height: implicitHeight
                }
            }
        }
    }

    SectionLoader {
        id: wallpapers
        objectName: "dashboardWallpapersSection"
        selected: root.section === "wallpapers"
        sourceComponent: StyledRect {
            variant: "pane"
            radius: Styling.radius(4)
            implicitWidth: wallpaperPanel.implicitWidth

            IslandWallpaperPanel {
                id: wallpaperPanel
                anchors.fill: parent
                compact: width < implicitWidth
                screen: Quickshell.screens.find(screen => screen.name === root.screenName) ?? null
            }
        }
    }

    SectionLoader {
        objectName: "dashboardWeatherSection"
        selected: root.section === "weather"
        sourceComponent: StyledRect {
            variant: "pane"
            radius: Styling.radius(4)

            Flickable {
                id: weatherViewport
                anchors.fill: parent
                contentWidth: width
                contentHeight: weather.height
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                IslandWeatherPanel {
                    id: weather
                    width: parent.width
                    height: Math.max(implicitHeight, weatherViewport.height)
                    showHeader: false
                    fillSky: true
                }
            }
        }
    }
}
