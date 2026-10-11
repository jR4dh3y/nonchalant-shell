// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P   A   P   E   R                                                      │
// │   paper background tinted from the text colour                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme

// Paper for calendar leaves, a watch's date window and parcel labels: the text
// colour under the notes' wash, written on in the notes' ink.
Item {
    id: root

    property var ink
    property real radius: Theme.paperRadius

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.ink.text
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.paperWash
    }
}
