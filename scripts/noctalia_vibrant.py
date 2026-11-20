#!/usr/bin/env python3
"""Noctalia v5 Vibrant wallpaper scheme, mapped onto Nonchalant's color contract.

This is a Python port of the Vibrant pipeline in Noctalia v5.5.0
(noctalia-dev/noctalia@c2573248a89470383e41b8e1ac432424691cbc1f):

- src/theme/image_loader.cpp     112x112 box resize
- src/theme/custom_schemes.cpp   Lab k-means, Vibrant scoring, HSL token maps
- src/theme/color.cpp            HSL helpers
- src/theme/contrast.cpp         WCAG contrast and OKLCH ensureContrast
- src/theme/fixed_palette.cpp    palette-style terminal (ANSI) colors

    MIT License

    Copyright (c) 2026 noctalia-dev

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

The CAM16/HCT code is translated from material-color-utilities as vendored by
Noctalia (third_party/material_color_utilities/cpp/cam and utils). Copyright 2022
Google LLC, licensed under the Apache License, Version 2.0. See
material-color-utilities.LICENSE. Changes: translated to Python and
reduced to the functions this scheme calls.

Intentional differences from upstream are listed in docs/wallpaper-colors.md.
"""

from array import array
import math
from operator import add
from pathlib import Path

from PIL import Image, ImageOps

Color = tuple[int, int, int]


def round_half_away(value: float) -> int:
    """C/C++ round()/lround(); Python's round() rounds halves to even."""
    return math.floor(value + 0.5) if value >= 0 else -math.floor(-value + 0.5)


def clamp(value, low, high):
    return max(low, min(value, high))


# ── HSL (color.cpp) ──────────────────────────────────────────────────────────

def to_hsl(color: Color) -> tuple[float, float, float]:
    rn, gn, bn = (channel / 255.0 for channel in color)
    max_c, min_c = max(rn, gn, bn), min(rn, gn, bn)
    delta = max_c - min_c
    lightness = (max_c + min_c) / 2.0
    hue = saturation = 0.0
    if delta != 0.0:
        if lightness not in (0.0, 1.0):
            saturation = delta / (1.0 - abs(2.0 * lightness - 1.0))
        if max_c == rn:
            turn = math.fmod((gn - bn) / delta, 6.0)
            hue = 60.0 * (turn + 6.0 if turn < 0.0 else turn)
        elif max_c == gn:
            hue = 60.0 * ((bn - rn) / delta + 2.0)
        else:
            hue = 60.0 * ((rn - gn) / delta + 4.0)
    return hue, saturation, lightness


def from_hsl(hue: float, saturation: float, lightness: float) -> Color:
    def byte(value: float) -> int:
        return clamp(round_half_away(value * 255.0), 0, 255)

    if saturation == 0.0:
        return (byte(lightness),) * 3
    q = lightness * (1.0 + saturation) if lightness < 0.5 else lightness + saturation - lightness * saturation
    p = 2.0 * lightness - q
    turn = hue / 360.0

    def channel(t: float) -> float:
        if t < 0.0:
            t += 1.0
        if t > 1.0:
            t -= 1.0
        if t < 1.0 / 6.0:
            return p + (q - p) * 6.0 * t
        if t < 1.0 / 2.0:
            return q
        if t < 2.0 / 3.0:
            return p + (q - p) * (2.0 / 3.0 - t) * 6.0
        return p

    return byte(channel(turn + 1.0 / 3.0)), byte(channel(turn)), byte(channel(turn - 1.0 / 3.0))


def hue_distance(first: float, second: float) -> float:
    diff = abs(first - second)
    return min(diff, 360.0 - diff)


def shift_hue(color: Color, degrees: float) -> Color:
    hue, saturation, lightness = to_hsl(color)
    hue = math.fmod(hue + degrees, 360.0)
    return from_hsl(hue + 360.0 if hue < 0.0 else hue, saturation, lightness)


def adjust_surface(base: Color, max_saturation: float, lightness: float) -> Color:
    hue, saturation, _ = to_hsl(base)
    return from_hsl(hue, min(saturation, max_saturation), lightness)


# ── Contrast (contrast.cpp) ─────────────────────────────────────────────────

def linearize_channel(channel: int) -> float:
    normalized = channel / 255.0
    return normalized / 12.92 if normalized <= 0.04045 else ((normalized + 0.055) / 1.055) ** 2.4


def relative_luminance(color: Color) -> float:
    r, g, b = map(linearize_channel, color)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(first: Color, second: Color) -> float:
    darker, lighter = sorted((relative_luminance(first), relative_luminance(second)))
    return (lighter + 0.05) / (darker + 0.05)


def is_dark(color: Color) -> bool:
    return relative_luminance(color) < 0.179


def to_oklch(color: Color) -> tuple[float, float, float]:
    r, g, b = map(linearize_channel, color)
    l = math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    b_axis = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return lightness, math.hypot(a, b_axis), math.atan2(b_axis, a)


def from_oklch(lightness: float, chroma: float, hue: float) -> tuple[float, float, float]:
    a, b = chroma * math.cos(hue), chroma * math.sin(hue)
    l_root = lightness + 0.3963377774 * a + 0.2158037573 * b
    m_root = lightness - 0.1055613458 * a - 0.0638541728 * b
    s_root = lightness - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_root * l_root * l_root, m_root * m_root * m_root, s_root * s_root * s_root
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def in_srgb_gamut(linear: tuple[float, float, float]) -> bool:
    return all(-1e-7 <= channel <= 1.0 + 1e-7 for channel in linear)


