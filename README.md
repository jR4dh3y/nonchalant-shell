<p align="center">
  <img src="./assets/nonchalant/nonchalant-logo-color.svg" alt="Nonchalant Shell" width="420" />
</p>

# Nonchalant Shell

**Nonchalant Shell** is a Niri-first Wayland desktop shell built with
[Quickshell](https://quickshell.org). It is a hard fork of
[Ambxst](https://github.com/Axenide/Ambxst), reworked toward a lean runtime:
wallpaper, one unified bar, a floating run menu, and a lockscreen — driven by a
reactive JSON configuration system.

## Features

- Runs directly on [Niri](https://github.com/YaLTeR/niri) via its JSON event stream
- Normalized monitor, workspace, and window state for multi-monitor setups
- Unified bar with workspaces/taskbar, clock, system status, and systray
- Floating run menu and power menu
- Wallpaper picker and secure `WlSessionLock` session lock
- Isolated `nonchalant` config, state, cache, data, and IPC paths

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

Nonchalant Shell is derived from Ambxst by Axenide and retains the upstream
copyright and contributor history. See the Git history for the full lineage.

This project is licensed under the GNU Affero General Public License v3.0 or
later. See [LICENSE](./LICENSE).
