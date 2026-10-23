# Deck

Select **Settings → Shell → Bar → Style → Deck**. Position chooses the top or bottom edge.

![Deck rendered on a disposable Niri session](../assets/demos/deck-bar.png)

Deck keeps the desktop footprint small: at the default 14px font it draws a 32px bar and reserves 40px including both gaps. The workspace strip, window tabs, and status strip occupy three adjacent zones. The control drawer reserves no extra space while closed. Its outer width and height stay fixed across pages, bounded by the output dimensions. All eight pages remain visible in a sidebar: Controls, Connections, Windows, Today, Inbox, Tray, Wallpapers, and Resources.

## Design idea: a console for the session

Deck treats the session like a mixing console. Every level is a channel strip, every tab tells you its state before you open it, and every page opens with one line of current state. The goal is to read the session at a glance, then adjust it with one direct gesture, rather than browse a settings panel.

![Controls as channel strips beside the session rack](../assets/demos/deck-controls.png)

- **Channel strips.** Output, Mic, and Display are vertical faders. Each strip has a large live readout at the top, a full-height track you can click, drag, or scroll, and its own switch underneath. Output and Mic have working mute switches. Display shows a passive icon because brightness cannot be muted. The rack beside the strips holds the slower settings: output device choice (when there is more than one device), media transport with an inline scrubber, battery state, power profiles as a checked list, and, at the bottom, Do not disturb (with its On/Off state), Sound mixer, and the power menu.
- **Meters share the grammar.** Resources uses the same strips, read-only: CPU, Memory, and GPU (or CPU heat when there is no GPU). The rack next to them lists clock, heat, memory in GB, GPU name, and network rates. Levels look the same everywhere, so a high reading looks high on either page.
- **Live index.** Each sidebar tab shows a trailing value: output volume or Muted, Offline, window count, today's temperature, waiting notifications or Quiet, background app count, and live CPU while sampling. A glance at the closed list tells you which page needs attention.
- **Internal groups.** Controls separates output devices, playback, power, and session actions. Connections uses an enclosed Wi-Fi/Bluetooth selector, with connected and available networks separated; Bluetooth separates connected, paired, and available devices. Workspace groups and individual notifications have inset surfaces. The sidebar names the current page, so there is no repeated header. Settings and Close sit at the foot of the sidebar.
- **Today reads as a date first.** A large day numeral, weekday, month, ISO week, and weather sit beside the month grid. Weekends are muted, the trailing sixth week is hidden when empty, and Today is only enabled when you are viewing another month.
- **Windows grouped by workspace.** Rows sit under their workspace with a count, and the shown workspace is marked. Moving a window offers compact workspace numbers inline.
- **Wallpapers as thumbnails.** A responsive thumbnail grid replaces the file list.
- **Workspace pips.** In the bar, each workspace number shows up to four occupancy pips, replacing the old "1 · 2" text. Occupied workspaces are visible without reading.

![Resources as read-only channel meters](../assets/demos/deck-resources.png)

![Today with the date readout beside the month](../assets/demos/deck-today.png)

![Windows grouped by workspace](../assets/demos/deck-windows.png)

These screenshots come from a disposable Niri session without audio or brightness hardware, so the Output, Mic, and Display strips show "—". Resources readings are the host's read-only CPU, memory, and GPU values sampled during the capture.

## Daily actions

