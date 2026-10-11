pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services.desktop
import qs.modules.theme
import qs.config
import qs.modules.widgets.desktop.details.games

FocusScope {
    id: root

    required property var row
    signal closeRequested()

    readonly property string playing: GamesService.playing
    readonly property var game: GamesService.entry(root.playing)
    readonly property real gap: Styling.fontSize(-2)

    Component.onCompleted: root.forceActiveFocus()
    Component.onDestruction: GamesService.leave()

    Keys.onEscapePressed: {
        if (root.playing !== "")
            GamesService.leave()
        else
            root.closeRequested()
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.playing === "" ? shelfPage : gamePage
    }

    Component {
        id: shelfPage

        FocusScope {
            id: shelf
            Component.onCompleted: shelf.forceActiveFocus()

            ColumnLayout {
                anchors.fill: parent
                spacing: root.gap

                GridView {
                    id: gamesGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: Math.max(Styling.fontSize(0) * 13, width / 3)
                    cellHeight: Styling.fontSize(0) * 10
                    model: GamesService.catalogue
                    currentIndex: Math.max(0, GamesService.catalogue.findIndex(item => item.id === GamesService.lastOpened))

                    delegate: Item {
                        id: gameTile
                        required property int index
                        required property var modelData
                        width: gamesGrid.cellWidth - root.gap
                        height: gamesGrid.cellHeight - root.gap

                        StyledRect {
                            anchors.fill: parent
                            variant: gamesGrid.currentIndex === gameTile.index ? "focus" : "common"
                        }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 2 * root.gap
                            spacing: root.gap / 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: gameTile.modelData.icon
                                color: GamesService.tintOf(gameTile.modelData.id)
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(6)
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                text: gameTile.modelData.name
                                color: Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: GamesService.played(gameTile.modelData.id)
                                    ? `Best ${GamesService.bestOf(gameTile.modelData.id)}` : gameTile.modelData.unit
                                color: Colors.overSurfaceVariant
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-3)
                            }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: GamesService.open(gameTile.modelData.id)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: GamesService.lastPlayed !== ""
                            ? `${GamesService.entry(GamesService.lastPlayed).name} · best ${GamesService.bestOf(GamesService.lastPlayed)}`
                            : "Choose a game to play"
                        color: Colors.overSurfaceVariant
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        elide: Text.ElideRight
                    }
                    Text {
                        text: `${GamesService.catalogue.length} games`
                        color: Colors.overSurfaceVariant
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-1)
                    }
                }
            }

            Keys.onLeftPressed: gamesGrid.currentIndex = Math.max(0, gamesGrid.currentIndex - 1)
            Keys.onRightPressed: gamesGrid.currentIndex = Math.min(gamesGrid.count - 1, gamesGrid.currentIndex + 1)
            Keys.onUpPressed: gamesGrid.currentIndex = Math.max(0, gamesGrid.currentIndex - 3)
            Keys.onDownPressed: gamesGrid.currentIndex = Math.min(gamesGrid.count - 1, gamesGrid.currentIndex + 3)
            Keys.onReturnPressed: {
                const item = GamesService.catalogue[gamesGrid.currentIndex]
                if (item)
                    GamesService.open(item.id)
            }
            Keys.onEnterPressed: {
                const item = GamesService.catalogue[gamesGrid.currentIndex]
                if (item)
                    GamesService.open(item.id)
            }
            Keys.onSpacePressed: {
                const item = GamesService.catalogue[gamesGrid.currentIndex]
                if (item)
                    GamesService.open(item.id)
            }
        }
    }

    Component {
        id: gamePage

        ColumnLayout {
            id: round
            property bool beaten: false
            readonly property var played: board.game
            readonly property bool over: round.played ? round.played.over : false
            readonly property int score: round.played ? round.played.score : 0
            readonly property bool byMoves: root.game ? root.game.lower : false

            spacing: root.gap

            function again(): void {
                round.beaten = false
                if (round.played)
                    round.played.restart()
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_R || (round.over && (event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter || event.key === Qt.Key_Space))) {
                    round.again()
                    event.accepted = true
                }
            }

            Connections {
                target: round.played
                function onFinished(score: int): void {
                    round.beaten = GamesService.record(root.playing, score)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: root.game ? root.game.name : "Game"
                    color: Colors.overSurface
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    text: `${round.byMoves ? "Moves" : "Score"} ${round.score}`
                    color: Colors.overSurface
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-1)
                }
                Text {
                    visible: GamesService.played(root.playing)
                    text: `Best ${GamesService.bestOf(root.playing)}`
                    color: Colors.overSurfaceVariant
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-1)
                }
                DetailButton {
                    text: "Shelf"
                    onClicked: GamesService.leave()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GameBoard {
                    id: board
                    anchors.fill: parent
                    gameId: root.playing
                    tint: GamesService.tintOf(root.playing)
                }

                StyledRect {
                    anchors.fill: parent
                    visible: round.over
                    variant: "popup"

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: root.gap
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: round.byMoves ? "Solved" : "Game over"
                            color: Colors.overSurface
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(3)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: round.beaten ? `★ New best · ${round.score}`
                                : `${round.byMoves ? "Moves" : "Score"} ${round.score}`
                            color: round.beaten ? Colors.yellow : Colors.overSurfaceVariant
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.fontSize(0)
                        }
                        DetailButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Play again"
                            highlighted: true
                            onClicked: round.again()
                        }
                    }

                    TapHandler {
                        enabled: round.over
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: round.again()
                    }
                }
            }
        }
    }
}