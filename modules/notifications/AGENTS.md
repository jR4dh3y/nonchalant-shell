# AGENTS.md: modules/notifications/

## OVERVIEW
Notification popup system built on Quickshell.Services.Notifications. Handles display, grouping, dismissal, and action invocation for notifications.

## STRUCTURE
```
modules/notifications/
├── notification_utils.js          # Time formatting, body sanitization
├── NotificationToastStack.qml     # Active overlay toast stack (rendered inside UnifiedShellPanel)
├── NotificationDelegate.qml       # Core notification delegate for history & popups
├── NotificationAppIcon.qml        # App icon/image with fallback chain
├── NotificationAnimation.qml     # Dismiss animation (slide + fade)
├── NotificationDismissButton.qml # Dismiss action button
├── NotificationActionButtons.qml # Interactive notification action buttons
├── NotificationGroup.qml         # Grouping logic for notification history
└── NotificationGroupExpandButton.qml # Expand toggle
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Toast stack | `NotificationToastStack.qml` | Embedded in `UnifiedShellPanel.qml` |
| Core display | `NotificationDelegate.qml` | Grouped and single mode presentation |
| Action buttons | `NotificationActionButtons.qml` | Action invocation (`attemptInvokeAction`) |
| Icon handling | `NotificationAppIcon.qml` | Image > appIcon > Icons fallback chain |
| Dismiss animation | `NotificationAnimation.qml` | Scale + opacity + slide |
| Body & Time | `notification_utils.js` | Body text parsing and friendly time formatting |

## CONVENTIONS

- **Urgency levels**: Use `NotificationUrgency.Normal` / `NotificationUrgency.Critical` from `Quickshell.Services.Notifications`.
- **Critical styling**: Critical toasts MUST use `Colors.error` border and `DiagonalStripePattern`.
- **Action Invocation**: Card body click invokes default action (`Notifications.attemptInvokeAction(id, "default")`). Action buttons invoke specific keys. Never blanket-dismiss on card clicks.
- **StyledRect containers**: All card backgrounds, action buttons, and icons must use `StyledRect`. Never use raw `Rectangle`.
- **Animation duration**: Read `Config.animDuration` (never hardcode milliseconds).
- **Strong Typing**: Strongly type notification properties (`Notif`, `int id`, `string summary`).

## ANTI-PATTERNS

- Trapping clicks with full-card `MouseArea` that silently dismisses without invoking the notification's default action.
- Using raw `Rectangle` for backgrounds or borders instead of `StyledRect`.
- Hardcoding animation durations (e.g. `duration: 300` or `800`) instead of `Config.animDuration`.
- Missing urgency checks for critical notifications.
- Direct notification removal without animation callbacks.
