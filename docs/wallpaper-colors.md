# Wallpaper colors

Select **Wallpaper** in the wallpaper picker's scheme menu, or run
`nonchalant run wallpaper-colors`. Both clear the active static preset and
regenerate wallpaper colors. New wallpaper state defaults to Wallpaper.
Existing Material schemes and presets retain their saved selections.

**Content** and **Expressive** start from Matugen's first-ranked wallpaper
color. Their **Saturated accents** variants favor stronger accent colors.
The bar, panel and hover surfaces use the same subdued neutral colors in
either variant. Previously saved scheme selections keep their accent policy.
**Tonal Spot (Contrast)** raises Matugen's contrast to 0.5. **Smart
(Material)** lets Matugen choose a scheme based on the image. Versions
before Matugen 4.2 use Tonal Spot for that option.

Use the per-screen toggle in the wallpaper picker to give that display its
own wallpaper and palette. The shell's bars, dashboards, menus, OSDs, and
notifications follow the output they appear on. Clearing the override returns
that display to the global palette. A static preset applies on every output
until you select a wallpaper-driven scheme again.

Apply prepares the new image and palette before replacing the visible pair.
The wallpaper picker and lockscreen follow the applied selection. If an
image cannot be decoded, the previous wallpaper and palette stay in place
and you can retry the same file. Clearing a display override prepares the
global image before switching back to it.

Kitty, GTK, Qt, Niri, and the other app exporters share the palette from the
global wallpaper or static preset. Changing a display override leaves their
palette alone.

## Extraction

The **Wallpaper** extractor samples visible pixels, quantizes them into 64
color clusters, and ranks clusters using population and perceptual chroma. It
selects up to six hues separated by at least 30 degrees in OKLab, then fills
available slots with distinct shades sampled from the image. Primary,
secondary, and tertiary use the first three samples, with lightness adjusted
for readable text.

