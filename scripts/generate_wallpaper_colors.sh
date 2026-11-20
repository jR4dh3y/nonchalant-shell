#!/usr/bin/env bash
set -euo pipefail

image_path=${1:?wallpaper image is required}
scheme=${2:-scheme-tonal-spot}
mode=${3:-dark}
matugen_config=${4:?matugen config is required}
output_path=${5:?output path is required}

if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' '{"error":"python3 is required for wallpaper colors"}' >&2
  exit 127
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ $output_path == - ]]; then
  staging_dir=$(mktemp -d)
else
  mkdir -p -- "$(dirname -- "$output_path")"
  staging_dir=$(mktemp -d "${output_path}.XXXXXX")
fi
trap 'rm -rf -- "$staging_dir"' EXIT
temporary_path="$staging_dir/colors.json"

case ${image_path,,} in
  *.mp4|*.webm|*.mov|*.avi|*.mkv)
    if ! command -v ffmpeg >/dev/null 2>&1; then
      printf '%s\n' '{"error":"FFmpeg is required for video wallpaper colors"}' >&2
      exit 127
    fi
    frame_path="$staging_dir/frame.png"
    if ! ffmpeg -nostdin -v quiet -i "$image_path" -frames:v 1 -threads 1 "$frame_path"; then
      printf '%s\n' '{"error":"FFmpeg could not decode a wallpaper frame"}' >&2
      exit 1
    fi
    image_path=$frame_path
    ;;
esac

validate_palette() {
  python3 - "$temporary_path" "$script_dir/../assets/matugen/colors.json" <<'PY'
import json
from pathlib import Path
import re
import sys

try:
    palette = json.loads(Path(sys.argv[1]).read_text())
    expected = json.loads(Path(sys.argv[2]).read_text())
    if not isinstance(palette, dict) or set(palette) != set(expected):
        raise ValueError("Incomplete wallpaper palette")
    if not all(isinstance(value, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", value)
               for value in palette.values()):
        raise ValueError("Invalid wallpaper palette color")
except (OSError, ValueError) as error:
    print(json.dumps({"error": str(error)}), file=sys.stderr)
    sys.exit(1)
PY
}

publish_palette() {
  if [[ $output_path == - ]]; then
    cat -- "$temporary_path"
  else
    mv -- "$temporary_path" "$output_path"
  fi
}

set_surface_roles() {
  local normalized="$staging_dir/normalized.json"
  local surface_args=()
  if [[ $scheme == scheme-monochrome ]]; then
    surface_args+=(--monochrome)
  fi
  python3 "$script_dir/wallpaper_palette.py" "$image_path" "$mode" \
    --surfaces-for "$temporary_path" "${surface_args[@]}" > "$normalized" &&
    mv -- "$normalized" "$temporary_path"
}

if [[ $scheme == scheme-wallpaper || $scheme == scheme-noctalia-vibrant ]]; then
  if ! python3 -c 'from PIL import Image' >/dev/null 2>&1; then
    printf '%s\n' '{"error":"Pillow is required for wallpaper colors"}' >&2
    exit 127
  fi
  extractor_args=("$image_path" "$mode")
  [[ $scheme == scheme-noctalia-vibrant ]] && extractor_args+=(--vibrant)
  python3 "$script_dir/wallpaper_palette.py" "${extractor_args[@]}" > "$temporary_path"
  validate_palette
  publish_palette
  exit 0
fi

# Matugen cannot decode AVIF. Check the contents because wallpaper filenames
# sometimes have a WebP or JPEG extension even when they contain AVIF.
image_path=$(python3 - "$image_path" "$staging_dir/avif.png" <<'PY'
import sys

source, normalized = sys.argv[1:]
try:
    from PIL import Image, ImageOps

    with Image.open(source) as image:
        if image.format == "AVIF":
            ImageOps.exif_transpose(image).save(normalized)
            source = normalized
except (ImportError, OSError):
    pass
print(source)
PY
)

# Matugen options vary by release.
matugen_supports() {
  matugen image --help 2>/dev/null | grep -qw -- "$1"
}

if command -v matugen >/dev/null 2>&1; then
  prefer=${MATUGEN_PREFER:-}
  contrast_args=()
  case $scheme in
    scheme-content-dominant|scheme-expressive-dominant)
      scheme=${scheme%-dominant}
      prefer=
      ;;
    scheme-content|scheme-expressive)
      prefer=${prefer:-saturation}
      ;;
    scheme-tonal-spot-contrast)
      scheme=scheme-tonal-spot
      contrast_args=(--contrast 0.5)
      ;;
    scheme-smart)
      if ! matugen_supports scheme-smart; then
        echo "Matugen lacks Smart; using Tonal Spot" >&2
        scheme=scheme-tonal-spot
      fi
      ;;
  esac
  # Give each invocation its own output; an old shared cache is never success.
  python3 - "$matugen_config" "$staging_dir/config.toml" "$temporary_path" <<'PY'
import json
from pathlib import Path
import re
import sys

