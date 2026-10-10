pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components
import qs.modules.theme

Item {
    id: root

    property string family: "4x2"
    property var ink
    property bool active: false

    LyricsView {
        anchors.fill: parent
        anchors.margins: root.width > 300 ? Styling.fontSize(4) : Styling.fontSize(1)
        mode: root.family === "4x4" ? "detail" : "compact"
        lyricsEnabled: true
        active: root.active
    }
}
