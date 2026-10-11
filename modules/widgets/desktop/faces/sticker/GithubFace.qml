// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G   I   T   H   U   B       F   A   C   E                              │
// │   the contribution wall on a sheet of vinyl · sticker                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.theme
import qs.modules.widgets.desktop.impasto.services
import qs.modules.widgets.desktop.impasto.components

// The contribution wall on a black sticker, in GitHub's own fixed greens.
// The cell is one size and the width decides how many weeks fit, as in the
// other themes.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)
    property string seed: ""

    readonly property real side: Math.min(root.width, root.height)

    Cut {
        id: sheet

        anchors.fill: parent
        anchors.margins: root.side * 0.03
        shape: "soft"
        lean: Theme.stickerLean * 0.3
        seed: root.seed
        fill: root.ink.ground

        ContributionGrid {
            anchors.fill: parent
            anchors.margins: sheet.edge + sheet.side * 0.07
            visible: GithubService.available
            weeks: GithubService.weeks
            spacing: 3
            radius: 3
            maxCell: 18
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 24
            visible: !GithubService.available
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: SettingsService.githubUser.trim() === "" ? "No GitHub user set" : "GitHub is out of reach"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: sheet.paper
        }
    }
}
