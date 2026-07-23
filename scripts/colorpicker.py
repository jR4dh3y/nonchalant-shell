#!/usr/bin/env python3

import colorsys
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def cmd(*args, input=None):
    return subprocess.check_output(args, input=input)


for dep in ("niri", "magick", "wl-copy", "notify-send"):
    if subprocess.call(["which", dep], stdout=subprocess.DEVNULL) != 0:
        subprocess.call(
            [
                "notify-send",
                "Color Picker",
                f"Missing dependency: {dep}",
                "-u",
                "critical",
            ]
        )
        sys.exit(1)


def pick_rgb():
    """Use niri's built-in color picker. Prefer JSON; fall back to text."""
    try:
        raw = subprocess.check_output(
            ["niri", "msg", "--json", "pick-color"],
            stderr=subprocess.DEVNULL,
        ).decode()
        data = json.loads(raw)
        # Expected shapes vary slightly across versions:
        #   {"rgb": [r, g, b]} with 0..1 floats, or {"rgb": {"r":..}} etc.
        if isinstance(data, dict):
            rgb = data.get("rgb") or data.get("color") or data
            if isinstance(rgb, dict):
                r = rgb.get("r", rgb.get("red"))
                g = rgb.get("g", rgb.get("green"))
                b = rgb.get("b", rgb.get("blue"))
                vals = [r, g, b]
            elif isinstance(rgb, (list, tuple)) and len(rgb) >= 3:
                vals = list(rgb[:3])
            else:
                vals = None
            if vals is not None and all(v is not None for v in vals):
                # niri JSON often uses 0..1 floats; accept 0..255 ints too.
                out = []
                for v in vals:
                    fv = float(v)
                    out.append(int(round(fv * 255)) if fv <= 1.0 else int(round(fv)))
                return out
    except (subprocess.CalledProcessError, json.JSONDecodeError, TypeError, ValueError):
        pass

    try:
        text = subprocess.check_output(
            ["niri", "msg", "pick-color"],
            stderr=subprocess.DEVNULL,
        ).decode()
    except subprocess.CalledProcessError:
        return None

    hex_match = re.search(r"#([0-9a-fA-F]{6})", text)
    if hex_match:
        h = hex_match.group(1)
        return [int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)]

    rgb_match = re.search(
        r"rgb\s*\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)",
        text,
        re.IGNORECASE,
    )
    if rgb_match:
        vals = [float(rgb_match.group(i)) for i in (1, 2, 3)]
        return [
            int(round(v * 255)) if v <= 1.0 else int(round(v))
            for v in vals
        ]

    return None


rgb = pick_rgb()
if not rgb:
    sys.exit(0)

r, g, b = rgb
hex_color = f"#{r:02X}{g:02X}{b:02X}"
rgb_color = f"rgb({r}, {g}, {b})"

rn, gn, bn = r / 255, g / 255, b / 255
h, s, v = colorsys.rgb_to_hsv(rn, gn, bn)
hsv_color = f"hsv({round(h*360)}, {round(s*100)}%, {round(v*100)}%)"

icon = Path(tempfile.gettempdir()) / "color_picker_preview.png"
cmd("magick", "-size", "64x64", f"xc:{hex_color}", str(icon))

subprocess.run(["wl-copy"], input=hex_color.encode())

proc = subprocess.Popen(
    [
        "notify-send",
        "Color Picked",
        f"{hex_color} copied to clipboard",
        "-i",
        str(icon),
        "-a",
        "ColorPicker",
        "-u",
        "normal",
        "--action=hex=Copy HEX",
        "--action=rgb=Copy RGB",
        "--action=hsv=Copy HSV",
    ],
    stdout=subprocess.PIPE,
)

action = proc.communicate()[0].decode().strip()

if action == "rgb":
    subprocess.run(["wl-copy"], input=rgb_color.encode())
    subprocess.call(
        [
            "notify-send",
            "Color Picker",
            f"RGB copied: {rgb_color}",
            "-i",
            str(icon),
            "-u",
            "low",
        ]
    )
elif action == "hsv":
    subprocess.run(["wl-copy"], input=hsv_color.encode())
    subprocess.call(
        [
            "notify-send",
            "Color Picker",
            f"HSV copied: {hsv_color}",
            "-i",
            str(icon),
            "-u",
            "low",
        ]
    )
elif action == "hex":
    subprocess.run(["wl-copy"], input=hex_color.encode())
    subprocess.call(
        [
            "notify-send",
            "Color Picker",
            f"HEX copied: {hex_color}",
            "-i",
            str(icon),
            "-u",
            "low",
        ]
    )
