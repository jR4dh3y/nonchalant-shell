# COMPONENTS KNOWLEDGE BASE

## OVERVIEW
Atomic design library for Nonchalant Shell. Every themed container in the shell ultimately uses `StyledRect`. Components enforce theme reactivity, native font rendering, and strong typing.

## STRUCTURE
### Layout & Containers
| Component | Role |
|-----------|------|
| `StyledRect.qml` | **THE** base themed container. `variant` selects style from `Styling.qml`. Handles borders, gradients, and radii |
| `Separator.qml` | Visual divider between sections |
| `ActionGrid.qml` | Flexible button grid (row or grid layout). Used by PowerMenu, ToolsMenu |

### Input
| Component | Role |
|-----------|------|
| `SearchInput.qml` | Text entry with icon, prefix, clear on escape control |
| `StyledSlider.qml` | Standard slider (volume, brightness, progress) |
| `PositionSlider.qml` | Media position/seek slider (requires `MprisPlayer`) |
| `CircularSeekBar.qml` | Circular arc seekbar for media players |
| `CircularControl.qml` | Circular knob for volume/mic |
| `ToggleButton.qml` | Icon button with tooltip and toggle state |

### Display & Feedback
| Component | Role |
|-----------|------|
| `StyledText.qml` | Shared `Text` with `NativeRendering` + full hinting (avoids DF soft halo) |
| `StyledToolTip.qml` | Themed tooltip with `show` and `description` API |
| `BarPopup.qml` | Base for bar flyout popups. Requires `anchorItem` |
| `OptionsMenu.qml` | Dropdown option selector |

### Animation & Visuals
| Component | Role |
|-----------|------|
| `WavyLine.qml` | Signature animated progress line rendered via 2D Canvas |
| `CarouselProgress.qml` | Progress wrapper |
| `DiagonalStripePattern.qml` | Decorative pattern overlay for critical/accent states |
| `Tinted.qml` / `TintedWallpaper.qml` | Color tint overlays with shader pipeline |

## CONVENTIONS
- **StyledRect variants**: Always pass `variant` as one of: `"pane"`, `"popup"`, `"common"`, `"internalbg"`, `"focus"`. Variant config comes from `Styling.getStyledRectConfig()`.
- **Strong Typing**: Components must declare explicit types (`required property Item anchorItem`, `required property MprisPlayer player`). Never use untyped `property var` for object references.
- **Null Safety**: In `StyledRect`, guard access to variant border configurations (`borderData?.[0]`, `borderData?.[1]`).
- **Reactive styling**: All components use `Config.resolveColor()` and `Styling.radius()`.
- **BarPopup pattern**: Requires an `anchorItem` to position relative to the shell panel.
- **Tooltips**: Use `StyledToolTip` with properties `show` and `description`.

## ANTI-PATTERNS
- Using raw `Rectangle` instead of `StyledRect` for containers or highlights.
- Hardcoding colors, radii, or font sizes instead of using `Colors.*`, `Styling.radius()`, `Styling.fontSize()`.
- Declaring untyped `property var` when `Item`, `MprisPlayer`, or primitive types are known.
- Retaining inert, non-functional shims (`BgShadow`, `Shadow`, `Outline`).
