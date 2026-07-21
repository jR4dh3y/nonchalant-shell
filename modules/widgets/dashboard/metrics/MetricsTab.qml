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
    // Header + body + outer vertical padding so the last row is not flush with the popup edge.
    implicitHeight: Math.min(400, systemHeader.implicitHeight + resourcesColumn.implicitHeight + 20)

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
            text: detail.secondaryText
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.Medium
            color: Colors.overBackground
        }

        Text {
            visible: detail.temperature >= 0
            text: Icons.temperature
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-2)
            color: detail.accentColor
        }

        Text {
            visible: detail.temperature >= 0
            text: `${detail.temperature}°`
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.Medium
            color: Colors.overBackground
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        RowLayout {
            id: systemHeader

            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 8

            Separator {
                Layout.preferredHeight: 2
                Layout.fillWidth: true
            }

            Text {
                text: "System"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overBackground
            }

            Separator {
                Layout.preferredHeight: 2
                Layout.fillWidth: true
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 8
            contentWidth: width
            contentHeight: resourcesColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

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

                // Network: icon + speeds only (no progress bar). Match the
                // vertical rhythm of other ResourceItem rows.
                Column {
                    width: parent.width
                    spacing: 4

                    RowLayout {
                        width: parent.width
                        height: 24
                        spacing: 8

                        Text {
                            text: Icons.ethernet
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: Colors.overBackground
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 20
                        }

                        Text {
                            text: Icons.arrowDown
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.cyan
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: root.formatSpeed(SystemResources.networkDownloadSpeed)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: Icons.arrowUp
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.red
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: root.formatSpeed(SystemResources.networkUploadSpeed)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // Bottom spacer so the last row is not flush with the popup edge.
                Item {
                    width: 1
                    height: 4
                }
            }
        }
    }
}
