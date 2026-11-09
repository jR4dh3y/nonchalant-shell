import QtQuick
import qs.modules.theme

QtObject {
    readonly property var categories: [
        { id: "shell", label: "THE SHELL" },
        { id: "desk", label: "THE DESK" },
        { id: "session", label: "THE SESSION" }
    ]

    readonly property var pages: [
        {
            id: "network",
            section: 0,
            category: "shell",
            label: "Network",
            description: "Wi-Fi connections and network status.",
            icon: Icons.wifiHigh,
            keywords: "internet wifi wireless connection ethernet ip router captive portal",
            component: "WifiPanel.qml",
            tabs: []
        },
        {
            id: "bluetooth",
            section: 1,
            category: "shell",
            label: "Bluetooth",
            description: "Pair and manage Bluetooth devices.",
            icon: Icons.bluetooth,
            keywords: "devices pairing connect headphones speakers keyboard mouse discovery",
            component: "BluetoothPanel.qml",
            tabs: []
        },
        {
            id: "audio",
            section: 2,
            category: "shell",
            label: "Mixer",
            description: "Output, input, and application sound levels.",
            icon: Icons.faders,
            keywords: "audio sound volume output input microphone mic speaker headphones pipewire",
            component: "AudioMixerPanel.qml",
            tabs: []
        },
        {
            id: "ai",
            section: 3,
            category: "shell",
            label: "AI",
            description: "Configure ACP agents and the assistant sidebar.",
            icon: Icons.robot,
            keywords: "assistant agent acp codex opencode grok enable disable working directory sidebar",
            component: "../../config/AiPanel.qml",
            tabs: []
        },
        {
            id: "shell",
            section: 6,
            category: "shell",
            label: "Shell",
            description: "The bar, assistant sidebar, and lockscreen.",
            icon: Icons.gear,
            keywords: "bar sidebar lockscreen settings clock 12h 24h time format lyrics LRCLIB track metadata",
            component: "ShellPanel.qml",
            tabs: [
                { id: "bar", panelSection: "bar", label: "Bar", keywords: "panel taskbar clock player screen 12h 24h time format lyrics LRCLIB track metadata music song" },
                { id: "sidebar", panelSection: "sidebar", label: "Sidebar", keywords: "assistant ai enable disable width position pinned" },
                { id: "lockscreen", panelSection: "lockscreen", label: "Lockscreen", keywords: "lock screen password login position lyrics LRCLIB track metadata music song" },
                { id: "system", panelSection: "system", label: "System", keywords: "about sponsor version" }
            ]
        },
        {
            id: "theme",
            section: 4,
            category: "desk",
            label: "Theme",
            description: "Appearance, wallpaper behavior, shadows, and colors.",
            icon: Icons.paintBrush,
            keywords: "appearance look style customize palette scheme",
            component: "ThemePanel.qml",
            tabs: [
                { id: "general", panelSection: "general", label: "General", keywords: "wallpaper icons animation font roundness overview blur backdrop niri" },
                { id: "shadow", panelSection: "shadow", label: "Shadows", keywords: "opacity blur offset color" },
                { id: "colors", panelSection: "colors", label: "Colors", keywords: "scheme palette variant gradient border" }
            ]
        },
        {
            id: "system",
            section: 5,
            category: "session",
            label: "System",
            description: "Weather, performance, and system resources.",
            icon: Icons.circuitry,
            keywords: "hardware info resources cpu ram memory performance",
            component: "SystemPanel.qml",
            tabs: [
                { id: "weather", panelSection: "weather", label: "Weather", keywords: "location temperature celsius fahrenheit" },
                { id: "performance", panelSection: "performance", label: "Performance", keywords: "animations preview effects dashboard" },
                { id: "system", panelSection: "system", label: "Resources", keywords: "cpu ram memory disk usage monitor" }
            ]
        }
    ]
}