- The left strip shows workspace numbers with occupancy pips. Click to switch, or scroll a workspace button to move between workspaces.
- The middle strip exposes each window on the current workspace with its own app icon and title. Click to focus, middle-click to close, and scroll to cycle windows. Right-click opens the window list.
- The status strip shows connection, volume, battery when available, notifications, and time. Scroll volume to adjust; right-click to mute. Click the time to open Today.
- The volume button opens Controls. Drag, click, or scroll a channel strip; its switch mutes the channel. Media appears in the rack only while a player is available; non-seekable playback hides the scrubber.
- Connections exposes Wi-Fi networks and Bluetooth devices. Windows provides search, focus, targeted close, and move-to-workspace actions. Inbox supports notification actions, Do not disturb, Clear all, and dismissal. Tray supports activation and nested application menus.
- `qs ipc call nonchalant run <page>` opens a drawer page directly: `controls`, `connections`, `windows`, `today`, `alerts`, `tray`, `wallpapers`, or `stats`. Running it again closes the drawer.
- Escape or an outside click closes the drawer. Focusing a window or changing workspace dismisses it and returns keyboard ownership to the desktop. Left/Right (and Up/Down outside a focused fader) move between pages.

On narrower screens, window tabs first reduce to icons; on the smallest screens, the window list remains accessible in the drawer. Additional connection, power, notification, and tray controls remain accessible there. The clock stays inline at the same font size. Empty workspaces leave the middle zone transparent, and populated window titles use middle elision to preserve distinguishing endings.

## Implementation and interaction surfaces

`layouts/DeckBar.qml` owns the compact geometry. `deck/` contains dedicated workspace and window strips, buttons, channel strips (`DeckChannel`), the playback scrubber (`DeckFader`), controls, connection lists, window search/move rows, calendar, notification list, wallpaper list, tray/menu navigation, and drawer transition controller. Styling primitives and system services are shared with the shell. Existing Clock, NonchalantTaskbar, dashboard, and island panel compositions are not embedded.

`DeckActions` releases popup ownership before window/workspace focus changes. `DeckDrawer` owns open, close, route replacement, keyboard focus, and per-output state. Fullscreen, overview, hiding the bar, style replacement, and destruction release popup ownership. Resource sampling runs only on the Resources page. Bluetooth discovery started by the drawer stops when leaving its connection page.

Every button—including window move/close rows, workspace destinations, notification actions, menu items, and media controls—uses the complete `DeckAction` surface for coherent press, hover, focus, and disabled feedback. Explicit Tab, Icon, Action, and Tile kinds distinguish navigation, utilities, text actions, and thumbnails without duplicating input behavior. The optional `detail` slot carries a row's live value. Slider handles and text inputs retain native keyboard behavior. Window and workspace strips follow the active item when overflowing.

## Verification

`python3 -m unittest tests.e2e.test_deck_runtime` exercises populated geometry at both edges, the compact footprint, action dispatch, window search and movement, vertical channel faders that fit the fixed drawer, mute controls, the live tab index and header-free sidebar, workspace occupancy pips, do-not-disturb, IPC routes, Escape/outside dismissal, calendar arithmetic, hidden input, and sampling lifetime.

`python3 tests/runtime/run_compositor.py --compositor niri --shell --style deck` exercises the full shell on a disposable compositor and captures every Deck drawer page (`deck-<page>.png`) with live clients. Hardware audio/brightness, real network authentication/pairing, mixed-scale monitor hotplug, and physical output rendering still require hardware acceptance.

With `dbus-next` installed in a disposable environment, `DECK_TEST_PYTHON=/path/to/python python3 -m unittest tests.e2e.test_deck_runtime` additionally verifies real tray activation, nested menu dispatch, disabled actions, and removal using the private D-Bus fixture.

The icon font is bundled from Phosphor Web v2.1.2 and registered by `Icons.qml`; it does not rely on the host substituting the requested family. See `assets/fonts/README.md` for provenance and license.

### Grouping change coverage

The shared drawer header is removed on all eight pages. Settings and Close remain in the sidebar; Escape, outside dismissal, direct IPC routes, and page selection retain their existing behavior. The taskbar uses its selected background without an extra underline. Controls, both connection modes, workspace groups, notifications, and resource details use shared inset sections. Today and Wallpapers already have a calendar and thumbnail grid, so they need no additional grouping; Tray retains its app/menu navigation. Config defaults and compositor backends are unaffected.