def srgb_from_linear(linear: tuple[float, float, float]) -> Color:
    def byte(channel: float) -> int:
        srgb = channel * 12.92 if channel <= 0.0031308 else 1.055 * channel ** (1.0 / 2.4) - 0.055
        return round_half_away(clamp(srgb, 0.0, 1.0) * 255.0)

    return tuple(map(byte, linear))


def gamut_map(lightness: float, chroma: float, hue: float) -> Color:
    linear = from_oklch(lightness, chroma, hue)
    if in_srgb_gamut(linear):
        return srgb_from_linear(linear)
    low, high = 0.0, chroma
    best = from_oklch(lightness, 0.0, hue)
    for _ in range(20):
        candidate_chroma = (low + high) / 2.0
        candidate = from_oklch(lightness, candidate_chroma, hue)
        if in_srgb_gamut(candidate):
            low, best = candidate_chroma, candidate
        else:
            high = candidate_chroma
    return srgb_from_linear(best)


def ensure_contrast(foreground: Color, background: Color, min_ratio: float = 4.5,
                    prefer_light: int = 0) -> Color:
    """Move foreground lightness along its OKLCH hue until it reaches min_ratio."""
    if contrast_ratio(foreground, background) >= min_ratio:
        return foreground
    lightness, chroma, hue = to_oklch(foreground)
    lighten = prefer_light > 0 if prefer_light else is_dark(background)
    preferred = gamut_map(1.0 if lighten else 0.0, chroma, hue)
    preferred_ratio = contrast_ratio(preferred, background)
    if preferred_ratio < min_ratio:
        opposite = gamut_map(0.0 if lighten else 1.0, chroma, hue)
        return opposite if contrast_ratio(opposite, background) > preferred_ratio else preferred
    low, high = (lightness, 1.0) if lighten else (0.0, lightness)
    best = preferred
    for _ in range(20):
        middle = (low + high) / 2.0
        test = gamut_map(middle, chroma, hue)
        if contrast_ratio(test, background) >= min_ratio:
            best = test
            if lighten:
                high = middle
            else:
                low = middle
        elif lighten:
            low = middle
        else:
            high = middle
    return best


# ── CAM16 and HCT (material-color-utilities) ────────────────────────────────

# kDefaultViewingConditions: sRGB, 50% gray background, average surround.
VC_AW, VC_NBB, VC_C, VC_NC, VC_FL_ROOT, VC_Z = 29.981000900, 1.016919255, 0.689999998, 1.0, 0.789482653, 1.909169555
VC_FL, VC_N = 0.388481468, 0.184186503
VC_RGB_D = (1.021177769, 0.986307740, 0.933960497)
VC_NCB = VC_NBB
T_INNER = 1.0 / (1.64 - 0.29 ** VC_N) ** 0.73
SCALED_DISCOUNT_FROM_LINRGB = ((0.001200833568784504, 0.002389694492170889, 0.0002795742885861124),
                               (0.0005891086651375999, 0.0029785502573438758, 0.0003270666104008398),
                               (0.00010146692491640572, 0.0005364214359186694, 0.0032979401770712076))
LINRGB_FROM_SCALED_DISCOUNT = ((1373.2198709594231, -1100.4251190754821, -7.278681089101213),
                               (-271.815969077903, 559.6580465940733, -32.46047482791194),
                               (1.9622899599665666, -57.173814538844006, 308.7233197812385))
Y_FROM_LINRGB = (0.2126, 0.7152, 0.0722)


def mcu_linearized(component: int) -> float:
    normalized = component / 255.0
    return normalized / 12.92 * 100.0 if normalized <= 0.040449936 else ((normalized + 0.055) / 1.055) ** 2.4 * 100.0


def mcu_delinearized(component: float) -> int:
    normalized = component / 100.0
    value = normalized * 12.92 if normalized <= 0.0031308 else 1.055 * normalized ** (1.0 / 2.4) - 0.055
    return clamp(round_half_away(value * 255.0), 0, 255)


# kCriticalPlanes in hct_solver.cc are exactly the linearized midpoints of 8-bit codes.
CRITICAL_PLANES = tuple(mcu_linearized(index + 0.5) for index in range(255))


def sanitize_degrees(degrees: float) -> float:
    if degrees < 0.0:
        return math.fmod(degrees, 360.0) + 360.0
    return math.fmod(degrees, 360.0) if degrees >= 360.0 else degrees


def signum(value: float) -> int:
    return -1 if value < 0 else (0 if value == 0 else 1)


def y_from_lstar(lstar: float) -> float:
    if lstar > 8.0:
        cube_root = (lstar + 16.0) / 116.0
        return cube_root * cube_root * cube_root * 100.0
    return lstar / (24389.0 / 27.0) * 100.0


def lstar_from_y(y: float) -> float:
    normalized = y / 100.0
    if normalized <= 216.0 / 24389.0:
        return (24389.0 / 27.0) * normalized
    return 116.0 * normalized ** (1.0 / 3.0) - 16.0