config = Path(sys.argv[1]).resolve()
text = config.read_text()
text = re.sub(r'(?m)^input_path[ \t]*=[ \t]*"([^"]*)"[ \t]*$',
              lambda match: "input_path = " + json.dumps(str(config.parent / match[1])), text)
text = re.sub(r'(?m)^output_path\s*=.*$',
              lambda match: "output_path = " + json.dumps(str(Path(sys.argv[3]).resolve())), text)
Path(sys.argv[2]).write_text(text)
PY
  args=(
    matugen image "$image_path"
    -c "$staging_dir/config.toml"
    -t "$scheme"
    -m "$mode"
    "${contrast_args[@]}"
  )
  if [[ -n $prefer ]] && matugen_supports --prefer; then
    args+=(--prefer "$prefer")
  elif matugen_supports --source-color-index; then
    args+=(--source-color-index 0)
  fi
  if "${args[@]}" >&2 && validate_palette && set_surface_roles && validate_palette; then
    publish_palette
    exit 0
  fi
  echo "matugen failed; trying wallust fallback..." >&2
fi

if ! command -v wallust >/dev/null 2>&1; then
  printf '%s\n' '{"error":"Neither matugen nor wallust is installed"}' >&2
  exit 127
fi
if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"error":"jq is required for the wallust fallback"}' >&2
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
  printf '%s\n' '{"error":"Wallust returned an incomplete wallpaper palette"}' >&2
  exit 1
fi

# Fill the legacy contract before applying the shared neutral surface roles.
jq -n \
  --arg background "${palette[0]}" \
  --arg foreground "${palette[15]}" \
  --arg surface "${palette[8]}" \
  --arg surface_bright "${palette[8]}" \
  --arg red "${palette[1]}" --arg light_red "${palette[9]}" \
  --arg green "${palette[2]}" --arg light_green "${palette[10]}" \
  --arg yellow "${palette[3]}" --arg light_yellow "${palette[11]}" \
  --arg blue "${palette[4]}" --arg light_blue "${palette[12]}" \
  --arg magenta "${palette[5]}" --arg light_magenta "${palette[13]}" \
  --arg cyan "${palette[6]}" --arg light_cyan "${palette[14]}" \
  '{
    background: $surface,
    overBackground: $foreground,
    shadow: "#000000",
    scrim: "#000000",
    surface: $surface,
    surfaceDim: $background,
    surfaceBright: $surface_bright,
    surfaceContainer: $surface,
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
    overPrimary: $background,
    overPrimaryContainer: $foreground,
    overPrimaryFixed: $background,
    overPrimaryFixedVariant: $background,
    secondary: $magenta,
    secondaryContainer: $surface_bright,
    secondaryFixed: $light_magenta,
    secondaryFixedDim: $magenta,
    overSecondary: $background,
    overSecondaryContainer: $foreground,
    overSecondaryFixed: $background,
    overSecondaryFixedVariant: $background,
    tertiary: $cyan,
    tertiaryContainer: $surface_bright,
    tertiaryFixed: $light_cyan,
    tertiaryFixedDim: $cyan,
    overTertiary: $background,
    overTertiaryContainer: $foreground,
    overTertiaryFixed: $background,
    overTertiaryFixedVariant: $background,
    inverseSurface: $foreground,
    inverseOnSurface: $background,
    inversePrimary: $light_blue,
    red: $red, lightRed: $light_red, redContainer: $surface_bright, redSource: $red, redValue: $red,
    overRed: $background, overRedContainer: $foreground,
    green: $green, lightGreen: $light_green, greenContainer: $surface_bright, greenSource: $green, greenValue: $green,
    overGreen: $background, overGreenContainer: $foreground,
    yellow: $yellow, lightYellow: $light_yellow, yellowContainer: $surface_bright, yellowSource: $yellow, yellowValue: $yellow,
    overYellow: $background, overYellowContainer: $foreground,
    blue: $blue, lightBlue: $light_blue, blueContainer: $surface_bright, blueSource: $blue, blueValue: $blue,
    overBlue: $background, overBlueContainer: $foreground,
    magenta: $magenta, lightMagenta: $light_magenta, magentaContainer: $surface_bright, magentaSource: $magenta, magentaValue: $magenta,
    overMagenta: $background, overMagentaContainer: $foreground,
    cyan: $cyan, lightCyan: $light_cyan, cyanContainer: $surface_bright, cyanSource: $cyan, cyanValue: $cyan,
    overCyan: $background, overCyanContainer: $foreground,
    white: $foreground, whiteContainer: $surface_bright, whiteSource: $foreground, whiteValue: $foreground,
    overWhite: $background, overWhiteContainer: $foreground,
    error: $light_red, errorContainer: $red, overError: $background, overErrorContainer: $foreground,
    danger: $light_red, overDanger: $background,
    warning: $light_yellow, overWarning: $background, success: $light_green, overSuccess: $background,
    sourceColor: $blue
  }' > "$temporary_path"

set_surface_roles
validate_palette
publish_palette
