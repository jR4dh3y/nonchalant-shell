# <img src="./assets/nonchalant/nonchalant-logo-color.svg" alt="" width="40" height="40"> Nonchalant Shell

**Nonchalant Shell** is a Niri-first Wayland desktop shell built with
[Quickshell](https://quickshell.org).

## Hard fork

This project is a **hard fork** of
[Ambxst](https://github.com/Axenide/Ambxst) by
[Axenide](https://github.com/Axenide).

It is not Ambxst, does not track Ambxst as an upstream merge target for
day-to-day work, and ships under its own name, branding, config paths, and
release process. The fork keeps a lean runtime focus:

- wallpaper
- one unified bar
- floating run menu
- lockscreen
- settings and desktop widgets
- reactive JSON configuration

Multi-monitor support uses Quickshell `Variants` on `Quickshell.screens`.

## Features

- Runs directly on [Niri](https://github.com/YaLTeR/niri) via its JSON event stream
- Normalized monitor, workspace, and window state for multi-monitor setups
- Unified bar with workspaces/taskbar, clock, system status, and systray
- Floating run menu and power menu
- Wallpaper picker and secure `WlSessionLock` session lock
- Searchable settings with section history, previews, and the existing configuration domains
- Desktop widget editor with Modern, Analogue, and Sticker themes
- Synchronized lyrics in the media players, desktop widgets, and lockscreen
- Separate configuration, per-shell state, cache, data, and IPC paths

## Showcase

### Island bar

<img src="./assets/demos/bar-island.png" alt="Island bar" width="100%">

<details>
<summary>View previews</summary>

| | |
|---|---|
| **Launcher** — search and launch apps from the island<br><img src="./assets/demos/launcher.gif" alt="Launcher" width="100%"> | **Dashboard** — controls, media and quick toggles<br><img src="./assets/demos/dashboard.gif" alt="Dashboard" width="100%"> |
| **Wallpaper picker**<br><img src="./assets/demos/wallpapers.gif" alt="Wallpaper picker" width="100%"> | **System monitor**<br><img src="./assets/demos/system-monitor.gif" alt="System monitor" width="100%"> |
| **Sound**<br><img src="./assets/demos/sound.gif" alt="Sound popup" width="100%"> | **Wi-Fi**<br><img src="./assets/demos/wifi.gif" alt="Wi-Fi popup" width="100%"> |
| **Calendar**<br><img src="./assets/demos/calendar.gif" alt="Calendar popup" width="100%"> | **Power menu**<br><img src="./assets/demos/powermenu.gif" alt="Power menu" width="100%"> |
| **Weather**<br><img src="./assets/demos/weather.gif" alt="Weather popup" width="100%"> | **Battery & power profile**<br><img src="./assets/demos/battery.gif" alt="Battery popup" width="100%"> |

</details>

### Classic bar

<img src="./assets/demos/bar-classic.png" alt="Classic bar" width="100%">

<details>
<summary>View previews</summary>

| | |
|---|---|
| **Launcher**<br><img src="./assets/demos/launcher-bar.gif" alt="Launcher, classic bar" width="100%"> | **Dashboard**<br><img src="./assets/demos/dashboard-bar.gif" alt="Dashboard, classic bar" width="100%"> |
| **Wallpaper picker**<br><img src="./assets/demos/wallpapers-bar.gif" alt="Wallpaper picker, classic bar" width="100%"> | **System monitor**<br><img src="./assets/demos/system-monitor-bar.gif" alt="System monitor, classic bar" width="100%"> |
| **Power menu**<br><img src="./assets/demos/powermenu-bar.gif" alt="Power menu, classic bar" width="100%"> | **Weather**<br><img src="./assets/demos/weather-bar.gif" alt="Weather popup, classic bar" width="100%"> |
| **Battery & power profile**<br><img src="./assets/demos/battery-bar.gif" alt="Battery popup, classic bar" width="100%"> | |

</details>

## Direct commands

The shell exposes lightweight commands through its IPC runner. For example,
`nonchalant run wallpapers` opens the wallpaper picker on the focused monitor
and toggles it closed when invoked again. This can be bound from Niri with:

```kdl
Mod+Shift+W hotkey-overlay-title="Open Wallpapers" { spawn "nonchalant" "run" "wallpapers"; }
```

### Settings, widgets, and lyrics

```bash
nonchalant run settings
nonchalant run widgets
```

The widgets command toggles the desktop editor. Add a widget from the gallery,
drag it into position, then use its inspector to choose a supported size and
appearance. A selected widget also has a lower-right resize handle.
Notes and audio spectra can also be placed on screen edges.
Layout and appearance are saved in `nonchalant/config/desktop.json` under
`$XDG_CONFIG_HOME`. Editing is suspended on fullscreen outputs and dismissed
when its output changes workspace.

The gallery includes media, timer, Claude, Codex, battery, volume, brightness,
network, Bluetooth, weather, GitHub, system statistics, updates, pet, games,
calendar, notes, tasks, clock, photos, spectrum, and lyrics. Notes, tasks, and
game scores use the shell's state directory under `$XDG_STATE_HOME/nonchalant`.
Claude and Codex usage comes from local session
records, not account billing or quota APIs.
GitHub uses the username configured in Desktop settings. Update checks use
available package-manager tools; they do not install packages. Audio spectra
require `cava`.

Settings retain the existing Network, Bluetooth, Mixer, AI, and detailed theme
controls. The port uses Nonchalant's configuration store and Niri integration,
not Impasto's profiles, updater, or Hyprland controllers.

Lyrics follow the selected MPRIS player. Timed lines follow playback and can be
clicked to seek; plain lyrics scroll manually. Shell settings provide separate
bar and lockscreen switches. When a lyrics view is visible, track title, artist,
album, and duration are sent to [LRCLIB](https://lrclib.net). Results are cached
under `$XDG_STATE_HOME/nonchalant/lyrics`. Hidden views do not start new lookups
or retries; a lookup already in progress can finish after its view closes.
Retries are scheduled by the active lyrics service, not by the Python helper.
The lyrics helper and desktop data helpers require Python 3.


## Run the development tree

Install Quickshell and the runtime tools needed by the shell. Install fonts once,
then run from a checkout:

```bash
./scripts/install-fonts.sh
qs -p /path/to/nonchalant-shell
```

Or use the CLI wrapper:

```bash
./cli.sh
```

The installer and Nix package are still inherited scaffolding and may need
adjustment for this fork.

## Attribution and license

Nonchalant Shell is derived from Ambxst by Axenide. Full copyright and
contributor history from that lineage is preserved in this repository’s Git
history.

The settings presentation, desktop widgets, games, and lyrics port incorporate
work from [Impasto](https://github.com/andreumassanet/impasto) by Andreu Massanet,
based on revision `6d759aa3fe16e3b40641beeb9b24e3c4afcfeefe`. That upstream is
GPLv3-licensed; its retained source notices apply to the incorporated work.

This project is licensed under the GNU Affero General Public License v3.0 or
later. See [LICENSE](./LICENSE).