def cam16(color: Color) -> tuple[float, float, float, float, float]:
    """Return CAM16 hue, chroma, J*, a*, b* (CamFromInt)."""
    red, green, blue = map(mcu_linearized, color)
    x = 0.41233895 * red + 0.35762064 * green + 0.18051042 * blue
    y = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    z = 0.01932141 * red + 0.11916382 * green + 0.95034478 * blue
    cones = (0.401288 * x + 0.650173 * y - 0.051461 * z,
             -0.250268 * x + 1.204414 * y + 0.045854 * z,
             -0.002079 * x + 0.048952 * y + 0.953127 * z)
    adapted = []
    for cone, discount in zip(cones, VC_RGB_D):
        discounted = discount * cone
        factor = (VC_FL * abs(discounted) / 100.0) ** 0.42
        adapted.append(signum(discounted) * 400.0 * factor / (factor + 27.13))
    r_a, g_a, b_a = adapted
    a = (11.0 * r_a + -12.0 * g_a + b_a) / 11.0
    b = (r_a + g_a - 2.0 * b_a) / 9.0
    u = (20.0 * r_a + 20.0 * g_a + 21.0 * b_a) / 20.0
    p2 = (40.0 * r_a + 20.0 * g_a + b_a) / 20.0
    hue = sanitize_degrees(math.atan2(b, a) * 180.0 / math.pi)
    hue_radians = hue * math.pi / 180.0
    j = 100.0 * (p2 * VC_NBB / VC_AW) ** (VC_C * VC_Z)
    hue_prime = hue + 360 if hue < 20.14 else hue
    e_hue = 0.25 * (math.cos(hue_prime * math.pi / 180.0 + 2.0) + 3.8)
    p1 = 50000.0 / 13.0 * e_hue * VC_NC * VC_NCB
    t = p1 * math.sqrt(a * a + b * b) / (u + 0.305)
    alpha = t ** 0.9 * (1.64 - 0.29 ** VC_N) ** 0.73
    chroma = alpha * math.sqrt(j / 100.0)
    m = chroma * VC_FL_ROOT
    jstar = (1.0 + 100.0 * 0.007) * j / (1.0 + 0.007 * j)
    mstar = 1.0 / 0.0228 * math.log(1.0 + 0.0228 * m)
    return hue, chroma, jstar, mstar * math.cos(hue_radians), mstar * math.sin(hue_radians)


def matrix_multiply(vector, matrix):
    return tuple(vector[0] * row[0] + vector[1] * row[1] + vector[2] * row[2] for row in matrix)


def argb_from_linrgb(linrgb) -> Color:
    return tuple(mcu_delinearized(channel) for channel in linrgb)


def gray_from_lstar(lstar: float) -> Color:
    return (mcu_delinearized(y_from_lstar(lstar)),) * 3


def chromatic_adaptation(component: float) -> float:
    factor = abs(component) ** 0.42
    return signum(component) * 400.0 * factor / (factor + 27.13)


def hue_of(linrgb) -> float:
    r_a, g_a, b_a = map(chromatic_adaptation, matrix_multiply(linrgb, SCALED_DISCOUNT_FROM_LINRGB))
    return math.atan2((r_a + g_a - 2.0 * b_a) / 9.0, (11.0 * r_a + -12.0 * g_a + b_a) / 11.0)


def sanitize_radians(angle: float) -> float:
    return math.fmod(angle + math.pi * 8, math.pi * 2)


def in_cyclic_order(a: float, b: float, c: float) -> bool:
    return sanitize_radians(b - a) < sanitize_radians(c - a)


def nth_vertex(y: float, n: int):
    k_r, k_g, k_b = Y_FROM_LINRGB
    coord_a = 0.0 if n % 4 <= 1 else 100.0
    coord_b = 0.0 if n % 2 == 0 else 100.0
    if n < 4:
        g, b = coord_a, coord_b
        r = (y - g * k_g - b * k_b) / k_r
        return (r, g, b) if 0.0 <= r <= 100.0 else None
    if n < 8:
        b, r = coord_a, coord_b
        g = (y - r * k_r - b * k_b) / k_g
        return (r, g, b) if 0.0 <= g <= 100.0 else None
    r, g = coord_a, coord_b
    b = (y - r * k_r - g * k_g) / k_b
    return (r, g, b) if 0.0 <= b <= 100.0 else None


def bisect_to_segment(y: float, target_hue: float):
    left = right = (-1.0, -1.0, -1.0)
    left_hue = right_hue = 0.0
    initialized, uncut = False, True
    for n in range(12):
        middle = nth_vertex(y, n)
        if middle is None:
            continue
        middle_hue = hue_of(middle)
        if not initialized:
            left = right = middle
            left_hue = right_hue = middle_hue
            initialized = True
            continue
        if uncut or in_cyclic_order(left_hue, middle_hue, right_hue):
            uncut = False
            if in_cyclic_order(left_hue, target_hue, middle_hue):
                right, right_hue = middle, middle_hue
            else:
                left, left_hue = middle, middle_hue
    return left, right


def true_delinearized(component: float) -> float:
    normalized = component / 100.0
    value = normalized * 12.92 if normalized <= 0.0031308 else 1.055 * normalized ** (1.0 / 2.4) - 0.055
    return value * 255.0


def bisect_to_limit(y: float, target_hue: float):
    left, right = bisect_to_segment(y, target_hue)
    left_hue = hue_of(left)
    for axis in range(3):
        if left[axis] == right[axis]:
            continue
        if left[axis] < right[axis]:
            l_plane = math.floor(true_delinearized(left[axis]) - 0.5)
            r_plane = math.ceil(true_delinearized(right[axis]) - 0.5)
        else:
            l_plane = math.ceil(true_delinearized(left[axis]) - 0.5)
            r_plane = math.floor(true_delinearized(right[axis]) - 0.5)
        for _ in range(8):
            if abs(r_plane - l_plane) <= 1:
                break
            m_plane = math.floor((l_plane + r_plane) / 2.0)
            coordinate = CRITICAL_PLANES[m_plane]
            t = (coordinate - left[axis]) / (right[axis] - left[axis])
            middle = tuple(source + (target - source) * t for source, target in zip(left, right))
            middle_hue = hue_of(middle)
            if in_cyclic_order(left_hue, target_hue, middle_hue):
                right, r_plane = middle, m_plane
            else:
                left, left_hue, l_plane = middle, middle_hue, m_plane
    return tuple((a + b) / 2 for a, b in zip(left, right))


