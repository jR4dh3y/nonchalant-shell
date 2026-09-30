# AGENTS.md: modules/lockscreen/

## OVERVIEW
Lock screen UI with PAM authentication via WlSessionLockSurface.

## LOCKSHOT (flash fix)
The lock surface's frame-1 must show the *desktop as the user saw it*
(windows included), not the clean wallpaper - otherwise niri's output switch
to the locked frame flashes the bright wallpaper. Flow:
1. `LockscreenService.lock()` → `GlobalStates.beginLockshotPrep()`.
2. `LockshotCapture.qml` (one per screen, hosted on the overlay
   `UnifiedShellPanel`) creates a *fresh* hidden `ScreencopyView` (Loader),
   waits for `hasContent`, then `grabToImage()`s it and unloads the view.
   Never host it on the background wallpaper window: `grabToImage()` waits for
   the host's next frame, and niri withholds frame callbacks from an occluded
   background layer (a maximized window made the grab take ~600ms, past the
   400ms prep timeout, so the lock showed the plain gray scrim). Never
   reuse a view: it has no per-frame signal, so a reused view gets grabbed
   with its previous (stale) frame. The
   `ItemGrabResult` goes to `GlobalStates.notifyLockshotPrepared()` (stored in
   `GlobalStates.lockshots`). The shot never touches disk: PNG encoding on
   the UI thread stalled the shell right before the lock engaged.
3. Service engages the lock once all screens report (400ms timeout fallback).
4. `LockScreen.qml` frame-1 shows the shot synchronously from the grab's
   `itemgrabber:` URL, then crossfades to the wallpaper on startAnim.
5. `LockscreenService.finishUnlock()` drops the grab results.
If no shot exists, the wallpaper is only ever revealed dimmed - never at
full brightness. Do not reintroduce a full-brightness wallpaper frame-1.

## STRUCTURE
```
modules/lockscreen/
├── LockScreen.qml       # Main WlSessionLockSurface component
└── LockshotCapture.qml  # Pre-lock desktop capture (hosted on the overlay panel)
config/pam/
└── password.conf        # Custom PAM rules for lockscreen
```
Related: `modules/widgets/dashboard/widgets/LockPlayer.qml` (music player on lock screen).

## WHERE TO LOOK
| Symbol | Location | Role |
|--------|----------|------|
| `WlSessionLockSurface` | `LockScreen.qml` | Root; handles Wayland session lock protocol |
| `PamContext` | `LockScreen.qml` | PAM authentication via `Quickshell.Services.Pam` |
| `shotImage` | `LockScreen.qml` | Displays the in-memory frame-1 desktop lockshot |
| `TintedWallpaper` | `LockScreen.qml` | Wallpaper with blur and dimming layer |
| `authPasswordHolder` | `LockScreen.qml` | Transient memory holder for password |
| `wrongPasswordAnim` | `LockScreen.qml` | Shake animation on auth failure |
| `unlockTimer` | `LockScreen.qml` | Sets `GlobalStates.lockscreenVisible = false` after exit animation |

Key behaviors:
- On lock: pre-capture lockshot via Wallpaper screencopy, engage lock, start entry animation, focus password input on primary screen.
- On auth: verify PAM response requirements: send password ONLY when `!pamAuth.responseVisible` (echo off), send username when `pamAuth.responseVisible` (echo on). Clear password immediately.
- On unlock: crossfade, trigger unlock animation, and release the in-memory lockshots.
- On failure: shake animation, clear password, provide immediate visual error feedback.

## CONVENTIONS
- **PAM Message Safety**: ALWAYS check `!pamAuth.responseVisible` before transmitting password. Never echo passwords into username or info prompts.
- **Immediate Credential Wipe**: Set `authPasswordHolder.password = ""` immediately after `pamAuth.respond()`.
- **Lockshot In Memory**: Keep desktop captures as in-memory `ItemGrabResult`s; never write them to disk (UI-thread stall + unencrypted desktop images on disk). Release them on unlock.
- **Backdrop fades**: Gate backdrop `Behavior`s on `backdropAnimArmed`, set *before* `startAnim`/`lockscreenUnlocking` change. Gating on the same flag that changes the target races binding evaluation order and snaps the fade.
- **Multi-Monitor Focus**: Only grant active focus to the password field on the primary screen (`root.screen === Quickshell.screens[0]`) to prevent focus fighting across displays.

## ANTI-PATTERNS
- Never log passwords, tokens, or raw PAM prompt responses.
- Retaining plaintext password in memory after sending PAM response.
- Feeding passwords to `PromptEchoOn` prompts (causes passwords to be logged as usernames in `/var/log/auth.log`).
- Writing desktop screenshots to disk (`$XDG_RUNTIME_DIR` or elsewhere).