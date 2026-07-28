import QtQuick
import qs.modules.theme

QtObject {
    property var dynamicItems: []

    readonly property var staticItems: [
        { label: "Network", keywords: "internet wifi connection ethernet ip", section: 0, subSection: "", subLabel: "", icon: Icons.wifiHigh, isIcon: true },
        { label: "Bluetooth", keywords: "devices pairing connect", section: 1, subSection: "", subLabel: "", icon: Icons.bluetooth, isIcon: true },
        { label: "Audio Mixer", keywords: "sound volume output input mic speaker", section: 2, subSection: "", subLabel: "", icon: Icons.faders, isIcon: true },
        { label: "AI", keywords: "assistant agent acp codex opencode grok enable disable", section: 3, subSection: "", subLabel: "", icon: Icons.robot, isIcon: true },
        { label: "Audio Effects", keywords: "equalizer bass treble easyeffects", section: 4, subSection: "", subLabel: "", icon: Icons.waveform, isIcon: true },

        { label: "Theme", keywords: "appearance look style customize", section: 5, subSection: "", subLabel: "Theme", icon: Icons.paintBrush, isIcon: true },
        { label: "General Appearance", keywords: "wallpaper icons animation font roundness", section: 5, subSection: "general", subLabel: "Theme > General", icon: Icons.paintBrush, isIcon: true },
        { label: "Shadows", keywords: "opacity blur offset color", section: 5, subSection: "shadow", subLabel: "Theme > Shadow", icon: Icons.drop, isIcon: true },
        { label: "Colors", keywords: "scheme palette variant gradient border", section: 5, subSection: "colors", subLabel: "Theme > Colors", icon: Icons.palette, isIcon: true },

        { label: "System", keywords: "hardware info resources cpu ram weather performance", section: 6, subSection: "", subLabel: "System", icon: Icons.circuitry, isIcon: true },
        { label: "Weather", keywords: "location temperature celsius fahrenheit", section: 6, subSection: "weather", subLabel: "System > Weather", icon: Icons.mapPin, isIcon: true },
        { label: "Performance", keywords: "animations preview effects dashboard", section: 6, subSection: "performance", subLabel: "System > Performance", icon: Icons.lightning, isIcon: true },
        { label: "System Resources", keywords: "cpu ram memory disk usage monitor", section: 6, subSection: "system", subLabel: "System > Resources", icon: Icons.circuitry, isIcon: true },

        { label: "Shell", keywords: "bar sidebar lockscreen settings", section: 7, subSection: "", subLabel: "Shell", icon: Icons.gear, isIcon: true },
        { label: "Bar", keywords: "panel taskbar clock player screen", section: 7, subSection: "bar", subLabel: "Shell > Bar", icon: Icons.layout, isIcon: true },
        { label: "Lockscreen", keywords: "lock screen password login position", section: 7, subSection: "lockscreen", subLabel: "Shell > Lockscreen", icon: Icons.lock, isIcon: true },
        { label: "Shell System", keywords: "about sponsor version", section: 7, subSection: "system", subLabel: "Shell > System", icon: Icons.circuitry, isIcon: true },
        { label: "Assistant Sidebar", keywords: "ai sidebar enable disable width position pinned", section: 7, subSection: "sidebar", subLabel: "Shell > Sidebar", icon: Icons.robot, isIcon: true }
    ]

    property var items: staticItems.concat(dynamicItems)

    function addDynamicItems(newItems) {
        let currentLabels = new Set(items.map(item => item.section + ":" + item.label));
        let uniqueNew = [];

        for (let i = 0; i < newItems.length; i++) {
            let item = newItems[i];
            let key = item.section + ":" + item.label;
            if (!currentLabels.has(key)) {
                uniqueNew.push(item);
                currentLabels.add(key);
            }
        }

        if (uniqueNew.length > 0) {
            dynamicItems = dynamicItems.concat(uniqueNew);
        }
    }
}