def inverse_chromatic_adaptation(adapted: float) -> float:
    adapted_abs = abs(adapted)
    base = max(0, 27.13 * adapted_abs / (400.0 - adapted_abs))
    return signum(adapted) * base ** (1.0 / 0.42)


def find_result_by_j(hue_radians: float, chroma: float, y: float) -> Color | None:
    j = math.sqrt(y) * 11.0
    e_hue = 0.25 * (math.cos(hue_radians + 2.0) + 3.8)
    p1 = e_hue * (50000.0 / 13.0) * VC_NC * VC_NCB
    h_sin, h_cos = math.sin(hue_radians), math.cos(hue_radians)
    for iteration in range(5):
        j_normalized = j / 100.0
        alpha = 0.0 if chroma == 0.0 or j == 0.0 else chroma / math.sqrt(j_normalized)
        t = (alpha * T_INNER) ** (1.0 / 0.9)
        p2 = VC_AW * j_normalized ** (1.0 / VC_C / VC_Z) / VC_NBB
        gamma = 23.0 * (p2 + 0.305) * t / (23.0 * p1 + 11 * t * h_cos + 108.0 * t * h_sin)
        a, b = gamma * h_cos, gamma * h_sin
        scaled = (inverse_chromatic_adaptation((460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0),
                  inverse_chromatic_adaptation((460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0),
                  inverse_chromatic_adaptation((460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0))
        linrgb = matrix_multiply(scaled, LINRGB_FROM_SCALED_DISCOUNT)
        if min(linrgb) < 0:
            return None
        fnj = sum(k * channel for k, channel in zip(Y_FROM_LINRGB, linrgb))
        if fnj <= 0:
            return None
        if iteration == 4 or abs(fnj - y) < 0.002:
            return None if max(linrgb) > 100.01 else argb_from_linrgb(linrgb)
        j = j - (fnj - y) * j / (2 * fnj)
    return None


def solve_hct(hue: float, chroma: float, lstar: float) -> Color:
    if chroma < 0.0001 or lstar < 0.0001 or lstar > 99.9999:
        return gray_from_lstar(lstar)
    hue_radians = sanitize_degrees(hue) / 180 * math.pi
    y = y_from_lstar(lstar)
    return find_result_by_j(hue_radians, chroma, y) or argb_from_linrgb(bisect_to_limit(y, hue_radians))


class Hct:
    """Hue, chroma, tone of an sRGB color, as the MCU Hct class stores them."""

    def __init__(self, color: Color):
        self.color = color
        self.hue, self.chroma, *_ = cam16(color)
        red, green, blue = map(mcu_linearized, color)
        self.tone = lstar_from_y(0.2126 * red + 0.7152 * green + 0.0722 * blue)

    @classmethod
    def of(cls, hue: float, chroma: float, tone: float) -> "Hct":
        return cls(solve_hct(hue, chroma, tone))

    def ucs(self) -> tuple[float, float, float]:
        return cam16(self.color)[2:]


# ── Image sampling (image_loader.cpp) ───────────────────────────────────────

TARGET = 112
DOWNSAMPLE_STEP = 16  # downsamplePixels(rgb112, factor 4) keeps every 16th pixel.


def f32(value: float) -> float:
    return array("f", (value,))[0]


def box_windows(source: int, target: int) -> list[tuple[int, int]]:
    """The input range each output pixel averages (box sampler window)."""
    factor = target / source
    scale = max(1.0 / factor + 1.0e-12, 1.0)
    support = max(scale * 0.5, 0.5)
    windows = []
    for output in range(target):
        bisect = (output + 0.5) / factor + 1.0e-12
        windows.append((int(max(bisect - support + 0.5, 0.0)), int(min(bisect + support + 0.5, float(source)))))
    return windows


def load_samples(image_path: Path) -> list[Color]:
    """Return the downsampled pixels of Noctalia's 112x112 box-resized buffer.

    Only the cells downsamplePixels keeps are computed, with the upstream
    single-precision accumulation order (vertical pass, then horizontal).
    """
    with Image.open(image_path) as original:
        image = ImageOps.exif_transpose(original)
        if image.mode in ("RGBA", "LA", "PA") or "transparency" in image.info:
            rgba = image.convert("RGBA")
            lowest_alpha, highest_alpha = rgba.getchannel("A").getextrema()
            if highest_alpha == 0:
                raise ValueError("Wallpaper has no visible pixels")
            image = rgba.convert("RGB")
            if lowest_alpha < 255:
                # Upstream averages straight RGB, so transparent pixels would
                # contribute their hidden color. Show them over black instead.
                image = Image.new("RGB", rgba.size)
                image.paste(rgba, mask=rgba.getchannel("A"))
        else:
            image = image.convert("RGB")
        width, height = image.size
        data = image.tobytes()

    rows = box_windows(height, TARGET)
    columns = box_windows(width, TARGET)
    sampled_columns = range(0, TARGET, DOWNSAMPLE_STEP)
    cells: dict[tuple[int, int], Color] = {}
    for output_x in sampled_columns:
        x0, x1 = columns[output_x]
        column_weight = f32(1.0 / (x1 - x0))
        for output_y in range(TARGET):
            y0, y1 = rows[output_y]
            row_weight = f32(1.0 / (y1 - y0))
            products = array("f", (value * row_weight for value in range(256)))
            vertical = array("f", bytes(4 * 3 * (x1 - x0)))
            for y in range(y0, y1):
                start = (y * width + x0) * 3
                vertical = array("f", map(add, vertical, map(products.__getitem__, data[start:start + 3 * (x1 - x0)])))
            pixel = []
            for channel in range(3):
                total = 0.0
                for value in vertical[channel::3]:
                    total = f32(total + f32(value * column_weight))
                pixel.append(math.floor(f32(clamp(total, 0.0, 255.0) + 0.5)))
            cells[output_x, output_y] = tuple(pixel)
    # Row-major order, as the upstream buffer is walked.
    return [cells[x, y] for y in range(TARGET) for x in sampled_columns]


# ── Lab k-means and Vibrant scoring (custom_schemes.cpp) ────────────────────

WHITE = (95.047, 100.0, 108.883)


def lab_f(t: float) -> float:
    return math.cbrt(t) if t > 0.008856 else (903.3 * t + 16.0) / 116.0


def lab_f_inverse(t: float) -> float:
    return t * t * t if t > 0.206893 else (116.0 * t - 16.0) / 903.3


def rgb_to_lab(color: Color) -> tuple[float, float, float]:
    r, g, b = map(linearize_channel, color)
    x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) * 100.0
    y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b) * 100.0
    z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) * 100.0
    fx, fy, fz = lab_f(x / WHITE[0]), lab_f(y / WHITE[1]), lab_f(z / WHITE[2])
    return 116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)


