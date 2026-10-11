// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O D U L E                                                            │
// │   maps a module id to its component                                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// Maps a module id to its component, so the bar, the island and the services
// pass ids around as strings.
//
// This desktop fallback only needs the offered games detail. Other offered
// modules have their own family face.
Item {
    id: root

    property string moduleId: ""
    property bool compact: false
    property var row: null

    readonly property var components: ({
        games: gamesModule
    })

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        active: root.moduleId !== ""
        sourceComponent: root.components[root.moduleId] ?? null
    }

    Component { id: gamesModule; GamesModule { row: root.row } }
}
