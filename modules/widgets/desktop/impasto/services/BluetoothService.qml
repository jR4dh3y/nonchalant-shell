pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth as Bluez
import qs.modules.services as Nonchalant

Singleton {
    id: root

    readonly property var adapter: Bluez.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool discovering: available && adapter.discovering
    readonly property var allDevices: available
        ? Nonchalant.BluetoothService.devices.map(device => ({
            address: device.address,
            name: device.name === "Unknown" ? device.address : device.name,
            deviceName: device.name === "Unknown" ? "" : device.name,
            icon: device.icon,
            paired: device.paired,
            connected: device.connected,
            pairing: device.connecting,
            trusted: device.trusted,
            battery: device.battery,
            batteryAvailable: device.batteryAvailable
        }))
        : []
    readonly property var devices: root.allDevices.filter(device =>
        root.isNamed(device) || device.paired || device.connected || device.pairing)
    readonly property var unnamedDevices: root.allDevices.filter(device =>
        !(root.isNamed(device) || device.paired || device.connected || device.pairing))
    readonly property int unnamedCount: unnamedDevices.length
    readonly property var connectedDevices: root.allDevices.filter(device => device.connected)
    readonly property int connectedCount: connectedDevices.length
    readonly property string summary: {
        if (!available)
            return "Unavailable"
        if (!enabled)
            return "Off"
        if (connectedCount === 0)
            return "No devices"
        if (connectedCount === 1)
            return connectedDevices[0].name
        return `${connectedCount} devices`
    }
    readonly property string icon: !available || !enabled ? "󰂲"
        : connectedCount > 0 ? "󰂱" : "󰂯"

    function isNamed(device: var): bool {
        return ((device?.deviceName ?? "") + "").length > 0
    }

    function deviceIcon(device: var): string {
        switch (device.icon) {
        case "audio-headset":
        case "audio-headphones": return "󰋋"
        case "audio-card": return "󰓃"
        case "input-mouse": return "󰍽"
        case "input-keyboard": return "󰌌"
        case "phone": return "󰄜"
        case "computer": return "󰟀"
        default: return "󰂯"
        }
    }

    function toggle(): void {
        if (available)
            Nonchalant.BluetoothService.toggle()
    }

    function setEnabled(value: bool): void {
        if (available)
            Nonchalant.BluetoothService.setEnabled(value)
    }

    function setDiscovering(value: bool): void {
        if (!available)
            return
        if (value)
            Nonchalant.BluetoothService.startDiscovery()
        else
            Nonchalant.BluetoothService.stopDiscovery()
    }

    function startDiscovery(): void { setDiscovering(true) }
    function stopDiscovery(): void { setDiscovering(false) }

    function connectDevice(device: var): void {
        if (!device || !available)
            return
        if (device.connected)
            Nonchalant.BluetoothService.disconnectDevice(device.address)
        else
            Nonchalant.BluetoothService.connectDevice(device.address)
    }

    function disconnectDevice(device: var): void {
        if (device && available)
            Nonchalant.BluetoothService.disconnectDevice(device.address)
    }

    function pairDevice(device: var): void {
        if (device && available)
            Nonchalant.BluetoothService.pairDevice(device.address)
    }

    function trustDevice(device: var): void {
        if (device && available)
            Nonchalant.BluetoothService.trustDevice(device.address)
    }

    function removeDevice(device: var): void {
        if (device && available)
            Nonchalant.BluetoothService.removeDevice(device.address)
    }
}