def lab_to_rgb(lab: tuple[float, float, float]) -> Color:
    fy = (lab[0] + 16.0) / 116.0
    fx = lab[1] / 500.0 + fy
    fz = fy - lab[2] / 200.0
    x = WHITE[0] * lab_f_inverse(fx) / 100.0
    y = WHITE[1] * lab_f_inverse(fy) / 100.0
    z = WHITE[2] * lab_f_inverse(fz) / 100.0
    linear = (3.2404542 * x - 1.5371385 * y - 0.4985314 * z,
              -0.9692660 * x + 1.8760108 * y + 0.0415560 * z,
              0.0556434 * x - 0.2040259 * y + 1.0572252 * z)

    def byte(channel: float) -> int:
        channel = clamp(channel, 0.0, 1.0)
        value = channel * 12.92 if channel <= 0.0031308 else 1.055 * channel ** (1.0 / 2.4) - 0.055
        return clamp(round_half_away(value * 255.0), 0, 255)

    return tuple(map(byte, linear))


def lab_distance(first, second) -> float:
    dl, da, db = first[0] - second[0], first[1] - second[1], first[2] - second[2]
    return math.sqrt(dl * dl + da * da + db * db)


def kmeans_centroids(colors: list[Color], k: int, iterations: int = 10) -> list[tuple[Color, int]]:
    """Lab k-means with Noctalia's deterministic lightness-ordered seeds.

    Returns (averaged centroid, count) pairs sorted by count, largest first.
    The 112x112 buffer always yields 784 samples, so upstream's fewer-colors-
    than-clusters branch is unreachable and not ported.
    """
    labs = [rgb_to_lab(color) for color in colors]
    order = sorted(range(len(labs)), key=lambda index: labs[index][0])
    step = len(labs) // k
    centroids = [labs[order[index * step]] for index in range(k)]
    assignments = [0] * len(labs)
    for _ in range(iterations):
        for index, value in enumerate(labs):
            best, nearest = math.inf, 0
            for cluster, centroid in enumerate(centroids):
                distance = lab_distance(value, centroid)
                if distance < best:
                    best, nearest = distance, cluster
            assignments[index] = nearest
        sums = [[0.0, 0.0, 0.0] for _ in range(k)]
        counts = [0] * k
        for cluster, value in zip(assignments, labs):
            total = sums[cluster]
            total[0] += value[0]
            total[1] += value[1]
            total[2] += value[2]
            counts[cluster] += 1
        for cluster in range(k):
            if counts[cluster]:
                centroids[cluster] = tuple(total / counts[cluster] for total in sums[cluster])
    counts = [assignments.count(cluster) for cluster in range(k)]
    clusters = [(lab_to_rgb(centroids[cluster]), counts[cluster]) for cluster in range(k) if counts[cluster]]
    return sorted(clusters, key=lambda entry: entry[1], reverse=True)


def vibrant_score(color: Color, count: int) -> float:
    """Chroma first, with penalties for very dark/light tones and muddy yellows."""
    hct = Hct(color)
    hue, chroma, tone = hct.hue, hct.chroma, hct.tone
    tone_penalty = 0.0
    if tone < 20.0:
        tone_penalty = (20.0 - tone) * 2.0
    elif tone > 80.0:
        tone_penalty = (tone - 80.0) * 1.5
    elif tone < 40.0:
        tone_penalty = (40.0 - tone) * 0.5
    elif tone > 60.0:
        tone_penalty = (tone - 60.0) * 0.3
    hue_penalty = 5.0 if 80.0 < hue < 110.0 else 0.0
    return (chroma - tone_penalty - hue_penalty) * float(count) ** 0.3


def extract_palette(samples: list[Color], k: int = 5) -> list[Color]:
    """Vibrant seeds: chroma-weighted centroids, padded with 60-degree hue turns."""
    cluster_count = 20
    kept = [color for color in samples if cam16(color)[1] >= 5.0]
    filtered = kept if len(kept) >= cluster_count * 2 else samples
    clusters = kmeans_centroids(filtered, cluster_count)
    scored = sorted(clusters, key=lambda entry: vibrant_score(*entry), reverse=True)
    palette = [color for color, _ in scored]
    while len(palette) < k:
        palette.append(shift_hue(palette[0], len(palette) * 60.0) if palette else (0x67, 0x50, 0xA4))
    return palette[:k]


