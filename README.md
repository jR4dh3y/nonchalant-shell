<p align="center">
  <img src="./assets/nonchalant/nonchalant-logo-color.svg" alt="Nonchalant Shell" width="420" />
</p>

# Nonchalant Shell

Nonchalant Shell is a Niri-first desktop shell built with Quickshell. It is a
hard fork of [Ambxst](https://github.com/Axenide/Ambxst) and is currently in the
early bring-up stage.

The current baseline keeps Ambxst's wallpaper and session-lock UI while the
rest of the shell moves toward direct Quickshell, Wayland, and Niri
integrations. Lock/login integration will eventually live in a separate
module.

## Current state

- Runs directly on Niri and follows its JSON event stream.
- Provides normalized monitor, workspace, and window state to the inherited UI.
- Uses Quickshell's native Wayland idle monitor instead of `axctl`.
- Keeps the inherited wallpaper picker and secure `WlSessionLock` screen.
- Uses isolated `nonchalant` config, state, cache, data, and IPC paths.

The bar and central menu are next. The intended design is a compact segmented
bar with the named-workspace/taskbar workflow on the left, date and menu access
in the middle, and a small native system-status cluster on the right.

## Run the development tree

Install Quickshell and the runtime tools required by the inherited Ambxst
features. Install the shell's icon and interface fonts once, then run:

```bash
./scripts/install-fonts.sh
qs -p /path/to/nonchalant-shell
```

The installer and Nix package are still inherited scaffolding and are not the
supported way to run this fork yet.

## Scope

`qylock` and `skwd-wall` are design and implementation references only. They
are not runtime dependencies. `skwd-wall` is being rewritten in Rust, so
Nonchalant keeps the inherited wallpaper implementation for now.

## Attribution and license

Nonchalant Shell is derived from Ambxst by Axenide and retains the upstream
copyright and contributor history. See the Git history for the full lineage.

This project is licensed under the GNU Affero General Public License v3.0 or
later. See [LICENSE](./LICENSE).
