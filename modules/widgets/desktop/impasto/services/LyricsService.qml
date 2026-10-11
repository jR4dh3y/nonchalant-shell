pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services as Nonchalant
import "."

Singleton {
    id: root
    readonly property bool available: SettingsService.lyrics
        && Nonchalant.LyricsService.available
    readonly property bool hasTrack: Nonchalant.LyricsService.hasTrack
    readonly property bool synced: Nonchalant.LyricsService.synced
    readonly property bool instrumental: Nonchalant.LyricsService.instrumental
    readonly property int current: Nonchalant.LyricsService.current
    readonly property string currentText: Nonchalant.LyricsService.currentText
    readonly property string nextText: Nonchalant.LyricsService.nextText
    readonly property list<var> lines: Nonchalant.LyricsService.lines
    readonly property bool loading: Nonchalant.LyricsService.status === "loading"
    readonly property string status: {
        if (!SettingsService.lyrics)
            return "Lyrics are off"
        if (!root.hasTrack)
            return "Nothing playing"
        switch (Nonchalant.LyricsService.status) {
        case "loading": return "Looking for lyrics"
        case "network":
        case "missing": return "No lyrics for this one"
        case "instrumental": return "Instrumental"
        case "plain": return "Lyrics, untimed"
        case "timed": return ""
        default: return ""
        }
    }

    function subscribe(): void { Nonchalant.LyricsService.subscribe() }
    function release(): void { Nonchalant.LyricsService.release() }
    function seekTo(seconds: real): bool { return Nonchalant.LyricsService.seekTo(seconds) }
}
