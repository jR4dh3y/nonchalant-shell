// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G A M E   B O A R D                                                    │
// │   loads a game by id and gives it the keyboard                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.details.games
import qs.modules.services.desktop

// Registry of the games: an id in, a board out, given its tint and the
// keyboard.
//
// ── CONTRACT ────────────────────────────────────────────────────────────────
//
// Every game is a `FocusScope` that fills its parent and declares:
//
//   property int score         current score
//   property bool over         the round has ended
//   property color tint        colour passed in from here
//   signal finished(int score) once, when the round ends
//   function restart()         new round, resets `over`
//
// A game draws only its board, in `Theme` tokens. The frame draws the score
// strip, the best, the game-over overlay and the restart button. Escape is
// handled by the panel, not the game.
//
// A new game needs a file here, a row in `GamesService.catalogue`, and a row
// below.
Item {
    id: root

    property string gameId: ""
    property color tint: Theme.accent

    readonly property var game: holder.item

    // Create the board as soon as its detail view has a real size.
    readonly property var entry: GamesService.entry(root.gameId)
    readonly property bool roomy: root.entry !== null && root.width > 0 && root.height > 0

    readonly property var components: ({
        whack: whackGame,
        snake: snakeGame,
        flood: floodGame,
        mini2048: mini2048Game,
        lights: lightsGame,
        hextris: hextrisGame,
        bots: botsGame,
        target: targetGame,
        space: spaceGame,
        tetris: tetrisGame,
        solitaire: solitaireGame
    })

    Loader {
        id: holder

        anchors.fill: parent
        focus: true
        active: root.roomy
        sourceComponent: root.components[root.gameId] ?? null

        // `focus: true` isn't enough: the Loader is a focus scope and the Item
        // above it isn't, so the game ends up without active focus.
        // forceActiveFocus() sets every scope up to the window.
        onLoaded: holder.item.forceActiveFocus()
    }

    Component { id: whackGame; Whack { tint: root.tint } }
    Component { id: snakeGame; Snake { tint: root.tint } }
    Component { id: floodGame; Flood { tint: root.tint } }
    Component { id: mini2048Game; Mini2048 { tint: root.tint } }
    Component { id: lightsGame; Lights { tint: root.tint } }
    Component { id: hextrisGame; Hextris { tint: root.tint } }
    Component { id: botsGame; Bots { tint: root.tint } }
    Component { id: targetGame; Target { tint: root.tint } }
    Component { id: spaceGame; Space { tint: root.tint } }
    Component { id: tetrisGame; Tetris { tint: root.tint } }
    Component { id: solitaireGame; Solitaire { tint: root.tint } }
}
