# AGENTS.md: modules/lockscreen/

## OVERVIEW
Lock screen UI with PAM authentication via WlSessionLockSurface.

## LOCK CURTAIN (no screenshots)
While locked, niri draws only the session-lock surface: nothing behind it,
and it has no lock animation. So lock/unlock fades run on `LockCurtain`, a
normal overlay layer that niri composites over the *live* desktop:
1. `LockscreenService.lock()` raises `GlobalStates.lockCurtainShown`. Each
   screen's curtain maps and fades `LockBackdrop` in over the desktop while
   swallowing keyboard/pointer input.
2. After `curtainFadeMs`, the service engages the session lock. The lock
   surface's frame-1 is the same `LockBackdrop`, so the switch is invisible;
   only the clock/password chrome animates in.
3. On PAM success the chrome animates out, then `finishUnlock()` releases the
   lock and lowers the curtain. The curtain stayed opaque (unseen) during the
   lock, so the release reveals it, and it fades out onto the real desktop.
4. `secureWatchdog`: if niri never confirms the lock (`lockscreenSecure`), the
   curtain is dropped rather than left as a fake lock with no way to unlock.
Never reintroduce desktop screenshots (stale frames, UI-thread stalls,
private images). Never fade the backdrop inside `LockScreen.qml`: it must
match the curtain pixel-for-pixel at both handoffs.

## STRUCTURE
```
modules/lockscreen/
├── LockScreen.qml       # Main WlSessionLockSurface component
├── LockCurtain.qml      # Overlay layer that fades the lock in/out
└── LockBackdrop.qml     # Dimmed wallpaper shared by curtain + lock surface
config/pam/
└── password.conf        # Custom PAM rules for lockscreen
```
Related: `modules/widgets/dashboard/widgets/LockPlayer.qml` (music player on lock screen).

## WHERE TO LOOK
| Symbol | Location | Role |
|--------|----------|------|
| `WlSessionLockSurface` | `LockScreen.qml` | Root; handles Wayland session lock protocol |
| `PamContext` | `LockScreen.qml` | PAM authentication via `Quickshell.Services.Pam` |
| `LockCurtain` | `LockCurtain.qml` | Overlay fade over the live desktop around the lock |
| `LockBackdrop` | `LockBackdrop.qml` | Dimmed lockscreen wallpaper (identical on curtain and lock) |
| `authPasswordHolder` | `LockScreen.qml` | Transient memory holder for password |
| `wrongPasswordAnim` | `LockScreen.qml` | Shake animation on auth failure |
| `unlockTimer` | `LockScreen.qml` | Calls `LockscreenService.finishUnlock()` after the chrome exit animation |

Key behaviors:
- On lock: fade the curtain in, engage lock, animate chrome in, focus password input on primary screen.
- On auth: verify PAM response requirements: send password ONLY when `!pamAuth.responseVisible` (echo off), send username when `pamAuth.responseVisible` (echo on). Clear password immediately.
- On unlock: animate chrome out, release the lock, fade the curtain out onto the live desktop.
- On failure: shake animation, clear password, provide immediate visual error feedback.

## CONVENTIONS
- **PAM Message Safety**: ALWAYS check `!pamAuth.responseVisible` before transmitting password. Never echo passwords into username or info prompts.
- **Immediate Credential Wipe**: Set `authPasswordHolder.password = ""` immediately after `pamAuth.respond()`.
- **Curtain handoff**: `LockCurtain` and `LockScreen` must render the same `LockBackdrop`; keep backdrop changes in that one component.
- **Multi-Monitor Focus**: Only grant active focus to the password field on the primary screen (`root.screen === Quickshell.screens[0]`) to prevent focus fighting across displays.

## ANTI-PATTERNS
- Never log passwords, tokens, or raw PAM prompt responses.
- Retaining plaintext password in memory after sending PAM response.
- Feeding passwords to `PromptEchoOn` prompts (causes passwords to be logged as usernames in `/var/log/auth.log`).
- Capturing the desktop (screencopy/grab) for lock transitions; use the curtain.