Every Wallpaper accent and terminal color comes from the wallpaper. Legacy
names such as `red`, `green`, and `blue` identify terminal palette slots rather
than fixed hue families. Status roles are the exception: `error`/`danger`,
`warning`, and `success` keep red, amber, and green hues on every wallpaper and
only move lightness until they are readable (see [Status roles](#status-roles)).
A grayscale or single-hue image keeps a limited accent palette. Missing
slots reuse sampled colors. Wallpaper, Material and Wallust derive their
surfaces from the hue family covering the most area, counting neutral grays
together. The tint is capped at 0.015 OKLab chroma. These schemes share one
surface hierarchy, with brighter hover and control fills in dark mode and
darker fills in light mode. Material Monochrome stays gray. Static presets
and Noctalia-style Vibrant supply their own surface colors.

OLED overrides for every scheme live in the shared `ShellPalette.qml` type.

## Vibrant (Noctalia-style)

`scheme-noctalia-vibrant` ports the Vibrant scheme from
[Noctalia v5.5.0](https://github.com/noctalia-dev/noctalia/tree/c2573248a89470383e41b8e1ac432424691cbc1f)
(MIT, © 2026 noctalia-dev) in `scripts/noctalia_vibrant.py`. The module keeps
the upstream MIT notice and the Apache-2.0 attribution for the CAM16/HCT code
from material-color-utilities. The Apache-2.0 license ships alongside the module.
`wallpaper_palette.py --vibrant` calls it, so
the generator, validation, and publication steps match the Wallpaper scheme.

The steps match upstream:

1. Box-resize the image to 112×112 and keep every 16th pixel (784 samples).
2. Drop samples below CAM16 chroma 5 when at least 40 remain.
3. Group the samples into 20 Lab k-means clusters. Starting centroids are
   spread evenly by lightness.
4. Score each averaged centroid as
   `(chroma − tonePenalty − yellowPenalty) × count^0.3`. Five seeds come out,
   padded with 60° hue turns of the first seed.
5. Build both modes in HSL. Secondary and tertiary use seeds 2 and 3 when
   they are more than 30° from earlier accents. Otherwise they become 30° and
   60° turns of the primary. `error` is the first red seed, or `#fd4663`.
6. Build the surface ladder from seed 1's hue at fixed lightness levels:
   dark 0.06–0.24, light 0.78–0.96. Saturation is capped by hue band, with
   cyan pushed toward blue in dark mode. Surfaces are clearly tinted:
   panel roles reach 0.03–0.11 OKLab chroma.
7. Make text, outlines, and on-colors readable with upstream `ensureContrast`
   (OKLCH lightness search). Text needs 4.5:1 and outlines 3:1.
8. Derive palette-style terminal colors (`synthesizeTerminalPaletteTokens`).

A comparison with an unmodified upstream build covers the 10 example
wallpapers and 11 synthetic images, including JPEG, 1×1, upscaled, gray,
black, and white images. Every upstream token matched exactly in both modes,
including terminal colors: 2,604 values.

### Role mapping

| Nonchalant role | Noctalia v5 token |
| --- | --- |
| `background` | `surface` (= upstream `background`) |
| `surface`, `surfaceContainer` | `surface_container` |
| `surfaceDim`, `surfaceBright`, `surfaceVariant`, `surfaceContainerLowest/Low/High/Highest` | same-named token |
| `overBackground`, `overSurface` | `on_surface` |
| `overSurfaceVariant` | `on_surface_variant` |
| `outline`, `outlineVariant`, `shadow`, `scrim`, `surfaceTint` | same-named token |
| `inverseSurface`, `inverseOnSurface`, `inversePrimary`, `sourceColor` | same-named token |
| `primary/secondary/tertiary` + `Container`, `Fixed`, `FixedDim` | same-named token |
| `over<Accent>`, `over<Accent>Container`, `over<Accent>Fixed`, `over<Accent>FixedVariant` | `on_<accent>…` |
| `error`, `errorContainer`, `overError`, `overErrorContainer` | same-named token |
| `red`, `green`, `yellow`, `blue`, `magenta`, `cyan` | `terminal_normal_<slot>` (from `error`, `primary`, `secondary`, `tertiary`, `primary_fixed_dim`, `secondary_fixed_dim`) |
| `danger`, `overDanger` | `error` and an on-color, with lightness moved for 4.5:1 text on every panel role |
| `warning`, `success` + `over…` | none upstream; fixed amber and green hues, readable on every panel role |
| `lightRed` … `lightCyan` | `terminal_bright_<slot>` |
| `white` | `terminal_normal_white` (= `on_surface_variant`) |
| `<slot>Source`, `<slot>Value` | the scheme token the slot starts from |
| `<slot>Container`, `over<Slot>`, `over<Slot>Container` | Noctalia's container and on-color rules applied to the slot color |

Upstream sets `background` equal to `surface`. Its bar, panels, and OSD fill
with `Surface`, while cards and capsules use `SurfaceContainer`. Nonchalant
uses `background` for those outer fills and `surface` for the panes inside
them, so `surface` takes upstream `surface_container`. Otherwise every pane
would match its popup. The Wallpaper scheme already sets `surface` equal to
`surfaceContainer`.

The shell's default `theme.js` variants need no change:

| Variant | Fill | Text | Dark L (HSL) | Light L |
| --- | --- | --- | --- | --- |
| `bg`, `popup`, `internalbg` | `background` | `overBackground` | 0.12 | 0.90 |
| `pane`, `common` | `surface` | `overBackground` | 0.16 | 0.86 |
| `focus`, borders | `surfaceBright` | `overBackground` | 0.24 | 0.95 |
| `barbg` (opacity 0 by default) | `surfaceDim` | `overBackground` | 0.08 | 0.82 |
| `primary`, `secondary`, `tertiary`, `error` | accent | `over<Accent>` | accent | accent |

The `red`, `green`, and `yellow` slots are terminal colors here: `red` starts
from `error`, while `green` and `yellow` follow `primary` and `secondary`. The
shell never reads them for status. Upstream `error` stays token-exact, so it
can be the raw `#fd4663` seed at about 2:1 on light panels. `danger` keeps that
hue but moves lightness until it is readable text on `background`, `surface`,
`surfaceContainerHighest`, and `surfaceBright`. `warning` and `success` use the
same check.

### Upstream behavior that does not port exactly

- **Transparency:** upstream averages straight RGB, so fully transparent
  pixels contribute their hidden color. Nonchalant composites translucent
  images over black first. Opaque images are unaffected.
- **Decoding:** Pillow replaces upstream's wuffs, libjpeg, libwebp, JXL, and
  HEIF decoders. 8-bit PNG and baseline JPEG matched. Other formats can
  differ in the least significant bit, and a one-bit difference can move a
  k-means seed. Video wallpapers use the first frame from FFmpeg, as before.
- **Resize:** only the 784 box-filtered cells that upstream samples are
  computed, with its single-precision accumulation order.
- **Unreachable branch:** the k-means path for fewer samples than clusters is
  not ported. The 112×112 buffer always yields 784 samples.
- **Not emitted:** Noctalia's `hover`/`on_hover` (= `tertiary`), the other
  `terminal_*` tokens, and its template variables. Nonchalant's contract
  has no slots for them. The shell hover is a neutral state layer instead.
- **Legacy-role fill-ins:** upstream has no container or foreground for
  terminal colors. Nonchalant fills them with the upstream accent recipes.

Faithful quirks that are kept on purpose:

- A pure gray wallpaper gets red accents: gray has HSL hue 0, and Vibrant
  raises accent saturation to at least 0.7. Use the Wallpaper scheme for
  grayscale wallpapers.
- Secondary and tertiary may be hue turns rather than image colors.
- In dark mode `shadow` equals `background`. Light mode uses a light tinted
  shadow.
- In light mode, a darker on-color can replace white text on a
  mid-lightness accent.

Pillow supplies image extraction and is included in the Arch, Fedora, and Nix
dependencies. Material schemes use Matugen with Wallust as a fallback. Static
presets keep their existing palettes.

Generated palettes must match the complete color contract. The job publishes
a result only while its wallpaper, scheme, and light mode still match the
request. The global palette is written to `colors.json`. Display overrides
use separate `colors-<output>.json` files and fall back to the global palette
when extraction fails. Each Material invocation has its own temporary config
and output. FFmpeg decodes the first video frame, so color generation can
finish before thumbnails are available.

WebP and AVIF go through Qt's image loader. When Qt cannot decode the file,
the desktop uses a cached still decoded by Pillow, including AVIF files with
a WebP name. The lockscreen and overview use that same cached still.

## Status roles

Every published palette carries six status keys beside the Material roles:
`danger`, `overDanger`, `warning`, `overWarning`, `success`, `overSuccess`.
`ShellPalette` also exposes `dangerContainer` and `overDangerContainer` (the
error containers). GUI state reads these roles. The `red`, `yellow`, and
`green` slots remain terminal and exporter colors only.

| Source | `danger` | `warning` | `success` |
| --- | --- | --- | --- |
| Wallpaper | `error`, seeded from `#fd4663` | seeded from `#f0a01e` | seeded from `#3fb950` |
| Vibrant | upstream `error`, made readable | HSL hue 38° | HSL hue 135° |
| Material (Matugen) | `error` | custom `yellow` (blended) | custom `green` (blended) |
| Wallust fallback | `lightRed` | `lightYellow` | `lightGreen` |
| Static preset | authored `danger`, else `error` | authored `warning`, else `yellow` | authored `success`, else `green` |

Wallpaper and Vibrant status roles keep their hue and move lightness for
4.5:1 against the panel roles and their `over…` foreground. Matugen supplies
Material tones for its custom colors. The Wallpaper scheme's `error`
is now a status role too, so app exports that read `error` (Niri urgent
borders, Qt, pywal) get red rather than the first wallpaper seed. Kitty and
the other terminal colors still use the wallpaper slots.

`scripts/preset_palette.py` publishes static presets. It fills any missing
status key from the preset's own `error`, `yellow`, or `green` (and their
foregrounds) and keeps authored values. A reloaded `JsonAdapter` keeps the
previous value for a key the new file omits, so every published palette must
carry every key.

## Shell role map

Each window resolves its palette with `DisplayPalettes`, so these roles follow
the output a surface is on. App exporters keep using the global `Colors`.

| State | Treatment |
| --- | --- |
| Rest | Quiet surface variant (`pane`, `common`, `internalbg`) or none on flat pills. Primary text `overBackground`/`overSurface`, metadata `overSurfaceVariant`. |
| Hover | Neutral lift: the `focus` variant, or `HoverTint` (the `focus` item color at 10%, 16% pressed) on flat and accent-free pills. `HoverTint` stays off accent fills. Press keeps scale feedback without a color jump. |
| Keyboard focus | `FocusRing`, a 2px `primary` outline, separate from hover and selection. Used by the tray menu, Polkit field and buttons, settings search results, wallpaper scheme/mode/per-screen selectors, the model refresh button, and the control-menu tabs. |
| Active / selected | The active workspace uses a `primary` indicator and shows its label when empty. The shared taskbar and Left bar show app icons when it has windows. Open audio controls use a `primary` fill and its paired item color. Lower-emphasis selections such as today's date use `primarycontainer`. |
| Applied / occupied | Inactive occupied workspace labels use `secondary` text. Empty inactive workspace labels use `overSurfaceVariant`. Deck also marks occupancy with pips. Connected Wi-Fi and Bluetooth use `secondary` text. The notification count uses `secondarycontainer`. The applied wallpaper gets a secondary outline or label. |
| Inactive / muted | `overSurfaceVariant` ink and `outlineVariant` progress, in every OSD path including the Pills inline strip. Mute is not an error. |
| Status | `danger` text for urgent inactive workspaces and a danger glyph in Deck. Critical notifications, destructive power arming, and invalid passwords use `error` or `errorcontainer` fills with their item color. The Pills alert counter shows a danger cue while it holds a critical notification. `warning` and `success` indicate battery and audio levels, limited Wi-Fi, and charging. |
| Data and media | CPU, GPU, disk, and speaker volume `primary`; memory and microphone `secondary`; network, the media waveform, and the Left bar brightness gauge `tertiary`. |

Three StyledRect variants pair Material containers with their foregrounds:
`primarycontainer`, `secondarycontainer`, and `errorcontainer`. They are
additive theme keys with defaults, so saved themes and presets keep their
custom variants. Configured fills and item colors stay authoritative because
call sites read `Styling.srItem(variant)` or the rectangle's `item`.

The classic resource panel and Deck meters color data with
`ShellPalette.metricRole()`. The Left side-pane monitor and the Island/Pills
stats panel use the same series identities through StyledRect variants:

| Metric | Palette role |
| --- | --- |
| CPU | Primary below 70%, warning from 70%, danger from 90%. |
| Disk | Primary below 75%, warning from 75%, danger from 90%. |
| Memory | Secondary. |
| GPU | Primary. |
| Network | Tertiary. |

Variant-based progress bars use the `error` variant from 90%. Temperatures
from 90 °C read `danger`. `Battery.statusColor()` is the shared charge ramp:
charging `success`, at most 15% `danger`, at most 30% `warning`, otherwise
`primary`.

## Coverage ledger

| Path | Applicability and verification |
| --- | --- |
| Wallpaper picker and scheme selector | The dashboard, Island and Deck pass their owning output. The picker offers both Material Vibrant and Noctalia-style Vibrant. |
| Startup, wallpaper changes, and hotplug | One manager owns the persisted wallpaper choices. The two-output Wayland test covers startup, rapid changes, failed extraction, clearing overrides, and output disable and re-enable. |
| Dark/light, static presets, and OLED | The two-output test switches between a static preset and a dynamic scheme, then changes light mode. The shared role type applies OLED overrides. |
| Images, GIFs, and video | Tests cover GIF first-frame extraction and video generation without a thumbnail cache. Live video playback is outside those tests. |
| Shell styling | The two-output test checks themed panel text, panel pixels, and an anchored popup on each output. The shell suite exercises Default, Left, Deck, and Pills layouts and their shared components. |
| Status roles and presets | Unit tests check status hue bands and contrast for both generated schemes in both modes, that bundled and user presets publish the full contract with authored values intact, and that Matugen and Wallust output match the contract. |
| Role map | Source tests check the metric roles, mute-as-inactive in all OSD paths, and Island status icons. Runtime tests check Left workspace inks, hover contrast, and calendar off-month contrast. |
| App exports | The two-output test verifies the global palette in Kitty, GTK, Qt and Niri exports and checks that changing an override leaves all four files untouched. |
| Remote providers, mobile clients, and new config keys | No applicable entry points. Wallpaper choice and extraction are local to the Wayland shell. |

Run the focused checks with:

```bash
python3 -m unittest tests.unit.test_wallpaper_palette tests.e2e.test_display_palettes_runtime -v
```

Run the shell checks with:

```bash
python3 tests/run_tests.py --all
```

The display test uses Quickshell and two private headless Sway outputs. It
checks panel pixels when `grim` is available.

`NoctaliaVibrantTests` checks fixed upstream values for two fixtures. To
compare every token against an upstream build, point `NOCTALIA_PALETTE` at a
binary. The binary must print `<mode>\t<token>\t#rrggbb` lines from
`generateCustom(..., Scheme::Vibrant)`:

```bash
NOCTALIA_PALETTE=/path/to/noctalia-palette python3 -m unittest tests.unit.test_wallpaper_palette -v
```
