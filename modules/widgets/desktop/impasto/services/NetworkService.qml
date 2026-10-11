pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services as Nonchalant

Singleton {
    readonly property bool wifiConnected: Nonchalant.NetworkService.wifiConnected
    readonly property bool wiredConnected: Nonchalant.NetworkService.ethernet
    readonly property bool wifiEnabled: Nonchalant.NetworkService.wifiEnabled
    readonly property string wifiStatus: Nonchalant.NetworkService.wifiStatus
    readonly property string networkName: Nonchalant.NetworkService.networkName
    readonly property string activeSsid: Nonchalant.NetworkService.activeSsid
    readonly property real strength: Nonchalant.NetworkService.networkStrength / 100
    readonly property bool vpnConnected: Nonchalant.NetworkService.vpnConnected
    readonly property string vpnName: Nonchalant.NetworkService.vpnName
    readonly property bool available: Nonchalant.NetworkService.wifi || wiredConnected
    readonly property var online: {
        switch (Nonchalant.NetworkService.connectivity) {
        case "full": return true
        case "none":
        case "limited":
        case "portal": return false
        default: return null
        }
    }
    readonly property string connectionName: wiredConnected ? "Wired"
        : wifiConnected ? (networkName || activeSsid)
        : !available ? "Unavailable"
        : !wifiEnabled ? "Off" : "Not connected"
    readonly property string stateLine: {
        if (wiredConnected)
            return online === true ? "Ethernet · online"
                : online === false ? "Ethernet · no internet"
                : "Ethernet · connectivity unknown"
        if (wifiConnected)
            return online === true ? "Wi-Fi · online"
                : online === false ? "Wi-Fi · no internet"
                : "Wi-Fi · connectivity unknown"
        if (!available)
            return "Network unavailable"
        if (!wifiEnabled)
            return "Wi-Fi radio off"
        return online === true ? "Online"
            : online === false ? "Nothing reaches the internet"
            : "Connectivity unknown"
    }
    readonly property string icon: wiredConnected ? "󰈁"
        : !wifiEnabled ? "󰤮"
        : wifiConnected ? "󰤨" : "󰤯"
}