def find_error_color(palette: list[Color]) -> Color:
    for color in palette:
        hue, saturation, lightness = to_hsl(color)
        if (hue <= 30.0 or hue >= 330.0) and saturation > 0.4 and 0.3 < lightness < 0.7:
            return color
    return (0xFD, 0x46, 0x63)


# ── Token maps (generateNormalDark / generateNormalLight) ───────────────────

def accent_seeds(palette: list[Color]) -> tuple[Color, Color, Color]:
    primary = palette[0]
    primary_hue = to_hsl(primary)[0]
    secondary = shift_hue(primary, 30.0)
    if len(palette) > 1 and hue_distance(primary_hue, to_hsl(palette[1])[0]) > 30.0:
        secondary = palette[1]
    tertiary = shift_hue(primary, 60.0)
    if len(palette) > 2:
        tertiary_hue = to_hsl(palette[2])[0]
        if (hue_distance(primary_hue, tertiary_hue) > 30.0
                and hue_distance(to_hsl(secondary)[0], tertiary_hue) > 30.0):
            tertiary = palette[2]
    return primary, secondary, tertiary


def generate_tokens(palette: list[Color], dark: bool) -> dict[str, Color]:
    primary, secondary, tertiary = accent_seeds(palette)
    error = find_error_color(palette)
    primary_h, primary_s, primary_l = to_hsl(primary)
    secondary_h, secondary_s, secondary_l = to_hsl(secondary)
    tertiary_h, tertiary_s, tertiary_l = to_hsl(tertiary)
    error_h, error_s, _ = to_hsl(error)
    text_h, text_s, _ = to_hsl(palette[0])
    t: dict[str, Color] = {}

    if dark:
        t["primary"] = from_hsl(primary_h, max(primary_s, 0.7), max(primary_l, 0.65))
        t["secondary"] = from_hsl(secondary_h, max(secondary_s, 0.6), max(secondary_l, 0.60))
        t["tertiary"] = from_hsl(tertiary_h, max(tertiary_s, 0.5), max(tertiary_l, 0.60))
    else:
        t["primary"] = from_hsl(primary_h, max(primary_s, 0.7), clamp(primary_l, 0.25, 0.45))
        t["secondary"] = from_hsl(secondary_h, max(secondary_s, 0.6), clamp(secondary_l, 0.22, 0.40))
        t["tertiary"] = from_hsl(tertiary_h, max(tertiary_s, 0.5), clamp(tertiary_l, 0.20, 0.35))
    t["error"] = error
    for name in ("primary", "secondary", "tertiary", "error"):
        t[name + "_container"] = container(t[name], dark)

    if dark:
        # Shift cyan toward blue and cap saturation by hue band.
        surface_hue = text_h
        if 160.0 <= surface_hue <= 200.0:
            surface_hue = math.fmod(surface_hue + 10.0, 360.0)
        cap = 0.35 if surface_hue < 60.0 or surface_hue > 300.0 else (0.50 if surface_hue < 120.0 else 0.90)
        base = from_hsl(surface_hue, min(text_s, cap), 0.5)
        ladder = {"surface": (cap, 0.12), "surface_variant": (min(0.80, cap), 0.16),
                  "surface_container_lowest": (0.85, 0.06), "surface_container_low": (0.85, 0.14),
                  "surface_container": (0.70, 0.16), "surface_container_high": (0.75, 0.20),
                  "surface_container_highest": (0.70, 0.24), "surface_dim": (0.85, 0.08),
                  "surface_bright": (0.75, 0.24)}
    else:
        base = palette[0]
        ladder = {"surface": (0.90, 0.90), "surface_variant": (0.80, 0.78),
                  "surface_container_lowest": (0.85, 0.96), "surface_container_low": (0.85, 0.88),
                  "surface_container": (0.80, 0.86), "surface_container_high": (0.75, 0.84),
                  "surface_container_highest": (0.70, 0.80), "surface_dim": (0.85, 0.82),
                  "surface_bright": (0.90, 0.95)}
    for name, (max_saturation, lightness) in ladder.items():
        t[name] = adjust_surface(base, max_saturation, lightness)
    surface = t["surface"]

    t["on_surface"] = ensure_contrast(from_hsl(text_h, 0.05, 0.95 if dark else 0.10), surface)
    t["on_surface_variant"] = ensure_contrast(from_hsl(text_h, 0.05, 0.70 if dark else 0.35), t["surface_variant"])
    if dark:
        t["outline"] = ensure_contrast(adjust_surface(palette[0], 0.10, 0.30), surface, 3.0)
        t["outline_variant"] = ensure_contrast(adjust_surface(palette[0], 0.10, 0.40), surface, 3.0)
        t["shadow"] = surface
    else:
        t["outline"] = ensure_contrast(from_hsl(text_h, max(text_s * 0.4, 0.25), 0.65), surface, 3.0)
        t["outline_variant"] = ensure_contrast(from_hsl(text_h, max(text_s * 0.3, 0.20), 0.75), surface, 3.0)
        t["shadow"] = from_hsl(text_h, max(text_s * 0.3, 0.15), 0.80)
    t["scrim"] = (0, 0, 0)

    for name in ("primary", "secondary", "tertiary", "error"):
        t["on_" + name] = on_accent(t[name], text_h, dark)
    for name, (hue, saturation) in (("primary", (primary_h, primary_s)), ("secondary", (secondary_h, secondary_s)),
                                    ("tertiary", (tertiary_h, tertiary_s)), ("error", (error_h, error_s))):
        t["on_" + name + "_container"] = on_container(hue, saturation, t[name + "_container"], dark)
    for name, hue in (("primary", primary_h), ("secondary", secondary_h), ("tertiary", tertiary_h)):
        accent_h, accent_s, _ = to_hsl(t[name])
        fixed = from_hsl(accent_h, max(accent_s, 0.70), 0.85 if dark else 0.40)
        fixed_dim = from_hsl(accent_h, max(accent_s, 0.65), 0.75 if dark else 0.30)
        t[name + "_fixed"], t[name + "_fixed_dim"] = fixed, fixed_dim
        t["on_" + name + "_fixed"] = ensure_contrast(from_hsl(hue, 0.15, 0.15 if dark else 0.90), fixed)
        t["on_" + name + "_fixed_variant"] = ensure_contrast(from_hsl(hue, 0.15, 0.20 if dark else 0.85), fixed_dim)

    t["surface_tint"] = t["primary"]
    t["inverse_surface"] = from_hsl(text_h, 0.08, 0.90 if dark else 0.15)
    t["inverse_on_surface"] = from_hsl(text_h, 0.05, 0.15 if dark else 0.90)
    t["inverse_primary"] = from_hsl(primary_h, max(primary_s * 0.8, 0.5), 0.40 if dark else 0.70)
    t["background"] = surface
    t["on_background"] = t["on_surface"]
    t["source_color"] = palette[0]
    return t


