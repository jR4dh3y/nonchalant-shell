pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
pragma ComponentBehavior: Bound

/**
 * System resource monitoring service
 * Optimized to be lightweight and avoid waking up dGPUs.
 */
Singleton {
    id: root

    // CPU metrics
    property real cpuUsage: 0.0
    property string cpuModel: ""
    property int cpuTemp: -1
    property real cpuFrequency: 0

    // RAM metrics
    property real ramUsage: 0.0
    property real ramTotal: 0
    property real ramUsed: 0
    property real ramAvailable: 0

    // GPU metrics
    property var gpuUsages: []
    property var gpuVendors: []
    property var gpuNames: []
    property var gpuDrivers: []
    property int gpuCount: 0
    property bool gpuDetected: false
    property var gpuTemps: []
    property var gpuVramUsed: []
    property var gpuVramTotal: []
    property var gpuClockMhz: []
    
    // Legacy single GPU properties
    property real gpuUsage: gpuUsages.length > 0 ? gpuUsages[0] : 0.0
    property string gpuVendor: gpuVendors.length > 0 ? gpuVendors[0] : "unknown"
    property int gpuTemp: gpuTemps.length > 0 ? gpuTemps[0] : -1

    // Disk metrics
    property var diskUsage: ({})
    property var diskUsed: ({})
    property var diskTotal: ({})
    property var diskTypes: ({})
    property var validDisks: []

    // Network throughput in bytes per second
    property real networkDownloadSpeed: 0
    property real networkUploadSpeed: 0

    // Update interval
    property int updateInterval: 2000

    // Unified monitor process.
    // Resource-efficient: only runs while the bar monitor popup is open.
    // Optimized GPU polling avoids waking dGPUs.
    property Process monitorProcess: Process {
        id: monitorProcess
        running: GlobalStates.systemMonitorOpen && root.validDisks.length > 0
        
        command: {
            let cmd = ["python3", Quickshell.shellDir + "/scripts/system_monitor.py", root.updateInterval.toString()];
            return cmd.concat(root.validDisks);
        }
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    const stats = JSON.parse(data);
                    
                    // Static info (received once at start)
                    if (stats.static) {
                        root.cpuModel = stats.static.cpu_model || root.cpuModel;
                        root.gpuNames = stats.static.gpu_names || [];
                        root.gpuVendors = stats.static.gpu_vendors || [];
                        root.gpuDrivers = stats.static.gpu_drivers || [];
                        root.gpuCount = stats.static.gpu_count || 0;
                        root.gpuDetected = root.gpuCount > 0;
                        root.diskTypes = stats.static.disk_types || {};
                        return;
                    }

                    // Update metrics
                    if (stats.cpu) {
                        root.cpuUsage = stats.cpu.usage;
                        root.cpuTemp = stats.cpu.temp;
                        root.cpuFrequency = stats.cpu.frequency || 0;
                    }
                    
                    if (stats.ram) {
                        root.ramUsage = stats.ram.usage;
                        root.ramTotal = stats.ram.total;
                        root.ramUsed = stats.ram.used;
                        root.ramAvailable = stats.ram.available;
                    }
                    
                    if (stats.disk) {
                        root.diskUsage = stats.disk.usage || {};
                        root.diskUsed = stats.disk.used || {};
                        root.diskTotal = stats.disk.total || {};
                    }

                    if (stats.network) {
                        root.networkDownloadSpeed = stats.network.download || 0;
                        root.networkUploadSpeed = stats.network.upload || 0;
                    }
                    
                    if (stats.gpu) {
                        root.gpuUsages = stats.gpu.usages;
                        root.gpuTemps = stats.gpu.temps;
                        root.gpuDrivers = stats.gpu.drivers || root.gpuDrivers;
                        root.gpuVramUsed = stats.gpu.vram_used || [];
                        root.gpuVramTotal = stats.gpu.vram_total || [];
                        root.gpuClockMhz = stats.gpu.clock_mhz || [];
                    }
                } catch (e) {
                    console.warn("SystemResources: Failed to parse monitor data: " + e);
                }
            }
        }
    }

    Component.onCompleted: validateDisks()

    Connections {
        target: Config.system
        function onDisksChanged() { root.validateDisks(); }
    }

    property bool configReady: Config.initialLoadComplete
    onConfigReadyChanged: if (configReady) validateDisks()

    onValidDisksChanged: if (monitorProcess.running) restartMonitor()
    onUpdateIntervalChanged: if (monitorProcess.running) restartMonitor()

    function restartMonitor() {
        monitorProcess.running = false;
        Qt.callLater(() => { monitorProcess.running = true; });
    }

    function validateDisks() {
        const configuredDisks = Config.system.disks || ["/"];
        let newValidDisks = [];
        for (let i = 0; i < configuredDisks.length; i++) {
            const disk = configuredDisks[i];
            if (disk && typeof disk === 'string' && disk.trim() !== '') {
                newValidDisks.push(disk.trim());
            }
        }
        if (newValidDisks.length === 0) newValidDisks = ["/"];
        validDisks = newValidDisks;
    }

}
