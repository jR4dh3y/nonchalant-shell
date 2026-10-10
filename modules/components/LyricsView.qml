pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    property string mode: "compact"
    property bool lyricsEnabled: Config.bar.lyricsEnabled
    property bool active: false
    property bool subscribed: false

    implicitHeight: root.mode === "detail" ? 140 : 22
    readonly property bool shouldRender: root.active && root.visible
        && root.width > 0 && root.height > 0

    readonly property bool hasTrack: MprisController.activePlayer !== null
        && MprisController.trackTitle.trim() !== ""
    readonly property string statusText: {
        if (!root.lyricsEnabled)
            return "Lyrics are off";
        if (!root.hasTrack)
            return "Nothing playing";
        switch (LyricsService.status) {
        case "loading": return "Looking for lyrics";
        case "network": return "Network unavailable · retrying";
        case "missing": return "No lyrics for this track";
        case "instrumental": return "Instrumental";
        case "plain": return "Lyrics, untimed";
        case "timed": return "";
        default: return "Looking for lyrics";
        }
    }
    readonly property string compactText: {
        if (!root.lyricsEnabled || !root.hasTrack || !LyricsService.available)
            return root.statusText;
        if (LyricsService.instrumental)
            return "Instrumental";
        if (LyricsService.synced)
            return LyricsService.currentText || "♪";
        return "Lyrics, untimed";
    }

    function syncSubscription(): void {
        const shouldSubscribe = root.shouldRender && root.lyricsEnabled;
        if (shouldSubscribe === root.subscribed)
            return;
        root.subscribed = shouldSubscribe;
        if (shouldSubscribe)
            LyricsService.subscribe();
        else
            LyricsService.release();
    }

    onShouldRenderChanged: root.syncSubscription()
    onLyricsEnabledChanged: root.syncSubscription()
    Component.onCompleted: root.syncSubscription()
    Component.onDestruction: {
        if (root.subscribed)
            LyricsService.release();
    }

    Text {
        anchors.fill: parent
        visible: root.shouldRender && root.mode === "compact"
        text: root.compactText
        textFormat: Text.PlainText
        color: root.lyricsEnabled && LyricsService.available && LyricsService.synced
            && LyricsService.current >= 0 ? Colors.primary : Colors.overSurfaceVariant
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        font.weight: Font.DemiBold
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        anchors.centerIn: parent
        width: parent.width
        visible: root.shouldRender && root.mode === "detail"
            && (!root.lyricsEnabled || !LyricsService.available || LyricsService.instrumental)
        text: root.statusText
        color: Colors.overSurfaceVariant
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(1)
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
    }

    FontMetrics {
        id: lyricFontMetrics
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(1)
        font.weight: Font.DemiBold
    }

    ListView {
        id: lyricLines
        anchors.fill: parent
        visible: root.shouldRender && root.mode === "detail" && root.lyricsEnabled
            && LyricsService.available && !LyricsService.instrumental
        clip: true
        model: visible ? LyricsService.lines : []
        spacing: 8
        interactive: !LyricsService.synced
        currentIndex: visible && LyricsService.synced && count > 0
            ? Math.min(LyricsService.current, count - 1) : -1
        highlightRangeMode: LyricsService.synced
            ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        // Strict range enforcement can change currentItem; do not size the range from it.
        preferredHighlightBegin: Math.max(0, (height - lyricFontMetrics.height) / 2)
        preferredHighlightEnd: Math.min(height,
            preferredHighlightBegin + lyricFontMetrics.height)
        highlightMoveDuration: Config.animDuration
        highlightFollowsCurrentItem: true
        header: Item {
            width: 1
            height: LyricsService.synced ? 0 : lyricLines.height / 3
        }
        footer: Item {
            width: 1
            height: lyricLines.height / 3
        }

        delegate: Item {
            id: lyricLine
            required property var modelData
            required property int index

            readonly property bool seekable: LyricsService.synced
                && (MprisController.activePlayer?.canSeek ?? false)
                && Number(lyricLine.modelData.t) >= 0

            activeFocusOnTab: seekable
            Accessible.role: seekable ? Accessible.Button : Accessible.StaticText
            Accessible.name: lineText.text
            Accessible.description: seekable ? "Seek to this lyric" : ""
            Accessible.onPressAction: {
                if (lyricLine.seekable)
                    LyricsService.seekTo(Number(lyricLine.modelData.t));
            }
            Keys.onReturnPressed: event => {
                if (lyricLine.seekable) {
                    LyricsService.seekTo(Number(lyricLine.modelData.t));
                    event.accepted = true;
                }
            }
            Keys.onSpacePressed: event => {
                if (lyricLine.seekable) {
                    LyricsService.seekTo(Number(lyricLine.modelData.t));
                    event.accepted = true;
                }
            }
            readonly property int distance: LyricsService.current < 0
                ? lyricLine.index + 1
                : Math.abs(lyricLine.index - LyricsService.current)

            width: lyricLines.width
            implicitHeight: lineText.implicitHeight

            Text {
                id: lineText
                anchors.fill: parent
                text: lyricLine.modelData.text !== "" ? lyricLine.modelData.text : "♪"
                textFormat: Text.PlainText
                color: lyricLine.distance === 0 ? Colors.primary : Colors.overBackground
                opacity: !LyricsService.synced || lyricLine.distance === 0
                    ? 1 : Math.max(0.24, 0.56 - 0.1 * lyricLine.distance)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.weight: Font.DemiBold
                font.underline: lyricLine.activeFocus
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
                anchors.fill: parent
                enabled: lyricLine.seekable
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    lyricLine.forceActiveFocus();
                    LyricsService.seekTo(Number(lyricLine.modelData.t));
                }
            }
        }
    }
}
