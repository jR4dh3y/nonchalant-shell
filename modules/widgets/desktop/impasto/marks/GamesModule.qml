// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G A M E S   M O D U L E                                                │
// │   arcade · best scores when open                                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services
import qs.modules.widgets.desktop.impasto.components

// Recent games with their bests and a button that opens the arcade. Games need
// keyboard focus, which the resting island doesn't hold, so none runs here.
Item {
    id: root

    property var row: null

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    readonly property string last: GamesService.lastPlayed
    readonly property var lastEntry: GamesService.entry(root.last)

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        ModuleCard {
            title: "Games"
            subtitle: GamesService.totalPlays === 0
                ? "Nothing played yet"
                : `${GamesService.totalPlays} ${GamesService.totalPlays === 1 ? "round" : "rounds"}`
                    + ` · ${GamesService.catalogue.length} ${GamesService.catalogue.length === 1 ? "game" : "games"}`

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: 0
                trackColor: Theme.indicatorDim

                Text {
                    anchors.centerIn: parent
                    text: "󰊗"
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    color: Theme.indicator
                }
            }

            // The last three, most recent first, with their bests.
            Repeater {
                model: ScriptModel {
                    values: GamesService.ranked.slice(0, 3)
                }

                RowLayout {
                    id: row

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.cardRow
                    spacing: 10

                    Text {
                        Layout.preferredWidth: 16
                        horizontalAlignment: Text.AlignHCenter
                        text: row.modelData.icon
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeRegular
                        color: GamesService.tintOf(row.modelData.id)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }

                    Text {
                        text: `${GamesService.bestOf(row.modelData.id)} ${row.modelData.unit}`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.cardRow

                Item { Layout.fillWidth: true }

                PillButton {
                    implicitHeight: Theme.cardRow
                    text: "Play"
                    icon: "󰐊"
                    onClicked: ModuleService.requestPanel("games", root.row)
                }
            }
        }
    }
}
