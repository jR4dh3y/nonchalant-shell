# AGENTS.md: modules/lockscreen/

## OVERVIEW
Lock screen UI with PAM authentication via WlSessionLockSurface.

## LOCKSHOT (flash fix)
The lock surface's frame-1 must show the *desktop as the user saw it*
(windows included), not the clean wallpaper - otherwise niri's output switch
to the locked frame flashes the bright wallpaper. Flow:
1. `LockscreenService.lock()` → `GlobalStates.beginLockshotPrep()`.
2. Each `Wallpaper.qml` window (one per screen) captures its output via a
   hidden `ScreencopyView` + `grabToImage()`, saves to
   `$XDG_RUNTIME_DIR/nonchalant-lockshot-<screen>.png`, preloads it into the
   pixmap cache, and reports via `GlobalStates.notifyLockshotPrepared()`.
3. Service engages the lock once all screens report (400ms timeout fallback).
4. `LockScreen.qml` frame-1 shows the shot (cache hit via matching
   source+sourceSize), then crossfades to the wallpaper on startAnim.
If no shot exists, the wallpaper is only ever revealed dimmed - never at
full brightness. Do not reintroduce a full-brightness wallpaper frame-1.

## STRUCTURE
```
modules/lockscreen/
└── LockScreen.qml       # Main WlSessionLockSurface component
config/pam/
└── password.conf        # Custom PAM rules for lockscreen
```
Related: `modules/widgets/dashboard/widgets/LockPlayer.qml` (music player on lock screen).

## WHERE TO LOOK
| Symbol | Location | Role |
|--------|----------|------|
| `WlSessionLockSurface` | `LockScreen.qml` | Root; handles Wayland session lock protocol |
| `PamContext` | `LockScreen.qml` | PAM authentication via `Quickshell.Services.Pam` |
| `shotImage` | `LockScreen.qml` | Displays pre-captured frame-1 desktop lockshot |
| `TintedWallpaper` | `LockScreen.qml` | Wallpaper with blur and dimming layer |
| `authPasswordHolder` | `LockScreen.qml` | Transient memory holder for password |
| `wrongPasswordAnim` | `LockScreen.qml` | Shake animation on auth failure |
| `unlockTimer` | `LockScreen.qml` | Sets `GlobalStates.lockscreenVisible = false` after exit animation |

Key behaviors:
- On lock: pre-capture lockshot via Wallpaper screencopy, engage lock, start entry animation, focus password input on primary screen.
- On auth: verify PAM response requirements: send password ONLY when `!pamAuth.responseVisible` (echo off), send username when `pamAuth.responseVisible` (echo on). Clear password immediately.
- On unlock: crossfade, trigger unlock animation, and unlink lockshot files from `$XDG_RUNTIME_DIR`.
- On failure: shake animation, clear password, provide immediate visual error feedback.

## CONVENTIONS
- **PAM Message Safety**: ALWAYS check `!pamAuth.responseVisible` before transmitting password. Never echo passwords into username or info prompts.
- **Immediate Credential Wipe**: Set `authPasswordHolder.password = ""` immediately after `pamAuth.respond()`.
- **Lockshot Cleanup**: Unlink lockshot image captures in `$XDG_RUNTIME_DIR` when unlocking to prevent persistent unencrypted desktop images on disk.
- **Multi-Monitor Focus**: Only grant active focus to the password field on the primary screen (`root.screen === Quickshell.screens[0]`) to prevent focus fighting across displays.

## ANTI-PATTERNS
- Never log passwords, tokens, or raw PAM prompt responses.
- Retaining plaintext password in memory after sending PAM response.
- Feeding passwords to `PromptEchoOn` prompts (causes passwords to be logged as usernames in `/var/log/auth.log`).
- Leaving unencrypted desktop screenshots in `$XDG_RUNTIME_DIR` after unlocking.