def container(base: Color, dark: bool) -> Color:
    hue, saturation, lightness = to_hsl(base)
    if dark:
        # Saturation steps by the remaining headroom so saturated accents stay muted.
        return from_hsl(hue, saturation + 0.15 * (1.0 - saturation), max(lightness - 0.35, 0.15))
    return from_hsl(hue, max(saturation - 0.20, 0.30), min(lightness + 0.35, 0.85))


def on_accent(accent: Color, text_hue: float, dark: bool) -> Color:
    seed = from_hsl(text_hue, 0.20, 0.12) if dark else from_hsl(text_hue, 0.1, 0.98)
    return ensure_contrast(seed, accent)


def on_container(hue: float, saturation: float, background: Color, dark: bool) -> Color:
    return ensure_contrast(from_hsl(hue, saturation, 0.90 if dark else 0.15), background, 4.5, 1 if dark else -1)


# ── Palette-style terminal colors (fixed_palette.cpp) ───────────────────────

ANSI_MIN_DISTANCE = 8.0
ANSI_HUE_STEP = 24.0
ANSI_TONE_STEP = 8.0
ANSI_MIN_HUE_CHROMA = 12.0
ANSI_MAX_STEPS = 6
BRIGHT_TONE_STEP = 6.0
BRIGHT_CHROMA_SCALE = 1.35
BRIGHT_MIN_DISTANCE = 3.0
BRIGHT_SEPARATION_STEP = 2.0
# Upstream terminal_normal_* order and the scheme role each slot starts from.
ANSI_ROLES = (("red", "error"), ("green", "primary"), ("yellow", "secondary"), ("blue", "tertiary"),
              ("magenta", "primary_fixed_dim"), ("cyan", "secondary_fixed_dim"))


def ucs_distance(first: Hct, second: Hct) -> float:
    a, b = first.ucs(), second.ucs()
    return math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2])


def distinct_color(color: Hct, taken: list[Hct], background: Color, tone_range: tuple[float, float],
                   tone_step: float) -> Hct:
    """Closest readable variant of color that does not clash with taken colors."""
    def readable(hue: float, tone: float) -> Hct:
        return Hct(ensure_contrast(solve_hct(hue, color.chroma, clamp(tone, 0.0, 100.0)), background))

    def nearest(candidate: Hct) -> float:
        return min((ucs_distance(candidate, other) for other in taken), default=math.inf)

    best = readable(color.hue, color.tone)
    best_distance = nearest(best)
    low, high = tone_range
    candidates = []
    if color.chroma >= ANSI_MIN_HUE_CHROMA:
        candidates += [(sanitize_degrees(color.hue + sign * step * ANSI_HUE_STEP), color.tone)
                       for step in range(1, ANSI_MAX_STEPS + 1) for sign in (1.0, -1.0)]
    candidates += [(color.hue, color.tone + sign * step * tone_step)
                   for step in range(1, ANSI_MAX_STEPS + 1) for sign in (1.0, -1.0)]
    for hue, tone in candidates:
        if best_distance >= ANSI_MIN_DISTANCE or not low <= tone <= high:
            continue
        candidate = readable(hue, tone)
        if not low <= candidate.tone <= high:
            continue
        distance = nearest(candidate)
        if distance > best_distance:
            best, best_distance = candidate, distance
    return best


def terminal_colors(tokens: dict[str, Color]) -> dict[str, tuple[Color, Color]]:
    """Map scheme roles to distinct, readable normal/bright ANSI pairs."""
    background = tokens["background"]
    dark_background = is_dark(background)
    min_normal = 0.0 if dark_background else BRIGHT_TONE_STEP
    max_normal = 100.0 - BRIGHT_TONE_STEP if dark_background else 100.0
    normals: list[Hct] = []
    brights: list[Hct] = []
    pairs = {}
    for slot, role in ANSI_ROLES:
        seed = Hct(tokens[role])
        seed = Hct.of(seed.hue, seed.chroma, clamp(seed.tone, min_normal, max_normal))
        normal = distinct_color(seed, normals, background, (0.0, 100.0), ANSI_TONE_STEP)
        bright_base = Hct.of(normal.hue, normal.chroma * BRIGHT_CHROMA_SCALE,
                             normal.tone + (BRIGHT_TONE_STEP if dark_background else -BRIGHT_TONE_STEP))
        bright_range = (normal.tone + 1.0, 100.0) if dark_background else (0.0, normal.tone - 1.0)
        bright = distinct_color(bright_base, brights, background, bright_range, BRIGHT_SEPARATION_STEP)
        if ucs_distance(bright, normal) < BRIGHT_MIN_DISTANCE:
            bright = distinct_color(bright_base, brights + [normal], background, bright_range,
                                    BRIGHT_SEPARATION_STEP)
        brights.append(bright)
        normals.append(normal)
        pairs[slot] = (normal.color, bright.color)
    return pairs


