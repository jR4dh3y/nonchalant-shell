"""Behavior checks for extraction, readable roles, and safe palette publication."""

import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from PIL import Image, ImageDraw
from scripts.wallpaper_palette import build_palette, contrast, extract, hue_distance, lab

ROOT = Path(__file__).resolve().parents[2]


def rgb(value: str) -> tuple[float, float, float]:
    return tuple(int(value[index:index + 2], 16) / 255 for index in (1, 3, 5))


class WallpaperPaletteTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.image = self.root / "wall paper ' $name.png"

    def stripes(self, colors):
        image = Image.new("RGB", (300, 200))
        draw = ImageDraw.Draw(image)
        for index, color in enumerate(colors):
            draw.rectangle((index * 300 // len(colors), 0,
                            (index + 1) * 300 // len(colors) - 1, 199), fill=color)
        image.save(self.image)

    def run_generator(self, scheme="scheme-wallpaper", mode="dark", extra_env=None):
        return subprocess.run(
            ["bash", str(ROOT / "scripts/generate_wallpaper_colors.sh"), str(self.image),
             scheme, mode, str(ROOT / "assets/matugen/config.toml"), str(self.root / "colors.json")],
            env={**os.environ, "HOME": str(self.root), **(extra_env or {})},
            capture_output=True, text=True, timeout=30)

    def test_distinct_wallpaper_hues_survive_extraction(self):
        colors = ["#cd7840", "#36a89c", "#82b44b", "#ddbb42"]
        self.stripes(colors)
        sources = extract(self.image)
        self.assertGreaterEqual(len(sources), 3)
        for source in sources:
            self.assertLess(min(hue_distance(source, lab(rgb(color))) for color in colors), 5)
        palette = build_palette(sources, "dark")
        accents = [lab(rgb(palette[role])) for role in ("primary", "secondary", "tertiary")]
        for index, first in enumerate(accents):
            for second in accents[index + 1:]:
                self.assertGreater(hue_distance(first, second), 25)

    def test_small_accents_survive_large_gray_regions(self):
        image = Image.new("RGB", (200, 200), "#666666")
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 0, 35, 35), fill="#ce593d")
        draw.rectangle((50, 0, 85, 35), fill="#368bbe")
        image.save(self.image)
        sources = extract(self.image)
        self.assertEqual(len(sources), 2)
        self.assertGreater(hue_distance(*sources), 90)

    def test_grayscale_does_not_invent_rainbow_accents(self):
        self.stripes(["#222222", "#888888", "#eeeeee"])
        palette = build_palette(extract(self.image), "dark")
        for name in ("primary", "secondary", "tertiary", "red", "green", "yellow", "blue", "magenta", "cyan"):
            value = lab(rgb(palette[name]))
            self.assertLess(math.hypot(*value[1:]), 0.005)

    def test_every_accent_slot_comes_from_and_changes_with_wallpaper(self):
        names = ("primary", "secondary", "tertiary", "red", "green", "yellow", "blue", "magenta", "cyan", "error")
        palettes = []
        for colors in (["#bd6036", "#dba74c", "#c64745"], ["#24799e", "#436bc2", "#319889"]):
            self.stripes(colors)
            sources = extract(self.image)
            palette = build_palette(sources, "dark")
            palettes.append(palette)
            for name in names:
                actual = lab(rgb(palette[name]))
                self.assertLess(min(hue_distance(actual, sample) for sample in sources), 2,
                                f"{name} invented a hue outside the wallpaper")
        for name in names:
            self.assertNotEqual(palettes[0][name], palettes[1][name],
                                f"{name} stayed fixed across warm and cool wallpapers")

    def test_transparent_pixels_do_not_supply_hidden_colors(self):
        image = Image.new("RGBA", (100, 100), (255, 0, 255, 0))
        ImageDraw.Draw(image).rectangle((0, 0, 30, 30), fill=(40, 140, 180, 255))
        image.save(self.image)
        sources = extract(self.image)
        self.assertEqual(len(sources), 1)
        self.assertLess(hue_distance(sources[0], lab((40 / 255, 140 / 255, 180 / 255))), 5)

    def test_complete_contract_and_contrast_in_both_modes(self):
        self.stripes(["#cd7840", "#36a89c", "#82b44b", "#ddbb42", "#587fbc"])
        expected = set(json.loads((ROOT / "assets/matugen/colors.json").read_text()))
        sources = extract(self.image)
        for mode in ("dark", "light"):
            with self.subTest(mode=mode):
                palette = build_palette(sources, mode)
                self.assertEqual(set(palette), expected)
                for value in palette.values():
                    self.assertRegex(value, r"^#[0-9a-f]{6}$")
                for name in ("primary", "secondary", "tertiary", "red", "green", "yellow",
                             "blue", "cyan", "magenta", "white", "error"):
                    title = name[0].upper() + name[1:]
                    for suffix in ("", "Container"):
                        self.assertGreaterEqual(contrast(rgb(palette[name + suffix]),
                                                        rgb(palette["over" + title + suffix])), 4.5)
                    self.assertGreaterEqual(contrast(rgb(palette[name]), rgb(palette["surfaceBright"])), 4.5)
                for background in ("background", "surface", "surfaceBright", "surfaceContainerHighest"):
                    self.assertGreaterEqual(contrast(rgb(palette[background]), rgb(palette["overSurface"])), 4.5)

    @unittest.skipUnless(shutil.which("node"), "node unavailable")
    def test_shared_bar_module_roles_have_readable_foregrounds(self):
        # Execute the actual role mapping rather than copying it into a test model.
        source = (ROOT / "modules/theme/Colors.qml").read_text()
        match = re.search(r"function accentRole\(module: string\): string \{(.*?)\n    \}", source, re.S)
        self.assertIsNotNone(match)
        modules = ["sound", "mic", "brightness", "wifi", "bluetooth", "battery",
                   "media", "calendar", "wallpapers", "weather", "power", "stats", "notifications"]
        result = subprocess.run(
            ["node", "-e", "const fs=require('fs'); const p=JSON.parse(fs.readFileSync(0,'utf8'));"
             "const role=new Function('module',p.body); console.log(JSON.stringify(p.modules.map(role)));"],
            input=json.dumps({"body": match.group(1), "modules": modules}),
            capture_output=True, text=True, check=True)
        roles = json.loads(result.stdout)
        self.assertEqual(set(roles), {"primary"})
        self.stripes(["#cd7840", "#36a89c", "#82b44b", "#ddbb42", "#587fbc"])
        for mode in ("dark", "light"):
            palette = build_palette(extract(self.image), mode)
            for module, role in zip(modules, roles):
                with self.subTest(mode=mode, module=module):
                    foreground = "over" + role[0].upper() + role[1:]
                    self.assertGreaterEqual(contrast(rgb(palette[role]), rgb(palette[foreground])), 4.5)

    @unittest.skipUnless(shutil.which("node"), "node unavailable")
    def test_resource_roles_follow_warning_thresholds_in_both_panels(self):
        source = (ROOT / "modules/theme/Colors.qml").read_text()
        match = re.search(r"function metricRole\(metric: string, usage: real\): string \{(.*?)\n    \}", source, re.S)
        self.assertIsNotNone(match)
        cases = [["cpu", 0], ["cpu", 69], ["cpu", 70], ["cpu", 90],
                 ["disk", 74], ["disk", 75], ["disk", 90],
                 ["memory", 95], ["gpu", 0], ["network", 0]]
        result = subprocess.run(
            ["node", "-e", "const fs=require('fs'); const p=JSON.parse(fs.readFileSync(0,'utf8'));"
             "const role=new Function('metric','usage',p.body);"
             "console.log(JSON.stringify(p.cases.map(c=>role(...c))));"],
            input=json.dumps({"body": match.group(1), "cases": cases}),
            capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout),
                         ["primary", "primary", "yellow", "red", "primary", "yellow", "red",
                          "blue", "yellow", "green"])
        for path in ("modules/bar/island/IslandStatsPanel.qml",
                     "modules/widgets/dashboard/metrics/MetricsTab.qml"):
            panel = (ROOT / path).read_text()
            for metric in ("cpu", "disk", "memory", "gpu", "network"):
                self.assertIn('Colors.metricRole("' + metric + '"', panel)

    def test_image_and_gif_use_same_first_frame(self):
        self.stripes(["#cd7840", "#36a89c", "#82b44b"])
        sources = extract(self.image)
        gif = self.root / "animated.gif"
        with Image.open(self.image) as image:
            image.save(gif, save_all=True, append_images=[Image.new("RGB", image.size, "blue")])
        self.assertEqual(sources, extract(gif))

    def test_wrapper_publishes_only_requested_path(self):
        self.stripes(["#cd7840", "#36a89c", "#82b44b"])
        result = self.run_generator()
        self.assertEqual(result.returncode, 0, result.stderr)
        palette = json.loads((self.root / "colors.json").read_text())
        self.assertEqual(palette, build_palette(extract(self.image), "dark"))
        self.assertFalse((self.root / ".cache/nonchalant/colors.json").exists())
        self.assertEqual(list(self.root.glob("colors.json.*")), [])

    def test_bad_image_preserves_previous_palette(self):
        self.image.write_text("not an image")
        output = self.root / "colors.json"
        output.write_text('{"previous":true}')
        result = self.run_generator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error", json.loads(result.stderr))
        self.assertEqual(output.read_text(), '{"previous":true}')

    @unittest.skipUnless(shutil.which("matugen"), "matugen unavailable")
    def test_material_scheme_generates_fresh_isolated_output(self):
        self.stripes(["#cd7840", "#36a89c", "#82b44b"])
        result = self.run_generator("scheme-tonal-spot")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("primary", json.loads((self.root / "colors.json").read_text()))
        self.assertFalse((self.root / ".cache/nonchalant/colors.json").exists())

    def test_success_without_output_cannot_reuse_stale_palette(self):
        self.stripes(["#cd7840", "#36a89c", "#82b44b"])
        output = self.root / "colors.json"
        output.write_text('{"previous":true}')
        commands = self.root / "bin"
        commands.mkdir()
        for name in ("matugen", "wallust"):
            script = commands / name
            script.write_text("#!/bin/sh\nexit 0\n")
            script.chmod(0o755)
        result = self.run_generator("scheme-tonal-spot", extra_env={"PATH": str(commands) + ":" + os.environ["PATH"]})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(output.read_text(), '{"previous":true}')

    @unittest.skipUnless(shutil.which("wallust"), "wallust unavailable")
    def test_wallust_fallback_publishes_complete_palette(self):
        self.stripes(["#cd7840", "#36a89c", "#82b44b"])
        commands = self.root / "bin"
        commands.mkdir()
        script = commands / "matugen"
        script.write_text("#!/bin/sh\nexit 1\n")
        script.chmod(0o755)
        expected = set(json.loads((ROOT / "assets/matugen/colors.json").read_text()))
        for mode in ("dark", "light"):
            with self.subTest(mode=mode):
                result = self.run_generator("scheme-tonal-spot", mode,
                                            {"PATH": str(commands) + ":" + os.environ["PATH"]})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(set(json.loads((self.root / "colors.json").read_text())), expected)


if __name__ == "__main__":
    unittest.main()
