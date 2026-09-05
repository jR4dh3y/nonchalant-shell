pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

Item {
    id: root

    implicitWidth: 480
    implicitHeight: 460

    signal backRequested()

    Component.onCompleted: {
        GlobalStates.islandStatsOpen = true;
    }

    Component.onDestruction: {
        GlobalStates.islandStatsOpen = false;
    }

    function formatFrequency(mhz: real): string {
        if (mhz <= 0) return "";
        return mhz >= 1000 ? (mhz / 1000).toFixed(1) + " GHz" : Math.round(mhz) + " MHz";
    }

    function formatStorage(bytes: real): string {
        const gb = Math.max(0, bytes) / 1024 / 1024 / 1024;
        return gb.toFixed(1) + " GB";
    }

    function formatSpeed(bps: real): string {
        const mbps = (Math.max(0, bps) * 8) / 1000 / 1000;
        return mbps.toFixed(1) + " Mbps";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ═══════════════════════════════════════════════════════════════
        // UNIFIED HEADER: Back + Title + Live Status Pill
        // ═══════════════════════════════════════════════════════════════
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 8

            // Back button
            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: width / 2
                variant: backMouse.containsMouse ? "focus" : "common"

                Text {
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: Icons.arrowLeft
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: Colors.overBackground
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }

            // Title
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "System Resources"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.bold: true
                color: Colors.overBackground
            }

            Item { Layout.fillWidth: true }

            // Live status badge
            StyledRect {
                implicitWidth: statusRow.implicitWidth + 14
                implicitHeight: 22
                radius: 11
                variant: "common"

                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 5

                    StyledRect {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        variant: "primary"
                    }

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: "LIVE"
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(-4)
                        font.bold: true
                        color: Colors.overBackground
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // NATIVE METRICS BODY
        // ═══════════════════════════════════════════════════════════════
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Styling.radius(2)
            variant: "internalbg"
            clip: true

            Flickable {
                id: statsFlickable
                anchors.fill: parent
                anchors.margins: 10
                contentWidth: width
                contentHeight: statsContentColumn.implicitHeight
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                WheelHandler {
                    target: statsFlickable
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        statsFlickable.contentY = Math.max(0, Math.min(Math.max(0, statsFlickable.contentHeight - statsFlickable.height), statsFlickable.contentY - event.angleDelta.y));
                    }
                }

                ColumnLayout {
                    id: statsContentColumn
                    width: statsFlickable.width
                    spacing: 8

                    // 1. CPU Card
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: Styling.radius(2)
                        variant: "common"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                StyledRect {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: 13
                                    variant: "primary"

                                    Text {
                                        anchors.centerIn: parent
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        text: Icons.cpu
                                        font.family: Icons.font
                                        font.pixelSize: 13
                                        color: Colors.overPrimary
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        text: SystemResources.cpuModel || "Processor"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.bold: true
                                        color: Colors.overBackground
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        text: {
                                            const freq = root.formatFrequency(SystemResources.cpuFrequency);
                                            const temp = SystemResources.cpuTemp >= 0 ? `${SystemResources.cpuTemp}°C` : "";
                                            return [freq, temp].filter(Boolean).join(" · ") || "Active";
                                        }
                                        font.family: Config.theme.monoFont
                                        font.pixelSize: Styling.fontSize(-3)
                                        color: Colors.overSurfaceVariant
                                    }
                                }

                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    text: Math.round(SystemResources.cpuUsage) + "%"
                                    font.family: Config.theme.monoFont
                                    font.pixelSize: Styling.fontSize(0)
                                    font.bold: true
                                    color: Colors.overBackground
                                }
                            }

                            // Progress Bar Track
                            StyledRect {
                                id: cpuTrack
                                Layout.fillWidth: true
                                Layout.preferredHeight: 4
                                radius: 2
                                variant: "internalbg"
                                clip: true

                                StyledRect {
                                    height: parent.height
                                    width: (SystemResources.cpuUsage > 0) ? Math.max(2, cpuTrack.width * Math.min(1.0, SystemResources.cpuUsage / 100)) : 0
                                    radius: 2
                                    variant: "primary"

                                    Behavior on width {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }

                    // 2. Memory (RAM) Card
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: Styling.radius(2)
                        variant: "common"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                StyledRect {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: 13
                                    variant: "primary"

                                    Text {
                                        anchors.centerIn: parent
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        text: Icons.ram
                                        font.family: Icons.font
                                        font.pixelSize: 13
                                        color: Colors.overPrimary
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        text: "Memory (RAM)"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.bold: true
                                        color: Colors.overBackground
                                    }

                                    Text {
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        text: `${(SystemResources.ramUsed / 1024 / 1024).toFixed(1)} GB / ${(SystemResources.ramTotal / 1024 / 1024).toFixed(1)} GB`
                                        font.family: Config.theme.monoFont
                                        font.pixelSize: Styling.fontSize(-3)
                                        color: Colors.overSurfaceVariant
                                    }
                                }

                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    text: Math.round(SystemResources.ramUsage) + "%"
                                    font.family: Config.theme.monoFont
                                    font.pixelSize: Styling.fontSize(0)
                                    font.bold: true
                                    color: Colors.overBackground
                                }
                            }

                            // Progress Bar Track
                            StyledRect {
                                id: ramTrack
                                Layout.fillWidth: true
                                Layout.preferredHeight: 4
                                radius: 2
                                variant: "internalbg"
                                clip: true

                                StyledRect {
                                    height: parent.height
                                    width: (SystemResources.ramUsage > 0) ? Math.max(2, ramTrack.width * Math.min(1.0, SystemResources.ramUsage / 100)) : 0
                                    radius: 2
                                    variant: "primary"

                                    Behavior on width {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }

                    // 3. GPU Cards
                    Repeater {
                        model: SystemResources.gpuDetected ? SystemResources.gpuCount : 0

                        StyledRect {
                            id: gpuDelegate
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: Styling.radius(2)
                            variant: "common"

                            readonly property real gpuUsageVal: SystemResources.gpuUsages[gpuDelegate.index] || 0

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    StyledRect {
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        radius: 13
                                        variant: "primary"

                                        Text {
                                            anchors.centerIn: parent
                                            renderType: Text.NativeRendering
                                            font.hintingPreference: Font.PreferFullHinting
                                            text: Icons.gpu
                                            font.family: Icons.font
                                            font.pixelSize: 13
                                            color: Colors.overPrimary
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            renderType: Text.NativeRendering
                                            font.hintingPreference: Font.PreferFullHinting
                                            text: SystemResources.gpuNames[gpuDelegate.index] || "GPU " + (gpuDelegate.index + 1)
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.bold: true
                                            color: Colors.overBackground
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            renderType: Text.NativeRendering
                                            font.hintingPreference: Font.PreferFullHinting
                                            text: {
                                                const vram = SystemResources.gpuVramTotal[gpuDelegate.index] > 0
                                                    ? `VRAM: ${(SystemResources.gpuVramUsed[gpuDelegate.index] / 1024 / 1024 / 1024).toFixed(1)} / ${(SystemResources.gpuVramTotal[gpuDelegate.index] / 1024 / 1024 / 1024).toFixed(1)} GB`
                                                    : "";
                                                const temp = (SystemResources.gpuTemps[gpuDelegate.index] ?? -1) >= 0 ? `${SystemResources.gpuTemps[gpuDelegate.index]}°C` : "";
                                                return [vram, temp].filter(Boolean).join(" · ") || "Active";
                                            }
                                            font.family: Config.theme.monoFont
                                            font.pixelSize: Styling.fontSize(-3)
                                            color: Colors.overSurfaceVariant
                                        }
                                    }

                                    Text {
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        text: Math.round(gpuDelegate.gpuUsageVal) + "%"
                                        font.family: Config.theme.monoFont
                                        font.pixelSize: Styling.fontSize(0)
                                        font.bold: true
                                        color: Colors.overBackground
                                    }
                                }

                                StyledRect {
                                    id: gpuTrack
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 4
                                    radius: 2
                                    variant: "internalbg"
                                    clip: true

                                    StyledRect {
                                        height: parent.height
                                        width: (gpuDelegate.gpuUsageVal > 0) ? Math.max(2, gpuTrack.width * Math.min(1.0, gpuDelegate.gpuUsageVal / 100)) : 0
                                        radius: 2
                                        variant: "primary"

                                        Behavior on width {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 4. Storage / Disks Card
                    Repeater {
                        model: SystemResources.validDisks

                        StyledRect {
                            id: diskDelegate
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: Styling.radius(2)
                            variant: "common"

                            readonly property real diskUsageVal: SystemResources.diskUsage[diskDelegate.modelData] || 0

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    StyledRect {
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        radius: 13
                                        variant: "primary"

                                        Text {
                                            anchors.centerIn: parent
                                            renderType: Text.NativeRendering
                                            font.hintingPreference: Font.PreferFullHinting
                                            text: Icons.disk
                                            font.family: Icons.font
                                            font.pixelSize: 13
                                            color: Colors.overPrimary
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            renderType: Text.NativeRendering
                                            font.hintingPreference: Font.PreferFullHinting
                                            text: "Disk (" + diskDelegate.modelData + ")"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.bold: true
                                            color: Colors.overBackground
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            renderType: Text.NativeRendering
                                            font.hintingPreference: Font.PreferFullHinting
                                            text: `${root.formatStorage(SystemResources.diskUsed[diskDelegate.modelData] || 0)} / ${root.formatStorage(SystemResources.diskTotal[diskDelegate.modelData] || 0)}`
                                            font.family: Config.theme.monoFont
                                            font.pixelSize: Styling.fontSize(-3)
                                            color: Colors.overSurfaceVariant
                                        }
                                    }

                                    Text {
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        text: Math.round(diskDelegate.diskUsageVal) + "%"
                                        font.family: Config.theme.monoFont
                                        font.pixelSize: Styling.fontSize(0)
                                        font.bold: true
                                        color: Colors.overBackground
                                    }
                                }

                                StyledRect {
                                    id: diskTrack
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 4
                                    radius: 2
                                    variant: "internalbg"
                                    clip: true

                                    StyledRect {
                                        height: parent.height
                                        width: (diskDelegate.diskUsageVal > 0) ? Math.max(2, diskTrack.width * Math.min(1.0, diskDelegate.diskUsageVal / 100)) : 0
                                        radius: 2
                                        variant: "primary"

                                        Behavior on width {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 5. Network Card
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: Styling.radius(2)
                        variant: "common"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            StyledRect {
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 13
                                variant: "primary"

                                Text {
                                    anchors.centerIn: parent
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    text: NetworkService.wifiEnabled ? Icons.wifiHigh : Icons.ethernet
                                    font.family: Icons.font
                                    font.pixelSize: 13
                                    color: Colors.overPrimary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    text: NetworkService.wifiEnabled ? (NetworkService.activeSsid || "Network") : "Ethernet / Local"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.bold: true
                                    color: Colors.overBackground
                                    elide: Text.ElideRight
                                }

                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    text: `↓ ${root.formatSpeed(SystemResources.networkDownloadSpeed)}   ↑ ${root.formatSpeed(SystemResources.networkUploadSpeed)}`
                                    font.family: Config.theme.monoFont
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: Colors.overSurfaceVariant
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
