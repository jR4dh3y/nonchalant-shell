pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.globals
import qs.modules.components
import qs.modules.theme
import qs.modules.bar.island
import qs.modules.services

Item {
    id: root

    property string screenName: ""
    signal closeRequested()
    readonly property real mediaCardSize: Math.min(Styling.fontSize(0) * 22,
        Math.max(0, (root.width - dashboardColumn.spacing) / 2))
    implicitWidth: dashboard.implicitWidth + dashboard.anchors.margins * 2
    implicitHeight: dashboardColumn.implicitHeight

    function focusCurrentTab(): void {
        dashboard.focusCurrentTab();
    }

    ColumnLayout {
        id: dashboardColumn
        anchors.fill: parent
        spacing: 8

        RowLayout {
            objectName: "dashboardMediaRow"
            Layout.preferredWidth: root.mediaCardSize * 2 + spacing
            Layout.alignment: Qt.AlignLeft
            Layout.minimumHeight: root.mediaCardSize
            Layout.maximumHeight: root.mediaCardSize
            Layout.preferredHeight: root.mediaCardSize
            spacing: dashboardColumn.spacing

            IslandMediaCard {
                id: mediaCard
                objectName: "dashboardMediaCard"
                Layout.preferredWidth: root.mediaCardSize
                Layout.fillHeight: true
                squareArtwork: true
                showLyrics: false
                onExpandRequested: GlobalShortcuts.run("media")
            }

            StyledRect {
                variant: "pane"
                radius: Styling.radius(2)
                Layout.preferredWidth: root.mediaCardSize
                Layout.fillHeight: true

                LyricsView {
                    objectName: "dashboardLyrics"
                    anchors.fill: parent
                    anchors.margins: 12
                    mode: "detail"
                    active: root.visible && GlobalStates.dashboardPopupScreen === root.screenName
                }
            }
        }

        StyledRect {
            variant: "pane"
            radius: Styling.radius(4)
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: dashboard.implicitHeight + 16
            Layout.preferredHeight: implicitHeight

            DashboardView {
                id: dashboard
                anchors.fill: parent
                anchors.margins: 8
                screenName: root.screenName
                popupMode: true
                onCloseRequested: root.closeRequested()
            }
        }
    }
}
