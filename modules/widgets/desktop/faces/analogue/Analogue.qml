pragma ComponentBehavior: Bound

import QtQuick
import "../../visual"

Item {
    id: root

    property string moduleId: ""
    property string family: "2x2"
    property var ink
    property var row: null
    property bool active: false

    readonly property list<string> modules: [
        "battery", "volume", "brightness", "network", "bluetooth", "updates",
        "weather", "github", "stats", "claude", "codex", "timer", "pet",
        "games", "media", "clock", "calendar", "tasks"
    ]

    Loader {
        anchors.fill: parent
        active: root.visible && root.modules.includes(root.moduleId)
        sourceComponent: face
    }

    Component {
        id: face
        AnalogueFace {
            anchors.fill: parent
            moduleId: root.moduleId
            family: root.family
            ink: root.ink
            row: root.row
            active: root.active
        }
    }
}