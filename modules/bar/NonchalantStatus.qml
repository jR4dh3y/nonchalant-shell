pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    required property var bar

    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(bar.screen)
    readonly property real volume: Audio.sink?.audio?.volume ?? 0
    readonly property bool muted: Audio.sink?.audio?.muted ?? false

    function volumeIcon() {
        if (root.muted)
            return Icons.speakerSlash;
        if (root.volume < 0.01)
            return Icons.speakerX;
        if (root.volume < 0.35)
            return Icons.speakerLow;
        return Icons.speakerHigh;
    }

    implicitWidth: statusRow.implicitWidth + 16
    implicitHeight: 36

    StyledRect {
        anchors.fill: parent
        variant: "bg"
        radius: Styling.radius(7)
        enableShadow: false
    }

    RowLayout {
        id: statusRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: NetworkService.wifi || NetworkService.ethernet
            text: NetworkService.ethernet ? Icons.ethernet : NetworkService.wifiIconForStrength(NetworkService.networkStrength)
            color: Colors.overBackground
            font.family: Icons.font
            font.pixelSize: 16
        }

        RowLayout {
            spacing: 3

            Text {
                text: root.volumeIcon()
                color: root.muted ? Colors.outline : Colors.overBackground
                font.family: Icons.font
                font.pixelSize: 16
            }

            Text {
                text: Math.round(root.volume * 100) + "%"
                color: Colors.overBackground
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
            }

        }

        RowLayout {
            visible: root.brightnessMonitor?.ready ?? false
            spacing: 3

            Text {
                text: Icons.sun
                color: Colors.overBackground
                font.family: Icons.font
                font.pixelSize: 16
            }

            Text {
                text: Math.round((root.brightnessMonitor?.brightness ?? 0) * 100) + "%"
                color: Colors.overBackground
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
            }
        }
    }
}
