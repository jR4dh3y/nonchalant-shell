import Quickshell.Wayland as Wayland

// Keep Ambxst's public service API while using Quickshell's native
// ext-idle-notify implementation. This works on Niri without axctl.
Wayland.IdleMonitor {}
