#!/usr/bin/env bash
set -euo pipefail

image_path=${1:?wallpaper image is required}
scheme=${2:-scheme-tonal-spot}
mode=${3:-dark}
matugen_config=${4:?matugen config is required}
output_path=${5:?output path is required}

if command -v matugen >/dev/null 2>&1; then
  args=(matugen image "$image_path" --source-color-index 0 -c "$matugen_config" -t "$scheme")
  [[ $mode == light ]] && args+=(-m light)
  exec "${args[@]}"
fi

if ! command -v wallust >/dev/null 2>&1; then
  echo "Neither matugen nor wallust is installed; wallpaper colors were not generated." >&2
  exit 127
fi

palette_name=ansidark16
[[ $mode == light ]] && palette_name=light16

mapfile -t palette < <(
  wallust run --no-config --no-cache --skip-sequences --skip-templates \
    --print-scheme --palette "$palette_name" --colorspace lchansi "$image_path" 2>/dev/null \
    | awk '/^#[[:xdigit:]]{6}$/{print toupper($0)}'
)

if (( ${#palette[@]} < 16 )); then
  echo "Wallust returned an incomplete wallpaper palette." >&2
  exit 1
fi

mkdir -p "$(dirname "$output_path")"
temporary_path=$(mktemp "${output_path}.XXXXXX")
trap 'rm -f "$temporary_path"' EXIT

jq -n \
  --arg background "${palette[0]}" \
  --arg foreground "${palette[15]}" \
  --arg surface "${palette[0]}" \
  --arg surface_bright "${palette[8]}" \
  --arg red "${palette[1]}" --arg light_red "${palette[9]}" \
  --arg green "${palette[2]}" --arg light_green "${palette[10]}" \
  --arg yellow "${palette[3]}" --arg light_yellow "${palette[11]}" \
  --arg blue "${palette[4]}" --arg light_blue "${palette[12]}" \
  --arg magenta "${palette[5]}" --arg light_magenta "${palette[13]}" \
  --arg cyan "${palette[6]}" --arg light_cyan "${palette[14]}" \
  '{
    background: $background,
    overBackground: $foreground,
    shadow: "#000000",
    scrim: "#000000",
    surface: $surface,
    surfaceDim: $surface,
    surfaceBright: $surface_bright,
    surfaceContainer: $surface_bright,
    surfaceContainerHigh: $surface_bright,
    surfaceContainerHighest: $surface_bright,
    surfaceContainerLow: $surface,
    surfaceContainerLowest: $background,
    surfaceVariant: $surface_bright,
    surfaceTint: $blue,
    overSurface: $foreground,
    overSurfaceVariant: $foreground,
    outline: $foreground,
    outlineVariant: $surface_bright,
    primary: $blue,
    primaryContainer: $surface_bright,
    primaryFixed: $light_blue,
    primaryFixedDim: $blue,
    overPrimary: $foreground,
    overPrimaryContainer: $foreground,
    overPrimaryFixed: $background,
    overPrimaryFixedVariant: $background,
    secondary: $magenta,
    secondaryContainer: $surface_bright,
    secondaryFixed: $light_magenta,
    secondaryFixedDim: $magenta,
    overSecondary: $foreground,
    overSecondaryContainer: $foreground,
    overSecondaryFixed: $background,
    overSecondaryFixedVariant: $background,
    tertiary: $cyan,
    tertiaryContainer: $surface_bright,
    tertiaryFixed: $light_cyan,
    tertiaryFixedDim: $cyan,
    overTertiary: $foreground,
    overTertiaryContainer: $foreground,
    overTertiaryFixed: $background,
    overTertiaryFixedVariant: $background,
    inverseSurface: $foreground,
    inverseOnSurface: $background,
    inversePrimary: $light_blue,
    red: $red, lightRed: $light_red, redContainer: $surface_bright, redSource: $red, redValue: $red,
    overRed: $foreground, overRedContainer: $foreground,
    green: $green, lightGreen: $light_green, greenContainer: $surface_bright, greenSource: $green, greenValue: $green,
    overGreen: $foreground, overGreenContainer: $foreground,
    yellow: $yellow, lightYellow: $light_yellow, yellowContainer: $surface_bright, yellowSource: $yellow, yellowValue: $yellow,
    overYellow: $foreground, overYellowContainer: $foreground,
    blue: $blue, lightBlue: $light_blue, blueContainer: $surface_bright, blueSource: $blue, blueValue: $blue,
    overBlue: $foreground, overBlueContainer: $foreground,
    magenta: $magenta, lightMagenta: $light_magenta, magentaContainer: $surface_bright, magentaSource: $magenta, magentaValue: $magenta,
    overMagenta: $foreground, overMagentaContainer: $foreground,
    cyan: $cyan, lightCyan: $light_cyan, cyanContainer: $surface_bright, cyanSource: $cyan, cyanValue: $cyan,
    overCyan: $foreground, overCyanContainer: $foreground,
    white: $foreground, whiteContainer: $surface_bright, whiteSource: $foreground, whiteValue: $foreground,
    overWhite: $background, overWhiteContainer: $foreground,
    error: $light_red, errorContainer: $red, overError: $background, overErrorContainer: $foreground,
    sourceColor: $blue
  }' > "$temporary_path"

mv "$temporary_path" "$output_path"
trap - EXIT
echo "Generated Nonchalant colors with wallust (matugen is unavailable)."