# ── Nonchalant contract ─────────────────────────────────────────────────────

# Nonchalant role -> Noctalia token, for roles that exist upstream.
#
# Upstream sets background == surface and fills bars, panels and OSDs with
# Surface while cards and capsules use SurfaceContainer. Nonchalant fills
# popups and the bar with `background` and the panes/cards inside them with
# `surface`, so `surface` takes surface_container to keep that layering.
DIRECT_ROLES = {
    "background": "surface", "overBackground": "on_background",
    "surface": "surface_container", "overSurface": "on_surface",
    "surfaceVariant": "surface_variant", "overSurfaceVariant": "on_surface_variant",
    "surfaceDim": "surface_dim", "surfaceBright": "surface_bright",
    "surfaceContainerLowest": "surface_container_lowest", "surfaceContainerLow": "surface_container_low",
    "surfaceContainer": "surface_container", "surfaceContainerHigh": "surface_container_high",
    "surfaceContainerHighest": "surface_container_highest", "surfaceTint": "surface_tint",
    "outline": "outline", "outlineVariant": "outline_variant", "shadow": "shadow", "scrim": "scrim",
    "inverseSurface": "inverse_surface", "inverseOnSurface": "inverse_on_surface",
    "inversePrimary": "inverse_primary", "sourceColor": "source_color",
    "error": "error", "overError": "on_error", "errorContainer": "error_container",
    "overErrorContainer": "on_error_container",
}
for _accent in ("primary", "secondary", "tertiary"):
    _title = _accent.title()
    DIRECT_ROLES.update({
        _accent: _accent, "over" + _title: "on_" + _accent,
        _accent + "Container": _accent + "_container", "over" + _title + "Container": "on_" + _accent + "_container",
        _accent + "Fixed": _accent + "_fixed", _accent + "FixedDim": _accent + "_fixed_dim",
        "over" + _title + "Fixed": "on_" + _accent + "_fixed",
        "over" + _title + "FixedVariant": "on_" + _accent + "_fixed_variant",
    })


def hex_color(color: Color) -> str:
    return "#{:02x}{:02x}{:02x}".format(*color)


def to_contract(tokens: dict[str, Color], dark: bool) -> dict[str, str]:
    """Express Noctalia tokens with Nonchalant's role names.

    Legacy slots are Noctalia's palette-style terminal colors: red..cyan are
    terminal_normal_*, light* are terminal_bright_*, and white is
    terminal_normal_white (on_surface_variant). Upstream has no container or
    foreground for those slots, so they reuse the scheme's accent recipes.
    """
    result = {name: hex_color(tokens[token]) for name, token in DIRECT_ROLES.items()}
    text_hue = to_hsl(tokens["source_color"])[0]
    pairs = terminal_colors(tokens)
    slots = {slot: (pairs[slot], tokens[role]) for slot, role in ANSI_ROLES}
    slots["white"] = ((tokens["on_surface_variant"], None), tokens["on_surface_variant"])
    for slot, ((normal, bright), seed) in slots.items():
        title = slot.title()
        slot_container = container(normal, dark)
        hue, saturation, _ = to_hsl(normal)
        result[slot] = hex_color(normal)
        if bright is not None:
            result["light" + title] = hex_color(bright)
        result[slot + "Source"] = result[slot + "Value"] = hex_color(seed)
        result[slot + "Container"] = hex_color(slot_container)
        result["over" + title] = hex_color(on_accent(normal, text_hue, dark))
        result["over" + title + "Container"] = hex_color(on_container(hue, saturation, slot_container, dark))
    return result


# Nonchalant status roles. Warning and success have no upstream counterpart;
# their hues stay fixed so they never borrow a wallpaper accent. `danger` is
# upstream `error` made readable as text: the error token itself stays exact.
STATUS_HUES = {"warning": 38.0, "success": 135.0}
# Every panel role status text can sit on: Nonchalant background, surface,
# raised cards and the hover lift.
STATUS_BACKGROUNDS = ("surface", "surface_container", "surface_container_highest", "surface_bright")


def status_roles(tokens: dict[str, Color], dark: bool) -> dict[str, str]:
    text_hue = to_hsl(tokens["source_color"])[0]
    seeds = {name: from_hsl(hue, 0.75, 0.62 if dark else 0.34) for name, hue in STATUS_HUES.items()}
    seeds["danger"] = tokens["error"]
    result: dict[str, str] = {}
    for name, value in seeds.items():
        # All panel roles share a polarity, so each step only moves further away.
        for background in STATUS_BACKGROUNDS:
            value = ensure_contrast(value, tokens[background])
        result[name] = hex_color(value)
        result["over" + name.title()] = hex_color(on_accent(value, text_hue, dark))
    return result


def generate(image_path: Path, mode: str) -> dict[str, str]:
    palette = extract_palette(load_samples(image_path))
    dark = mode == "dark"
    tokens = generate_tokens(palette, dark)
    return {**to_contract(tokens, dark), **status_roles(tokens, dark)}
