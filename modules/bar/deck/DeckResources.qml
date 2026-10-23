pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services
import qs.modules.theme

// Same channel grammar as Controls, read-only: meters on the left, detail rack on the right.
RowLayout {
    id: root
    required property real availableHeight
    readonly property bool sampled: SystemResources.cpuModel !== "" || SystemResources.ramTotal > 0
    spacing: Styling.fontSize(0)
    height: Math.max(availableHeight, rack.implicitHeight)

    function gigabytes(kilobytes: real): string {
        return (kilobytes / 1048576).toFixed(1);
    }
    function rate(bytes: real): string {
        return bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + " MB/s"
            : bytes >= 1024 ? Math.round(bytes / 1024) + " KB/s" : Math.round(bytes) + " B/s";
    }

    RowLayout {
        objectName: "deckMeters"
        Layout.fillHeight: true
        spacing: Styling.fontSize(0) * 0.25
        DeckChannel {
            objectName: "deckMeterCpu"
            Layout.fillHeight: true
            Layout.preferredWidth: Styling.fontSize(0) * 4.4
            interactive: false
            label: "CPU"
            glyph: Icons.cpu
            available: root.sampled
            value: SystemResources.cpuUsage / 100
        }
        DeckChannel {
            objectName: "deckMeterMemory"
            Layout.fillHeight: true
            Layout.preferredWidth: Styling.fontSize(0) * 4.4
            interactive: false
            label: "Memory"
            glyph: Icons.ram
            available: root.sampled
            value: SystemResources.ramUsage / 100
        }
        DeckChannel {
            objectName: "deckMeterGpu"
            visible: SystemResources.gpuDetected
            Layout.fillHeight: true
            Layout.preferredWidth: Styling.fontSize(0) * 4.4
            interactive: false
            label: "GPU"
            glyph: Icons.gpu
            value: SystemResources.gpuUsage / 100
        }
        DeckChannel {
            objectName: "deckMeterHeat"
            visible: !SystemResources.gpuDetected
            Layout.fillHeight: true
            Layout.preferredWidth: Styling.fontSize(0) * 4.4
            interactive: false
            label: "Heat"
            glyph: Icons.thermometer
            available: SystemResources.cpuTemp >= 0
            value: Math.max(0, SystemResources.cpuTemp) / 100
            readout: available ? String(SystemResources.cpuTemp) : "—"
            unit: available ? "°C" : ""
        }
    }

    DeckSection {
        id: rack
        title: "System"
        objectName: "deckResourceRack"
        Layout.fillWidth: true
        Layout.fillHeight: true
        StyledText {
            Layout.fillWidth: true
            text: SystemResources.cpuModel || "Reading system information…"
            font.weight: Font.DemiBold
            font.pixelSize: Styling.fontSize(-1)
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Styling.fontSize(0)
            rowSpacing: Styling.fontSize(0) * 0.35
            Repeater {
                model: [
                    { name: "Clock", value: SystemResources.cpuFrequency > 0 ? (SystemResources.cpuFrequency / 1000).toFixed(2) + " GHz" : "—" },
                    { name: "CPU heat", value: SystemResources.cpuTemp >= 0 ? SystemResources.cpuTemp + " °C" : "—" },
                    { name: "Memory", value: SystemResources.ramTotal > 0 ? root.gigabytes(SystemResources.ramUsed) + " / " + root.gigabytes(SystemResources.ramTotal) + " GB" : "—" },
                    { name: "GPU", value: SystemResources.gpuDetected ? (SystemResources.gpuNames[0] ?? SystemResources.gpuVendor) : "Not detected" },
                    { name: "Download", value: root.rate(SystemResources.networkDownloadSpeed) },
                    { name: "Upload", value: root.rate(SystemResources.networkUploadSpeed) }
                ]
                RowLayout {
                    id: reading
                    required property var modelData
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    StyledText {
                        text: reading.modelData.name
                        color: Colors.overSurfaceVariant
                        font.pixelSize: Styling.fontSize(-2)
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: reading.modelData.value
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: Font.Medium
                    }
                }
            }
        }
        Item { Layout.fillHeight: true }
        StyledText {
            Layout.fillWidth: true
            text: "Sampling runs only while this page is open."
            color: Colors.overSurfaceVariant
            font.pixelSize: Styling.fontSize(-3)
            wrapMode: Text.WordWrap
        }
    }
}
