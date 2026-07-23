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
        if (value < 1024)
            return `${Math.round(value)} B/s`;
        if (value < 1024 * 1024)
            return `${(value / 1024).toFixed(value < 10 * 1024 ? 1 : 0)} KiB/s`;
        if (value < 1024 * 1024 * 1024)
            return `${(value / 1024 / 1024).toFixed(1)} MiB/s`;
        return `${(value / 1024 / 1024 / 1024).toFixed(1)} GiB/s`;
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
            Layout.maximumWidth: Math.max(80, detail.width * 0.58)
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
            text: detail.secondaryText
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.Medium
            color: Colors.overBackground
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
                label: "CPU"
                value: SystemResources.cpuUsage / 100
                barColor: Colors.red
            }

            DetailRow {
                primaryText: SystemResources.cpuModel || "CPU"
                secondaryText: `${Math.round(SystemResources.cpuUsage)}%`
                temperature: SystemResources.cpuTemp
            }
        }

        Column {
            width: parent.width
            spacing: 4

            ResourceItem {
                width: parent.width
                icon: Icons.ram
                label: "RAM"
                value: SystemResources.ramUsage / 100
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
                    value: (SystemResources.gpuUsages[gpuColumn.index] || 0) / 100
                    statusText: gpuColumn.toVfio ? "To VFIO" : ""
                    barColor: gpuColumn.accentColor
                }

                DetailRow {
                    primaryText: root.gpuName(gpuColumn.index)
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
                    value: (SystemResources.diskUsage[diskColumn.modelData] || 0) / 100
                    barColor: Colors.yellow
                }

                DetailRow {
                    primaryText: diskColumn.modelData
                    secondaryText: `${Math.round(SystemResources.diskUsage[diskColumn.modelData] || 0)}%`
                }
            }
        }

        // Network: SSID (or connection name) + speeds
        RowLayout {
            width: parent.width
            height: 24
            spacing: 8

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: root.networkIcon
                font.family: Icons.font
                font.pixelSize: 18
                color: Colors.overBackground
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 20
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: root.networkLabel
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Medium
                color: Colors.overBackground
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: Icons.arrowDown
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.cyan
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: root.formatSpeed(SystemResources.networkDownloadSpeed)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Medium
                color: Colors.overBackground
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: Icons.arrowUp
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.red
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: root.formatSpeed(SystemResources.networkUploadSpeed)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Medium
                color: Colors.overBackground
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
