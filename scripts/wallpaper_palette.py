#!/usr/bin/env python3
"""Extract wallpaper accents and emit the shell's complete color-role contract."""

import argparse
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageOps

RGB = tuple[float, float, float]
Lab = tuple[float, float, float]


def linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def lab(rgb: RGB) -> Lab:
    r, g, b = map(linear, rgb)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def rgb_from_lab(value: Lab) -> RGB:
    lightness, a, b = value
    l = (lightness + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (lightness - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (lightness - 0.0894841775 * a - 1.2914855480 * b) ** 3
    channels = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    return tuple(12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
                 for c in channels)


def tone(source: Lab, lightness: float, chroma_limit: float = 1.0) -> RGB:
    """Change lightness without rotating hue; reduce chroma to fit the sRGB gamut."""
    _, a, b = source
    chroma = math.hypot(a, b)
    scale = min(1.0, chroma_limit / chroma) if chroma else 1.0
    for _ in range(100):
        rgb = rgb_from_lab((lightness, a * scale, b * scale))
        if all(-0.00001 <= c <= 1.00001 for c in rgb):
            return tuple(min(1.0, max(0.0, c)) for c in rgb)
        scale *= 0.95
    return rgb_from_lab((lightness, 0.0, 0.0))


def hex_color(rgb: RGB) -> str:
    return "#" + "".join(f"{round(c * 255):02x}" for c in rgb)


def luminance(rgb: RGB) -> float:
    return sum(c * weight for c, weight in zip(map(linear, rgb), (0.2126, 0.7152, 0.0722)))


def contrast(first: RGB, second: RGB) -> float:
    low, high = sorted((luminance(first), luminance(second)))
    return (high + 0.05) / (low + 0.05)


def hue(value: Lab) -> float:
    return math.degrees(math.atan2(value[2], value[1])) % 360


def hue_distance(first: Lab, second: Lab) -> float:
    distance = abs(hue(first) - hue(second))
    return min(distance, 360 - distance)


def extract(image_path: Path) -> list[Lab]:
    """Population and chroma both matter; large gray areas must not bury accents."""
    with Image.open(image_path) as original:
        image = ImageOps.exif_transpose(original).convert("RGBA")
        image.thumbnail((256, 256), Image.Resampling.LANCZOS)
        # Ignore transparent pixels rather than treating their hidden RGB as wallpaper.
        pixels = [image.getpixel((x, y))[:3]
                  for y in range(image.height) for x in range(image.width)
                  if image.getpixel((x, y))[3] >= 128]
    if not pixels:
        raise ValueError("Wallpaper has no visible pixels")
    sample = Image.new("RGB", (len(pixels), 1))
    sample.putdata(pixels)
    quantized = sample.quantize(colors=64, method=Image.Quantize.MEDIANCUT)
    palette = quantized.getpalette()
    counts = quantized.getcolors()
    candidates = [(count, lab(tuple(c / 255 for c in palette[index * 3:index * 3 + 3])))
                  for count, index in counts]
    colorful = [(count, value) for count, value in candidates
                if count / len(pixels) >= 0.002 and math.hypot(*value[1:]) >= 0.035
                and 0.15 < value[0] < 0.95]
    if not colorful:
        return [max(candidates, key=lambda entry: entry[0])[1]]
    score = lambda entry: math.sqrt(entry[0] / len(pixels)) * math.hypot(*entry[1][1:])
    colorful.sort(key=score, reverse=True)
    selected = [colorful.pop(0)[1]]
    while colorful and len(selected) < 6:
        # Pick another hue, not another shade of the dominant color.
        distinct = [entry for entry in colorful
                    if min(hue_distance(entry[1], value) for value in selected) >= 30]
        if not distinct:
            break
        chosen = max(distinct, key=lambda entry: score(entry) *
                     min(hue_distance(entry[1], value) for value in selected) / 180)
        selected.append(chosen[1])
        colorful.remove(chosen)
    # Fill remaining slots with distinct image chroma, including nearby warm/cool
    # shades. These are sampled colors, not manufactured complementary hues.
    while colorful and len(selected) < 6:
        distance = lambda value: min(math.hypot(value[1] - old[1], value[2] - old[2])
                                     for old in selected)
        distinct = [entry for entry in colorful if distance(entry[1]) >= 0.035]
        if not distinct:
            break
        chosen = max(distinct, key=lambda entry: score(entry) * distance(entry[1]))
        selected.append(chosen[1])
        colorful.remove(chosen)
    return selected


def build_palette(sources: list[Lab], mode: str) -> dict[str, str]:
    dark = mode == "dark"
    neutral = sources[0]
    result: dict[str, str] = {}
    surfaces = {
        "surfaceDim": (0.19, 0.87), "surfaceContainerLowest": (0.16, 0.99),
        "surfaceContainerLow": (0.23, 0.96), "background": (0.25, 0.95),
        "surface": (0.28, 0.93), "surfaceContainer": (0.28, 0.93),
        "surfaceContainerHigh": (0.32, 0.90), "surfaceContainerHighest": (0.36, 0.87),
        "surfaceBright": (0.40, 0.85), "surfaceVariant": (0.36, 0.87),
        "outline": (0.64, 0.48), "outlineVariant": (0.43, 0.76),
        "overBackground": (0.94, 0.20), "overSurface": (0.94, 0.20),
        "overSurfaceVariant": (0.80, 0.36), "inverseSurface": (0.94, 0.25),
        "inverseOnSurface": (0.25, 0.94),
    }
    for name, levels in surfaces.items():
        result[name] = hex_color(tone(neutral, levels[0 if dark else 1], 0.015))
    result.update(shadow="#000000", scrim="#000000", sourceColor=hex_color(tone(neutral, neutral[0])))
    background = tone(neutral, 0.40 if dark else 0.85, 0.015)

    def foreground(rgb: RGB) -> str:
        choices = [tone(neutral, 0.12, 0.01), tone(neutral, 0.98, 0.01)]
        return hex_color(max(choices, key=lambda value: contrast(rgb, value)))

    def add_role(name: str, source: Lab) -> None:
        lightness = min(0.82, max(0.70, source[0])) if dark else min(0.48, source[0])
        accent = tone(source, lightness)
        # Accents are also used as small text on the brightest shell container.
        # Leave room for 8-bit hex rounding at the publication boundary.
        while contrast(accent, background) < 4.6 and 0.20 < lightness < 0.95:
            lightness += 0.01 if dark else -0.01
            accent = tone(source, lightness)
        container = tone(source, 0.32 if dark else 0.90, 0.10)
        title = name[0].upper() + name[1:]
        result[name] = hex_color(accent)
        result[name + "Container"] = hex_color(container)
        result["over" + title] = foreground(accent)
        result["over" + title + "Container"] = foreground(container)
        if name in ("primary", "secondary", "tertiary"):
            fixed = tone(source, 0.90)
            dim = tone(source, 0.80)
            result[name + "Fixed"] = hex_color(fixed)
            result[name + "FixedDim"] = hex_color(dim)
            result["over" + title + "Fixed"] = foreground(dim)
            result["over" + title + "FixedVariant"] = foreground(dim)
        else:
            result["light" + title] = hex_color(tone(source, min(0.95, lightness + 0.08)))
            result[name + "Source"] = hex_color(tone(source, source[0]))
            result[name + "Value"] = result[name + "Source"]

    for index, name in enumerate(("primary", "secondary", "tertiary")):
        add_role(name, sources[index % len(sources)])
    # Legacy role names are slots in the image palette, not fixed hue families.
    # Every slot must change with its sampled wallpaper color.
    for index, name in enumerate(("red", "green", "yellow", "blue", "magenta", "cyan")):
        add_role(name, sources[index % len(sources)])
    add_role("white", (0.92, neutral[1] * 0.08, neutral[2] * 0.08))
    result.pop("lightWhite")
    for suffix in ("", "Container"):
        result["error" + suffix] = result["red" + suffix]
        result["overError" + suffix] = result["overRed" + suffix]
    result["surfaceTint"] = result["primary"]
    result["inversePrimary"] = hex_color(tone(sources[0], 0.45 if dark else 0.80))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("mode", choices=("dark", "light"))
    args = parser.parse_args()
    try:
        print(json.dumps(build_palette(extract(args.image), args.mode), indent=2))
        return 0
    except (OSError, ValueError) as error:
        print(json.dumps({"error": str(error)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
