pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Rectangle {
    id: root

    color: "transparent"
    implicitWidth: 250
    implicitHeight: resourcesColumn.implicitHeight

    readonly property string networkLabel: {
        if (NetworkService.active && NetworkService.active.ssid)
            return NetworkService.active.ssid;
        if (NetworkService.networkName)
            return NetworkService.networkName;
        if (NetworkService.ethernet)
            return "Ethernet";
        if (NetworkService.wifiEnabled)
            return "Disconnected";
        return "Offline";
    }

    readonly property string networkIcon: {
        if (NetworkService.ethernet && !NetworkService.active)
            return Icons.ethernet;
        if (NetworkService.wifiEnabled || NetworkService.active)
            return NetworkService.wifiIconForStrength(NetworkService.networkStrength);
        return Icons.ethernet;
    }

    function formatSpeed(bytesPerSecond) {
        const value = Math.max(0, bytesPerSecond || 0);
        return (value * 8 / 1000 / 1000).toFixed(1);
    }

    function formatStoragePair(usedBytes, totalBytes) {
        const used = Math.max(0, usedBytes || 0);
        const total = Math.max(0, totalBytes || 0);
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let divisor = 1;
        let unitIndex = 0;
        while (total / divisor >= 1024 && unitIndex < units.length - 1) {
            divisor *= 1024;
            unitIndex++;
        }
        const precision = unitIndex === 0 ? 0 : 1;
        return `${(used / divisor).toFixed(precision)} / ${(total / divisor).toFixed(precision)} ${units[unitIndex]}`;
    }

    function formatCompactStoragePair(usedBytes, totalBytes) {
        const used = Math.max(0, usedBytes || 0);
        const total = Math.max(0, totalBytes || 0);
        const units = ["B", "K", "M", "G", "T"];
        let divisor = 1;
        let unitIndex = 0;
        while (total / divisor >= 1024 && unitIndex < units.length - 1) {
            divisor *= 1024;
            unitIndex++;
        }
        const precision = total / divisor >= 10 ? 0 : 1;
        return `${(used / divisor).toFixed(precision)}/${(total / divisor).toFixed(precision)}${units[unitIndex]}`;
    }

    function formatFrequency(mhz) {
        const value = Math.max(0, mhz || 0);
        if (value <= 0)
            return "";
        return value >= 1000 ? `${(value / 1000).toFixed(1)} GHz` : `${Math.round(value)} MHz`;
    }

    function gpuDetails(index, toVfio) {
        if (toVfio)
            return "Unavailable";

        const details = [];
        const total = SystemResources.gpuVramTotal[index] || 0;
        if (total > 0) {
            const used = SystemResources.gpuVramUsed[index] || 0;
            details.push(root.formatCompactStoragePair(used, total));
        }

        const frequency = root.formatFrequency(SystemResources.gpuClockMhz[index]);
        if (frequency)
            details.push(frequency);
        return details.join(" · ");
    }

    function gpuColor(vendor) {
        switch ((vendor || "").toLowerCase()) {
        case "nvidia":
            return Colors.green;
        case "amd":
            return Colors.red;
        case "intel":
            return Colors.blue;
        default:
            return Colors.magenta;
        }
    }

    function gpuName(index) {
        const name = SystemResources.gpuNames[index] || "";
        if (name)
            return name;
        return SystemResources.gpuCount > 1 ? `GPU ${index + 1}` : "GPU";
    }

    Component.onCompleted: {
        const savedInterval = StateService.get("metricsRefreshInterval", 2000);
        SystemResources.updateInterval = Math.max(100, savedInterval);
    }

    component DetailRow: RowLayout {
        id: detail

        required property string primaryText
        required property string secondaryText
        property int temperature: -1
        property color accentColor: Colors.red

        width: parent ? parent.width : implicitWidth
        spacing: 4

        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            visible: detail.primaryText.length > 0
            Layout.maximumWidth: Math.max(80, detail.width * 0.62)
            text: detail.primaryText
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overBackground
            elide: Text.ElideMiddle
        }

        Separator {
            Layout.preferredHeight: 2
            Layout.fillWidth: true
        }

        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            visible: detail.temperature >= 0
            text: Icons.temperature
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-2)
            color: detail.accentColor
        }

        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            visible: detail.temperature >= 0
            text: `${detail.temperature}°`
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.Medium
            color: Colors.overBackground
        }

        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            visible: detail.secondaryText.length > 0
            text: detail.secondaryText
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.Medium
            color: Colors.overBackground
        }
    }

    Column {
        id: resourcesColumn

        width: parent.width
        spacing: 12

        Column {
            width: parent.width
            spacing: 4

            ResourceItem {
                width: parent.width
                icon: Icons.cpu
                label: SystemResources.cpuModel || "CPU"
                barColor: Colors.red
            }

            DetailRow {
                primaryText: root.formatFrequency(SystemResources.cpuFrequency)
                secondaryText: `${Math.round(SystemResources.cpuUsage)}%`
                temperature: SystemResources.cpuTemp
                accentColor: Colors.red
            }
        }

        Column {
            width: parent.width
            spacing: 4

            ResourceItem {
                width: parent.width
                icon: Icons.ram
                label: "RAM"
                barColor: Colors.cyan
            }

            DetailRow {
                primaryText: {
                    const usedGB = (SystemResources.ramUsed / 1024 / 1024).toFixed(1);
                    const totalGB = (SystemResources.ramTotal / 1024 / 1024).toFixed(1);
                    return `${usedGB} GB / ${totalGB} GB`;
                }
                secondaryText: `${Math.round(SystemResources.ramUsage)}%`
            }
        }

        Repeater {
            model: SystemResources.gpuDetected ? SystemResources.gpuCount : 0

            Column {
                id: gpuColumn

                required property int index
                readonly property string driver: SystemResources.gpuDrivers[index] || "none"
                readonly property bool toVfio: driver === "vfio-pci"
                readonly property color accentColor: root.gpuColor(SystemResources.gpuVendors[index])

                width: parent.width
                spacing: 4

                ResourceItem {
                    width: parent.width
                    icon: Icons.gpu
                    label: root.gpuName(gpuColumn.index)
                    barColor: gpuColumn.accentColor
                }

                DetailRow {
                    primaryText: root.gpuDetails(gpuColumn.index, gpuColumn.toVfio)
                    secondaryText: gpuColumn.toVfio ? "To VFIO" : `${Math.round(SystemResources.gpuUsages[gpuColumn.index] || 0)}%`
                    temperature: gpuColumn.toVfio ? -1 : (SystemResources.gpuTemps[gpuColumn.index] ?? -1)
                    accentColor: gpuColumn.accentColor
                }
            }
        }

        Repeater {
            model: SystemResources.validDisks

            Column {
                id: diskColumn

                required property string modelData
                width: parent.width
                spacing: 4

                ResourceItem {
                    width: parent.width
                    icon: {
                        const diskType = SystemResources.diskTypes[diskColumn.modelData] || "unknown";
                        switch (diskType) {
                        case "ssd":
                            return Icons.ssd;
                        case "hdd":
                            return Icons.hdd;
                        default:
                            return Icons.disk;
                        }
                    }
                    label: diskColumn.modelData
                    barColor: Colors.yellow
                }

                DetailRow {
                    primaryText: root.formatStoragePair(SystemResources.diskUsed[diskColumn.modelData], SystemResources.diskTotal[diskColumn.modelData])
                    secondaryText: `${Math.round(SystemResources.diskUsage[diskColumn.modelData] || 0)}%`
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4

            ResourceItem {
                width: parent.width
                icon: root.networkIcon
                label: root.networkLabel
                barColor: Colors.cyan
            }

            RowLayout {
                width: parent.width
                spacing: 4

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowUp
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.red
                }

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: root.formatSpeed(SystemResources.networkUploadSpeed)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    font.weight: Font.Medium
                    color: Colors.overBackground
                }

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: "/"
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overBackground
                }

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowDown
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.cyan
                }

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: root.formatSpeed(SystemResources.networkDownloadSpeed)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    font.weight: Font.Medium
                    color: Colors.overBackground
                }

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: "Mb/s"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    font.weight: Font.Medium
                    color: Colors.overBackground
                }

                Separator {
                    Layout.preferredHeight: 2
                    Layout.fillWidth: true
                }

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    visible: NetworkService.wifiEnabled && !NetworkService.ethernet
                    text: `${Math.round(NetworkService.networkStrength)}%`
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    font.weight: Font.Medium
                    color: Colors.overBackground
                }
            }
        }
    }
}
