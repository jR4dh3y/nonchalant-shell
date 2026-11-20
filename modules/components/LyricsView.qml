pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.services
import qs.modules.theme

Item {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)

    property string mode: "compact"
    property bool lyricsEnabled: Config.bar?.lyricsEnabled ?? true
    property bool active: false
    property bool collapseWhenEmpty: false
    property bool subscribed: false

    readonly property bool hasTrack: MprisController.activePlayer !== null
        && MprisController.trackTitle.trim() !== ""
    readonly property bool shouldSubscribe: root.lyricsEnabled && root.active
        && (root.collapseWhenEmpty || root.shouldRender)
    readonly property bool shouldRender: root.active && root.visible && root.width > 0 && root.height > 0
    readonly property string statusText: {
        if (!root.lyricsEnabled) return "Lyrics are off";
        if (!root.hasTrack) return "Nothing playing";
        switch (LyricsService.status) {
        case "network": return "Network unavailable · retrying";
        case "missing": return "No lyrics for this track";
        case "instrumental": return "Instrumental";
        case "plain": return "Lyrics, untimed";
        case "timed": return "";
        default: return "Looking for lyrics";
        }
    }
    readonly property string compactText: root.lyricsEnabled && root.hasTrack && LyricsService.available && LyricsService.synced
        ? LyricsService.currentText : root.statusText
    readonly property bool isMusicInterlude: root.shouldRender && root.lyricsEnabled && root.hasTrack && LyricsService.available
        && (LyricsService.instrumental || (LyricsService.synced && root.compactText.trim() === ""))
    readonly property int displayIndex: LyricsService.synced && LyricsService.lines.length > 0
        ? Math.max(0, Math.min(LyricsService.current >= 0 ? LyricsService.current : LyricsService.timelineIndex, LyricsService.lines.length - 1)) : -1

    implicitWidth: 200
    implicitHeight: root.mode === "compact" ? 22
        : Math.max(140, detailListLoader.item?.currentItem?.implicitHeight ?? 0)
    visible: !root.collapseWhenEmpty || (root.hasTrack && root.lyricsEnabled && LyricsService.available)
    clip: true

    property real phase: 0
    readonly property real currentPlaybackPosition: LyricsService.playbackPosition

    NumberAnimation on phase {
        from: 0
        to: Math.PI * 20
        duration: Math.PI * 20 / 2.5 * 1000
        loops: Animation.Infinite
        running: root.shouldSubscribe && root.shouldRender && LyricsService.available
            && (LyricsService.synced || LyricsService.instrumental)
        paused: running && !MprisController.isPlaying
        easing.type: Easing.Linear
        // All shader phase multipliers are periodic over 20π.
    }

    function lineEnd(index: int): real {
        const line = LyricsService.lines[index];
        if (!line) return 0;
        if (line.end >= 0) return line.end;
        const next = LyricsService.lines[index + 1];
        if (next) return next.t;
        return MprisController.length > line.t ? MprisController.length : line.t;
    }

    function lineProgress(index: int): real {
        const line = LyricsService.lines[index];
        if (!LyricsService.synced || !line) return 0;
        const span = root.lineEnd(index) - line.t;
        return span > 0 ? Math.max(0, Math.min(1, (root.currentPlaybackPosition - line.t) / span)) : 0;
    }

    function characterProgress(index: int): real {
        const line = LyricsService.lines[index];
        if (!LyricsService.synced || !line) return 0;
        const position = root.currentPlaybackPosition;
        if (!line.words?.length)
            return root.lineProgress(index) * line.text.length;
        let completed = 0;
        for (const word of line.words) {
            if (position < word.t)
                return completed;
            if (position < word.end)
                return word.start + word.length * (position - word.t) / (word.end - word.t);
            completed = word.start + word.length;
        }
        return line.text.length;
    }

    function interludeProgress(): real {
        return LyricsService.instrumental ? MprisController.progress : root.lineProgress(root.displayIndex);
    }

    function syncSubscription(): void {
        if (root.shouldSubscribe === root.subscribed) return;
        root.subscribed = root.shouldSubscribe;
        if (root.subscribed) LyricsService.subscribe();
        else LyricsService.release();
    }

    onShouldSubscribeChanged: root.syncSubscription()
    Component.onCompleted: root.syncSubscription()
    Component.onDestruction: {
        if (root.subscribed) LyricsService.release();
    }

    Item {
        id: compactContent
        anchors.fill: parent
        visible: root.shouldRender && root.mode === "compact"

        readonly property string cueKey: visible && LyricsService.available && LyricsService.synced
            ? LyricsService.track + "\n" + LyricsService.current : ""
        property string previousTrack: ""
        property int previousIndex: -1
        property real entryOffset: 0

        // Long lyrics travel left as their words fill. Each following cue starts
        // on the right instead of inheriting the outgoing lyric's scroll offset.
        function advanceCue(): void {
            const index = cueKey !== "" ? LyricsService.current : -1;
            const track = cueKey !== "" ? LyricsService.track : "";
            const nextCue = track === previousTrack && previousIndex >= 0
                && index === previousIndex + 1 && MprisController.isPlaying;
            previousTrack = track;
            previousIndex = index;
            cueEntrance.stop();
            entryOffset = 0;
            if (nextCue && Motion.enabled)
                cueEntrance.start();
        }

        onCueKeyChanged: Qt.callLater(advanceCue)
        transform: Translate { x: compactContent.entryOffset }
        NumberAnimation {
            id: cueEntrance
            target: compactContent
            property: "entryOffset"
            from: root.width
            to: 0
            duration: Config.animDuration
            easing.type: Easing.OutQuad
        }

        FluidLyricsText {
            id: compactLine
            objectName: "compactLyricText"
            visible: root.shouldRender && root.mode === "compact" && !root.isMusicInterlude
            FontMetrics {
                id: compactFontMetrics
                font: compactLine.font
            }
            readonly property real textAdvance: Math.ceil(compactFontMetrics.advanceWidth(root.compactText)) + 1
            width: Math.max(1, LyricsService.synced ? textAdvance : root.width)
            height: root.height
            text: root.mode === "compact" ? root.compactText : ""
            Accessible.name: root.compactText
            font.pixelSize: Styling.fontSize(-1)
            wrapMode: TextEdit.NoWrap
            horizontalAlignment: width > root.width ? TextEdit.AlignLeft : TextEdit.AlignHCenter
            characterProgress: fluidEnabled ? root.characterProgress(LyricsService.current) : 0
            playing: MprisController.isPlaying
            progressDuration: LyricsService.positionInterval
            phase: fluidEnabled ? root.phase : 0
            fluidEnabled: visible && root.mode === "compact" && root.shouldRender && root.lyricsEnabled && LyricsService.available && LyricsService.synced && LyricsService.current >= 0
            x: {
                if (width <= root.width) return (root.width - width) / 2;
                return Math.max(root.width - width, Math.min(0, root.width / 2 - fillCursor.x));
            }
        }

        LyricsInterlude {
            objectName: "compactInterlude"
            anchors.centerIn: parent
            visible: root.shouldRender && root.mode === "compact" && root.isMusicInterlude
            progress: visible ? root.interludeProgress() : 0
            phase: playing ? root.phase : 0
            playing: visible && MprisController.isPlaying
        }
    }

    Text {
        anchors.centerIn: parent
        width: parent.width
        visible: root.shouldRender && root.mode === "detail"
            && (!root.lyricsEnabled || !LyricsService.available)
        text: root.statusText
        color: root.shellPalette.overSurfaceVariant
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(1)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
    }

    LyricsInterlude {
        objectName: "instrumentalInterlude"
        anchors.centerIn: parent
        visible: root.shouldRender && root.mode === "detail" && LyricsService.available && LyricsService.instrumental
        progress: visible ? root.interludeProgress() : 0
        phase: playing ? root.phase : 0
        playing: visible && MprisController.isPlaying
    }

    Loader {
        id: detailListLoader
        anchors.fill: parent
        // Cue measurement must not depend on the height it supplies to the layout.
        active: root.active && root.visible && root.mode === "detail" && root.lyricsEnabled
            && LyricsService.available && !LyricsService.instrumental
        sourceComponent: ListView {
            id: lyricLines
            objectName: "lyricLines"
            anchors.fill: parent
            clip: true
            model: LyricsService.lines
            spacing: Styling.fontSize(-1) * 0.12
            interactive: !LyricsService.synced || (currentItem?.height ?? 0) > height
            currentIndex: root.displayIndex
            highlightRangeMode: ListView.NoHighlightRange
            // Center fitting cues; start oversized cues at the top so they can be scrolled.
            // Range enforcement can change currentIndex, so keep timing authoritative.
            function centerCurrent(): void {
                if (LyricsService.synced && currentItem)
                    contentY = currentItem.y + Math.min(currentItem.height, height) / 2 - height / 2;
            }
            onCurrentItemChanged: Qt.callLater(centerCurrent)
            onHeightChanged: Qt.callLater(centerCurrent)
            onWidthChanged: Qt.callLater(centerCurrent)
            Behavior on contentY {
                enabled: LyricsService.synced
                NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuad }
            }
            header: Item { width: 1; height: LyricsService.synced ? lyricLines.height / 2 : 0 }
            footer: Item { width: 1; height: LyricsService.synced ? lyricLines.height / 2 : 0 }

            delegate: Item {
                id: lyricLine
                required property var modelData
                required property int index
                readonly property int distance: Math.abs(index - root.displayIndex)
                readonly property real restingScale: !LyricsService.synced || distance === 0 ? 1 : (distance === 1 ? 0.84 : 0.72)
                readonly property bool interlude: modelData.text.trim() === ""
                readonly property bool seekable: LyricsService.synced
                    && (MprisController.activePlayer?.canSeek ?? false) && modelData.t >= 0
                // Fade context out before the viewport can slice its glyphs.
                readonly property real viewportMargin: Math.min(y - lyricLines.contentY,
                    lyricLines.contentY + lyricLines.height - y - height)
                    - height * (scale / restingScale - 1) / 2
                readonly property real edgeOpacity: !LyricsService.synced || distance === 0 ? 1
                    : Math.max(0, Math.min(1, viewportMargin / Styling.fontSize(0)))
                property real cueOpacity: !LyricsService.synced || distance === 0 ? 1
                    : (distance === 1 ? 0.3 : (distance === 2 ? 0.12 : 0.04))
                width: lyricLines.width
                implicitHeight: interlude ? marker.implicitHeight : lineText.implicitHeight
                height: implicitHeight * restingScale
                opacity: cueOpacity * edgeOpacity
                scale: restingScale
                onHeightChanged: {
                    if (lyricLine.index === lyricLines.currentIndex)
                        Qt.callLater(lyricLines.centerCurrent);
                }
                onYChanged: {
                    if (lyricLine.index === lyricLines.currentIndex)
                        Qt.callLater(lyricLines.centerCurrent);
                }
                Behavior on cueOpacity { NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuad } }
                Behavior on scale { NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuad } }

                activeFocusOnTab: seekable
                Accessible.role: seekable ? Accessible.Button : Accessible.StaticText
                Accessible.name: interlude ? "Instrumental break" : modelData.text
                Accessible.description: seekable ? "Seek to this lyric" : ""
                Accessible.onPressAction: if (seekable) LyricsService.seekTo(modelData.t)
                Keys.onReturnPressed: event => {
                    if (seekable) { LyricsService.seekTo(modelData.t); event.accepted = true; }
                }
                Keys.onSpacePressed: event => {
                    if (seekable) { LyricsService.seekTo(modelData.t); event.accepted = true; }
                }

                FluidLyricsText {
                    id: lineText
                    objectName: "detailLyricText"
                    width: parent.width
                    y: (parent.height - height) / 2
                    visible: !lyricLine.interlude
                    text: lyricLine.modelData.text
                    font.pixelSize: Styling.fontSize(6)
                    characterProgress: fluidEnabled ? root.characterProgress(lyricLine.index) : 0
                    playing: MprisController.isPlaying
                    progressDuration: LyricsService.positionInterval
                    phase: fluidEnabled ? root.phase : 0
                    fluidEnabled: visible && root.shouldRender && LyricsService.synced && lyricLine.distance === 0
                }
                LyricsInterlude {
                    id: marker
                    objectName: "lineInterlude"
                    anchors.centerIn: parent
                    visible: lyricLine.interlude
                    progress: visible && lyricLine.distance === 0 ? root.lineProgress(lyricLine.index) : 0
                    phase: playing ? root.phase : 0
                    playing: lyricLine.distance === 0 && MprisController.isPlaying
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: lyricLine.seekable
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        lyricLine.forceActiveFocus();
                        LyricsService.seekTo(lyricLine.modelData.t);
                    }
                }
            }
        }
    }
}
