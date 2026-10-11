pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.services as Nonchalant

Singleton {
    readonly property MprisPlayer active: {
        const player = Nonchalant.MprisController.activePlayer
        return player && (player.isPlaying || (player.trackTitle ?? "") !== "") ? player : null
    }
    readonly property bool available: active !== null
    readonly property bool playing: available && active.isPlaying
    readonly property string title: available ? (active.trackTitle ?? "") : ""
    readonly property string artist: available ? Nonchalant.MprisController.trackArtists : ""
    readonly property string album: available ? (active.trackAlbum ?? "") : ""
    readonly property string artUrl: available ? (active.trackArtUrl ?? "") : ""
    readonly property string identity: available ? (active.identity ?? "") : ""
    readonly property bool canNext: available && active.canGoNext
    readonly property bool canPrevious: available && active.canGoPrevious
    readonly property bool canToggle: available && active.canTogglePlaying
    readonly property bool canSeek: available && active.canSeek && length > 0
    readonly property real length: available ? Nonchalant.MprisController.length : 0
    readonly property real position: available ? Nonchalant.MprisController.position : 0
    readonly property bool seekable: length > 0
    readonly property real progress: seekable
        ? Math.max(0, Math.min(1, position / length)) : 0

    function toggle(): void { Nonchalant.MprisController.togglePlaying() }
    function previous(): void { Nonchalant.MprisController.previous() }
    function next(): void { Nonchalant.MprisController.next() }
    function seek(fraction: real): void {
        if (canSeek)
            active.position = Math.max(0, Math.min(1, fraction)) * length
    }
}
