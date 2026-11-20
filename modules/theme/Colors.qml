pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

ShellPalette {
    id: colors

    // QUICKSHELL-GIT: path: Quickshell.cachePath("colors.json")
    path: Quickshell.env("HOME") + "/.cache/nonchalant/colors.json"
    onFileChanged: generationTimer.restart()
    // Niri's include is a cache file, so write it once at startup as well as
    // on palette changes. onLoaded also fires after every reload(), which
    // generationTimer already covers, so only the first load writes here.
    // A missing or unreadable colors.json still writes from the fallback colors.
    property bool niriStartupWritten: false
    function writeNiriAtStartup(): void {
        if (colors.niriStartupWritten)
            return;
        colors.niriStartupWritten = true;
        niriGenerator.generate(colors);
    }
    onLoaded: writeNiriAtStartup()
    onLoadFailed: writeNiriAtStartup()

    property Connections oledWatcher: Connections {
        id: oledWatcher
        target: Config
        function onOledModeChanged() {
            generationTimer.restart();
        }
    }

    property Connections themeWatcher: Connections {
        id: themeWatcher
        target: Config.loader
        function onFileChanged() {
            generationTimer.restart();
        }
    }

    property QtCtGenerator qtCtGenerator: QtCtGenerator {
        id: qtCtGenerator
    }

    property GtkGenerator gtkGenerator: GtkGenerator {
        id: gtkGenerator
    }

    property PywalGenerator pywalGenerator: PywalGenerator {
        id: pywalGenerator
    }

    property KittyGenerator kittyGenerator: KittyGenerator {
        id: kittyGenerator
    }

    property NvChadGenerator nvChadGenerator: NvChadGenerator {
        id: nvChadGenerator
    }

    property DiscordGenerator discordGenerator: DiscordGenerator {
        id: discordGenerator
    }

    property NiriGenerator niriGenerator: NiriGenerator {
        id: niriGenerator
    }

    property Timer generationTimer: Timer {
        id: generationTimer
        interval: 100
        repeat: false
        onTriggered: {
            qtCtGenerator.generate(colors);
            gtkGenerator.generate(colors);
            pywalGenerator.generate(colors);
            kittyGenerator.generate(colors);
            nvChadGenerator.generate(colors);
            discordGenerator.generate(colors);
            niriGenerator.generate(colors);
        }
    }
}
