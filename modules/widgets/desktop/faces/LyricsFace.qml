// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L Y R I C S   F A C E                                                  │
// │   the lyrics of what is playing, and nothing else                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services

// Only the words, the same in every theme: the player is its own widget. On
// a square, a 4×2 and a band the line being sung large, with the next one
// under it where there is room; on a 4×4 the lines running past with the sung
// one held in the middle. With no line to show, the reason, where the line
// would be.
Item {
    id: root

    property string family: "4x2"
    property var ink: DesktopService.inkFor(null)

    property bool active: false
    property bool subscribed: false
    readonly property bool wanted: root.active && root.visible && root.width > 0 && root.height > 0

    readonly property bool large: root.family === "4x4"
    readonly property bool band: root.family === "8x2"
    readonly property bool square: root.family === "2x2"
    readonly property int padding: root.width > 300 ? 22 : 18
    readonly property bool singing: LyricsService.available && LyricsService.synced
        && LyricsService.current >= 0

    function syncSubscription(): void {
        if (root.wanted === root.subscribed)
            return
        root.subscribed = root.wanted
        if (root.subscribed)
            LyricsService.subscribe()
        else
            LyricsService.release()
    }

    onWantedChanged: root.syncSubscription()
    Component.onCompleted: root.syncSubscription()
    Component.onDestruction: {
        if (root.subscribed)
            LyricsService.release()
    }

    // ── THE LINE ────────────────────────────────────────────────────────────

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: root.padding
        visible: !root.large
        spacing: 6

        Text {
            id: sung

            width: parent.width
            text: root.singing
                ? (LyricsService.currentText !== "" ? LyricsService.currentText : "♪")
                : (LyricsService.status !== "" ? Tr.t(LyricsService.status) : "♪")
            wrapMode: Text.Wrap
            maximumLineCount: root.band ? 2 : root.square ? 5 : 3
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: root.band ? 30 : root.square ? 18 : 24
            font.weight: Font.Bold
            color: root.singing ? root.ink.text : root.ink.muted

            onTextChanged: turn.restart()

            NumberAnimation {
                id: turn
                target: sung
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.durationMedium
                easing.type: Theme.easing
            }
        }

        Text {
            width: parent.width
            visible: text !== "" && !root.square
            text: root.singing ? LyricsService.nextText : ""
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: root.band ? Theme.fontSizeLarge : Theme.fontSizeMedium
            font.weight: Font.DemiBold
            color: root.ink.muted
        }
    }

    // ── THE LINES ───────────────────────────────────────────────────────────

    Text {
        anchors.centerIn: lines
        width: lines.width
        visible: root.large && (!LyricsService.available || LyricsService.instrumental)
        text: Tr.t(LyricsService.status)
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pixelSize: 22
        font.weight: Font.Bold
        color: root.ink.muted
    }

    ListView {
        id: lines

        anchors.fill: parent
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        visible: root.large && LyricsService.available && !LyricsService.instrumental
        model: root.large ? LyricsService.lines : []
        spacing: 10
        interactive: !LyricsService.synced
        currentIndex: LyricsService.synced ? LyricsService.current : -1
        highlightRangeMode: LyricsService.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        preferredHighlightBegin: height / 2 - 16
        preferredHighlightEnd: height / 2 + 16
        highlightMoveDuration: Theme.durationMorph
        header: Item { width: 1; height: LyricsService.synced ? lines.height / 2 : root.padding }
        footer: Item { width: 1; height: lines.height / 2 }

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fade
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        delegate: Text {
            id: verse

            required property var modelData
            required property int index

            readonly property bool seekable: LyricsService.synced && MediaService.canSeek
                && Number(verse.modelData.t) >= 0
            activeFocusOnTab: verse.seekable
            Accessible.role: verse.seekable ? Accessible.Button : Accessible.StaticText
            Accessible.name: verse.text
            Accessible.description: verse.seekable ? "Seek to this lyric" : ""
            Accessible.onPressAction: if (verse.seekable) LyricsService.seekTo(Number(verse.modelData.t))
            Keys.onReturnPressed: event => {
                if (verse.seekable) {
                    LyricsService.seekTo(Number(verse.modelData.t))
                    event.accepted = true
                }
            }
            Keys.onSpacePressed: event => {
                if (verse.seekable) {
                    LyricsService.seekTo(Number(verse.modelData.t))
                    event.accepted = true
                }
            }
            HoverHandler { cursorShape: verse.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler {
                enabled: verse.seekable
                onTapped: {
                    verse.forceActiveFocus()
                    LyricsService.seekTo(Number(verse.modelData.t))
                }
            }

            readonly property int away: LyricsService.current < 0
                ? (LyricsService.synced ? verse.index + 1 : 1)
                : Math.abs(verse.index - LyricsService.current)

            width: lines.width
            text: verse.modelData.text !== "" ? verse.modelData.text : "♪"
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: 21
            font.weight: Font.Bold
            color: root.ink.text
            opacity: verse.away === 0 ? 1 : Math.max(0.2, 0.45 - 0.1 * (verse.away - 1))

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
            }
        }
    }

    Rectangle {
        id: fade

        anchors.fill: lines
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.2; color: "white" }
            GradientStop { position: 0.8; color: "white" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
