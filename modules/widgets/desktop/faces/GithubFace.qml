// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G   I   T   H   U   B       F   A   C   E                              │
// │   the contribution wall on the wallpaper · modern                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services
import qs.modules.widgets.desktop.impasto.components

// The contribution wall and nothing else, with no caption or logo; the count
// and the streak are in the island's detail and on the bar chip.
//
// The cell size is fixed (ContributionGrid derives it from the height, which
// the families share), so a wider face shows more weeks rather than smaller
// cells. Green and grey in every palette; `ink` is only here to match the
// registry's interface.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property string family: "2x2"

    ContributionGrid {
        anchors.fill: parent
        anchors.margins: 12
        visible: GithubService.available

        weeks: GithubService.weeks
        spacing: 3
        radius: 2.5
        maxCell: 24
    }

    // Says why the wall is empty: no user set, or GitHub unreachable.
    Text {
        anchors.centerIn: parent
        width: parent.width - 24
        visible: !GithubService.available
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: SettingsService.githubUser.trim() === "" ? "No GitHub user set" : "GitHub is out of reach"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: root.ink.muted
    }
}
