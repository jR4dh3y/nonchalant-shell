pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.theme

CircularBarMeter {
    id: root

    readonly property var currentMonitor: Brightness.getMonitorForScreen(bar.screen)

    value: currentMonitor?.brightness ?? 0.5
    icon: Icons.sun
    progressColor: Styling.srItem("overprimary")
    tooltipText: "Brightness " + Math.round(value * 100) + "%"
    clickEnabled: false

    onAdjusted: newValue => Brightness.setBrightnessForScreen(root.bar.screen, newValue)
}
