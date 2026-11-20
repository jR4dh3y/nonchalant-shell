pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// System monitor for the vertical-bar dashboard side pane. Every metric is the
// same tile (icon, name, value, detail, bar) in a two-column grid that fills
// the pane, so nothing scrolls and no row looks different from the others.
Item {
    id: root
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(root)

    readonly property int gap: 8
    implicitWidth: 420

    // Network has no natural 100%; scale its bar to the recent peak.
    property real networkPeak: 1
    readonly property real networkTotal: SystemResources.networkDownloadSpeed + SystemResources.networkUploadSpeed
    onNetworkTotalChanged: networkPeak = Math.max(networkPeak * 0.98, networkTotal, 1)

    function percent(value: real): string {
        return Math.round(Math.max(0, value)) + "%";
    }

    function gigabytes(bytes: real): string {
        return (Math.max(0, bytes) / 1024 / 1024 / 1024).toFixed(1);
    }

    function speed(bytesPerSecond: real): string {
        const mbps = Math.max(0, bytesPerSecond) * 8 / 1000 / 1000;
        return mbps >= 10 ? Math.round(mbps) + " Mb/s" : mbps.toFixed(1) + " Mb/s";
    }

    function shortCpuName(name: string): string {
        return (name || "CPU").replace(/\((R|TM)\)/g, "").replace(/^(AMD|Intel)\s+/, "")
            .replace(/\s+(with .*|\d+-Core Processor|CPU @.*)$/i, "").trim() || "CPU";
    }

    function shortGpuName(name: string, index: int): string {
        const short = (name || "").split(" / ")[0]
            .replace(/^(NVIDIA|AMD|Intel)\s+/, "").replace(/^GeForce\s+/, "")
            .replace(/\s+(Mobile|Series|Graphics)\b/g, "").trim();
        return short || "GPU " + (index + 1);
    }

    function joinParts(parts: list<string>): string {
        return parts.filter(part => part !== "").join(" · ");
    }

    // Tile identities only change when GPUs or disks change. The Repeater is
    // keyed by their count, so value updates never recreate tiles (which would
    // restart every bar animation from zero).
    readonly property list<string> tileKeys: {
        const keys = ["cpu", "ram"];
        const gpus = SystemResources.gpuDetected ? SystemResources.gpuCount : 0;
        for (let i = 0; i < gpus; i++)
            keys.push("gpu:" + i);
        for (const disk of SystemResources.validDisks)
            keys.push("disk:" + disk);
        keys.push("net");
        return keys;
    }

    function tileData(key: string): var {
        if (key === "cpu")
            return {
                icon: Icons.cpu,
                title: shortCpuName(SystemResources.cpuModel),
                value: percent(SystemResources.cpuUsage),
                detail: joinParts([
                    SystemResources.cpuFrequency > 0 ? (SystemResources.cpuFrequency / 1000).toFixed(1) + " GHz" : "",
                    SystemResources.cpuTemp >= 0 ? SystemResources.cpuTemp + "°C" : ""
                ]),
                fraction: SystemResources.cpuUsage / 100
            };
        if (key === "ram")
            return {
                icon: Icons.ram,
                title: "Memory",
                value: percent(SystemResources.ramUsage),
                detail: (SystemResources.ramUsed / 1024 / 1024).toFixed(1) + " / " + (SystemResources.ramTotal / 1024 / 1024).toFixed(1) + " GB",
                fraction: SystemResources.ramUsage / 100
            };
        if (key.startsWith("gpu:")) {
            const i = parseInt(key.slice(4));
            const usage = SystemResources.gpuUsages[i] || 0;
            const vramTotal = SystemResources.gpuVramTotal[i] || 0;
            const temp = SystemResources.gpuTemps[i] ?? -1;
            return {
                icon: Icons.gpu,
                title: shortGpuName(SystemResources.gpuNames[i], i),
                value: percent(usage),
                detail: joinParts([
                    vramTotal > 0 ? gigabytes(SystemResources.gpuVramUsed[i] || 0) + " / " + gigabytes(vramTotal) + " GB" : "",
                    temp >= 0 ? temp + "°C" : ""
                ]) || "Idle",
                fraction: usage / 100
            };
        }
        if (key.startsWith("disk:")) {
            const disk = key.slice(5);
            const usage = SystemResources.diskUsage[disk] || 0;
            return {
                icon: Icons.disk,
                title: disk === "/" ? "Disk" : "Disk " + disk,
                value: percent(usage),
                detail: gigabytes(SystemResources.diskUsed[disk] || 0) + " / " + gigabytes(SystemResources.diskTotal[disk] || 0) + " GB",
                fraction: usage / 100
            };
        }
        return {
            icon: NetworkService.vpnConnected ? Icons.vpnKey : (NetworkService.wifiEnabled ? Icons.wifiHigh : Icons.ethernet),
            title: NetworkService.vpnConnected ? (NetworkService.vpnName || "VPN") : (NetworkService.activeSsid || "Network"),
            value: speed(SystemResources.networkDownloadSpeed),
            detail: "↑ " + speed(SystemResources.networkUploadSpeed),
            fraction: root.networkTotal / root.networkPeak
        };
    }

    GridLayout {
        anchors.fill: parent
        anchors.margins: root.gap
        columns: 2
        rowSpacing: root.gap
        columnSpacing: root.gap

        Repeater {
            model: root.tileKeys.length

            StyledRect {
                id: tile
                required property int index
                readonly property var modelData: root.tileData(root.tileKeys[index] ?? "")
                readonly property string key: root.tileKeys[index] ?? ""
                // Series identities match the Island/Pills stats panel: memory
                // secondary, network tertiary, the rest primary. 90% load is error.
                readonly property string seriesVariant: key === "ram" ? "secondary" : (key === "net" ? "tertiary" : "primary")

                // An odd last tile spans both columns so the grid stays full.
                readonly property bool spansRow: index === root.tileKeys.length - 1 && root.tileKeys.length % 2 === 1

                Layout.columnSpan: spansRow ? 2 : 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                // Equal preferred sizes make every row and column the same size.
                Layout.preferredWidth: 1
                Layout.preferredHeight: 1
                variant: "internalbg"
                radius: Styling.radius(2)
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledRect {
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: Styling.scaledRadius(12)
                            variant: tile.seriesVariant

                            StyledText {
                                anchors.centerIn: parent
                                text: tile.modelData.icon
                                font.family: Icons.font
                                font.pixelSize: 12
                                color: Styling.srItem(tile.seriesVariant, root.shellPalette)
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: tile.modelData.title
                            font.pixelSize: Styling.fontSize(-1)
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    StyledText {
                        text: tile.modelData.value
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(3)
                        font.bold: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: tile.modelData.detail
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-3)
                        color: root.shellPalette.overSurfaceVariant
                        elide: Text.ElideRight
                    }

                    StyledRect {
                        id: track
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        Layout.topMargin: 2
                        radius: Styling.scaledRadius(2)
                        variant: "common"
                        clip: true

                        StyledRect {
                            height: parent.height
                            width: track.width * Math.max(0, Math.min(1, tile.modelData.fraction))
                            radius: Styling.scaledRadius(2)
                            variant: tile.key !== "net" && tile.modelData.fraction >= 0.9 ? "error" : tile.seriesVariant

                            Behavior on width {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
    }
}
