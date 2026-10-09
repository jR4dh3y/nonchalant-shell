pragma ComponentBehavior: Bound

import QtQuick

import "../visual"

Item {
    id: root

    property string moduleId: ""
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
        sourceComponent: widget
    }

    Component {
        id: widget
        WidgetFace {
            anchors.fill: parent
            moduleId: root.moduleId
            family: "2x2"
            ink: root.ink
            row: root.row
            active: root.active
        }
    }
}