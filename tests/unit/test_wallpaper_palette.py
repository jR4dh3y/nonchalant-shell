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
from scripts import noctalia_vibrant as vibrant

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
        self.assertGreaterEqual(len(sources.accents), 3)
        for source in sources.accents:
            self.assertLess(min(hue_distance(source, lab(rgb(color))) for color in colors), 5)
        palette = build_palette(sources, "dark")
        accents = [lab(rgb(palette[role])) for role in ("primary", "secondary", "tertiary")]
        for index, first in enumerate(accents):
            for second in accents[index + 1:]:
                self.assertGreater(hue_distance(first, second), 25)

    @unittest.skipUnless(shutil.which("node"), "node unavailable")
    def test_wallpaper_command_selects_extractor_and_clears_preset(self):
        shortcuts = (ROOT / "modules/services/GlobalShortcuts.qml").read_text()
        manager = (ROOT / "modules/widgets/dashboard/wallpapers/WallpaperManager.qml").read_text()
        command = re.search(r"function run\(command\) \{(.*?)\n    \}", shortcuts, re.S)
        scheme = re.search(r"function setMatugenScheme\(scheme: string\): void \{(.*?)\n    \}", manager, re.S)
        self.assertIsNotNone(command)
        self.assertIsNotNone(scheme)
        result = subprocess.run(
            ["node", "-e", """
const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
const config = {adapter: {matugenScheme: 'scheme-tonal-spot', activeColorPreset: 'Preset'}};
let generations = 0;
const quiet = {log() {}};
const setScheme = new Function('scheme', 'state', 'globalColors', data.scheme);
const manager = {setMatugenScheme(value) {
    setScheme(value, config.adapter, {refresh() {generations++}});
}};
const run = new Function('command', 'GlobalStates', 'Config', 'console', data.command);
run('wallpaper-colors', {wallpaperManager: manager}, {bar: {style: 'default'}}, quiet);
console.log(JSON.stringify({adapter: config.adapter, generations}));
"""],
            input=json.dumps({"command": command.group(1), "scheme": scheme.group(1)}),
            capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout), {
            "adapter": {"matugenScheme": "scheme-wallpaper", "activeColorPreset": ""},
            "generations": 1,
        })

    def test_small_accents_survive_large_gray_regions(self):
        image = Image.new("RGB", (200, 200), "#666666")
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 0, 35, 35), fill="#ce593d")
        draw.rectangle((50, 0, 85, 35), fill="#368bbe")
        image.save(self.image)
        sources = extract(self.image).accents
        self.assertEqual(len(sources), 2)
        self.assertGreater(hue_distance(*sources), 90)


    def test_grayscale_does_not_invent_rainbow_accents(self):
        self.stripes(["#222222", "#888888", "#eeeeee"])
        palette = build_palette(extract(self.image), "dark")
        for name in ("primary", "secondary", "tertiary", "red", "green", "yellow", "blue", "magenta", "cyan"):
            value = lab(rgb(palette[name]))
            self.assertLess(math.hypot(*value[1:]), 0.005)

    def test_every_accent_slot_comes_from_and_changes_with_wallpaper(self):
        # Terminal slots and accents follow the image. Status roles (error,
        # warning, success) are checked separately: they keep their hue.
        names = ("primary", "secondary", "tertiary", "red", "green", "yellow", "blue", "magenta", "cyan")
        palettes = []
        for colors in (["#bd6036", "#dba74c", "#c64745"], ["#24799e", "#436bc2", "#319889"]):
            self.stripes(colors)
            sources = extract(self.image)
            palette = build_palette(sources, "dark")
            palettes.append(palette)
            for name in names:
                actual = lab(rgb(palette[name]))
                self.assertLess(min(hue_distance(actual, sample) for sample in sources.accents), 2,
                                f"{name} invented a hue outside the wallpaper")
        for name in names:
            self.assertNotEqual(palettes[0][name], palettes[1][name],
                                f"{name} stayed fixed across warm and cool wallpapers")

    def test_status_roles_keep_their_hue_on_every_wallpaper(self):
        # Red, amber and green bands in OKLab hue degrees.
        bands = {"error": (0, 40), "warning": (45, 95), "success": (120, 165)}
        for colors in (["#bd6036", "#dba74c", "#c64745"], ["#24799e", "#436bc2", "#319889"],
                       ["#d23a3a", "#e0a020", "#3aa040"], ["#222222", "#888888", "#eeeeee"]):
            self.stripes(colors)
            sources = extract(self.image)
            for mode in ("dark", "light"):
                palette = build_palette(sources, mode)
                for role, (low, high) in bands.items():
                    with self.subTest(colors=colors, mode=mode, role=role):
                        hue = math.degrees(math.atan2(*reversed(lab(rgb(palette[role]))[1:]))) % 360
                        self.assertTrue(low <= hue <= high, f"{role} hue {hue:.0f}")
                        title = role[0].upper() + role[1:]
                        self.assertGreaterEqual(contrast(rgb(palette[role]), rgb(palette["over" + title])), 4.5)
                        self.assertGreaterEqual(contrast(rgb(palette[role]), rgb(palette["surfaceBright"])), 4.5)

    def test_transparent_pixels_do_not_supply_hidden_colors(self):
        image = Image.new("RGBA", (100, 100), (255, 0, 255, 0))
        ImageDraw.Draw(image).rectangle((0, 0, 30, 30), fill=(40, 140, 180, 255))
        image.save(self.image)
        sources = extract(self.image).accents
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
                self.assertEqual((palette["danger"], palette["overDanger"]), (palette["error"], palette["overError"]))
                for name in ("warning", "success"):
                    title = name[0].upper() + name[1:]
                    self.assertGreaterEqual(contrast(rgb(palette[name]), rgb(palette["over" + title])), 4.5)
                    self.assertGreaterEqual(contrast(rgb(palette[name]), rgb(palette["surfaceBright"])), 4.5)
                for background in ("background", "surface", "surfaceBright", "surfaceContainerHighest"):
                    self.assertGreaterEqual(contrast(rgb(palette[background]), rgb(palette["overSurface"])), 4.5)

    def test_inline_osd_paths_treat_mute_as_inactive(self):
        # Both OSD paths and the Pills inline strip: primary progress, muted
        # progress outlineVariant, muted ink overSurfaceVariant, never error.
        pills = (ROOT / "modules/bar/layouts/PillsBar.qml").read_text()
        self.assertIn("root.osdMuted ? root.shellPalette.overSurfaceVariant : root.shellPalette.primary", pills)
        self.assertIn("root.osdMuted ? root.shellPalette.outlineVariant : root.shellPalette.primary", pills)
        banner = (ROOT / "modules/bar/island/IslandOsdBanner.qml").read_text()
        osd = (ROOT / "modules/shell/osd/OSD.qml").read_text()
        island = (ROOT / "modules/bar/layouts/IslandBar.qml").read_text()
        for source in (banner, osd, island):
            self.assertIn("shellPalette.outlineVariant : Styling.srItem(\"overprimary\"", source)
        for source in (banner, osd):
            self.assertIn("shellPalette.overSurfaceVariant", source)
            self.assertNotIn("shellPalette.error", source)
        self.assertNotIn("accentRole", (ROOT / "modules/theme/ShellPalette.qml").read_text())

    @unittest.skipUnless(shutil.which("node"), "node unavailable")
    def test_classic_resource_roles_follow_warning_thresholds(self):
        source = (ROOT / "modules/theme/ShellPalette.qml").read_text()
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
        roles = json.loads(result.stdout)
        self.assertEqual(roles, ["primary", "primary", "warning", "danger", "primary", "warning", "danger",
                                 "secondary", "primary", "tertiary"])
        # Every returned name is a palette property; none is a terminal slot.
        for role in set(roles):
            self.assertRegex(source, r"property color " + role + r":")
        panel = (ROOT / "modules/widgets/dashboard/metrics/MetricsTab.qml").read_text()
        for metric in ("cpu", "disk", "memory", "gpu", "network"):
            self.assertIn('.shellPalette.metricRole("' + metric + '"', panel)

    def test_image_and_gif_use_same_first_frame(self):
        self.stripes(["#cd7840", "#36a89c", "#82b44b"])
        sources = extract(self.image)
        gif = self.root / "animated.gif"
        with Image.open(self.image) as image:
            image.save(gif, save_all=True, append_images=[Image.new("RGB", image.size, "blue")])
        self.assertEqual(sources, extract(gif))

    @unittest.skipUnless(shutil.which("ffmpeg"), "FFmpeg unavailable")
    def test_video_extracts_a_palette_before_any_thumbnail_exists(self):
        self.stripes(["#cd7840", "#36a89c", "#82b44b"])
        video = self.root / "video wallpaper.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-loop", "1", "-i", str(self.image),
                        "-t", "0.1", "-threads", "1", "-pix_fmt", "yuv420p", str(video)],
                       capture_output=True, check=True, timeout=30)
        self.image = video
        result = self.run_generator("scheme-noctalia-vibrant")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("primary", json.loads((self.root / "colors.json").read_text()))
        self.assertFalse((self.root / ".cache").exists())

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
        self.assertNotIn("trying wallust", result.stderr)

    @unittest.skipUnless(shutil.which("matugen"), "matugen unavailable")
    def test_material_scheme_accepts_avif_with_a_webp_filename(self):
        Image.init()
        if "AVIF" not in Image.SAVE:
            self.skipTest("Pillow AVIF encoder unavailable")
        self.image = self.root / "wallpaper.webp"
        Image.new("RGB", (64, 64), "#368bbe").save(self.image, "AVIF")
        result = self.run_generator("scheme-expressive")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("trying wallust", result.stderr)
        output = json.loads((self.root / "colors.json").read_text())
        self.assertIn("primary", output)

    @unittest.skipUnless(shutil.which("matugen"), "matugen unavailable")
    def test_material_picker_variants_generate_complete_palettes(self):
        self.stripes(["#6b658e", "#4c467d", "#670d35", "#806440"])
        output = self.root / "colors.json"
        expected = set(json.loads((ROOT / "assets/matugen/colors.json").read_text()))
        for mode in ("dark", "light"):
            palettes = {}
            for scheme in ("content-dominant", "expressive-dominant", "tonal-spot", "tonal-spot-contrast", "smart"):
                with self.subTest(mode=mode, scheme=scheme):
                    result = self.run_generator("scheme-" + scheme, mode)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertNotIn("trying wallust", result.stderr)
                    palettes[scheme] = json.loads(output.read_text())
                    self.assertEqual(set(palettes[scheme]), expected)
            self.assertEqual(palettes["content-dominant"]["sourceColor"], palettes["expressive-dominant"]["sourceColor"])
            self.assertNotEqual(palettes["tonal-spot"]["primary"], palettes["tonal-spot-contrast"]["primary"])

    @unittest.skipUnless(shutil.which("matugen"), "matugen unavailable")
    def test_wallpaper_area_controls_surfaces_across_schemes_and_modes(self):
        image = Image.new("RGB", (300, 120), "#555876")
        draw = ImageDraw.Draw(image)
        draw.rectangle((100, 0, 199, 119), fill="#454867")
        draw.rectangle((200, 0, 299, 119), fill="#646888")
        draw.rectangle((130, 35, 170, 85), fill="#b7012a")
        image.save(self.image)
        output = self.root / "colors.json"
        for mode in ("dark", "light"):
            palettes = []
            for scheme in ("scheme-wallpaper", "scheme-content-dominant", "scheme-content", "scheme-expressive"):
                result = self.run_generator(scheme, mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                palette = json.loads(output.read_text())
                palettes.append(palette)
                neutral = lab(rgb(palette["background"]))
                self.assertLess(hue_distance(neutral, lab(rgb("#555876"))), 12)
                self.assertLessEqual(math.hypot(*neutral[1:]), 0.017)
                self.assertGreater(contrast(rgb(palette["surface"]), rgb(palette["surfaceBright"])), 1.22)
                self.assertGreater(contrast(rgb(palette["overSurface"]), rgb(palette["surfaceBright"])), 4.5)
            for role in ("background", "surface", "surfaceBright", "outline"):
                self.assertEqual(len({palette[role] for palette in palettes}), 1)
            self.assertGreater(len({palette["primary"] for palette in palettes}), 1)

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



def pink_accent(path: Path) -> None:
    image = Image.new("RGB", (200, 200), "#aa916a")
    ImageDraw.Draw(image).rectangle((0, 0, 40, 40), fill="#dc2380")
    image.save(path)


def five_stripes(path: Path) -> None:
    image = Image.new("RGB", (300, 200))
    draw = ImageDraw.Draw(image)
    for index, color in enumerate(["#cd7840", "#36a89c", "#82b44b", "#ddbb42", "#587fbc"]):
        draw.rectangle((index * 60, 0, index * 60 + 59, 199), fill=color)
    image.save(path)


def oklab_chroma(value: str) -> float:
    return math.hypot(*lab(rgb(value))[1:])


def luminance(value: str) -> float:
    return vibrant.relative_luminance(tuple(int(value[i:i + 2], 16) for i in (1, 3, 5)))


class NoctaliaVibrantTests(unittest.TestCase):
    """scheme-noctalia-vibrant is a port of Noctalia v5.5.0's Vibrant scheme."""

    # Values from Noctalia v5.5.0 (c2573248) built unmodified, run on the same
    # fixtures, written with Nonchalant role names (see docs/wallpaper-colors.md).
    UPSTREAM = {
        ("pink", "dark"): {
            "sourceColor": "#dc2380", "background": "#29141f", "surface": "#371b29",
            "surfaceContainerHighest": "#53283d", "overSurface": "#f3f2f2", "outline": "#71626a",
            "primary": "#e665a6", "secondary": "#d6a65c", "tertiary": "#99e34f", "error": "#fd4663",
            "red": "#fd4663", "lightRed": "#ff6a7b", "green": "#e665a6", "yellow": "#d6a65c",
            "blue": "#99e34f", "magenta": "#ed91c0", "cyan": "#e9c896",
        },
        ("pink", "light"): {
            "sourceColor": "#dc2380", "background": "#f8d3e6", "surface": "#f5c1db",
            "surfaceContainerHighest": "#f0a8cc", "overSurface": "#1b181a", "outline": "#a16f89",
            "primary": "#c62073", "secondary": "#a37329", "tertiary": "#5a9a18", "error": "#fd4663",
            "red": "#c4003c", "lightRed": "#a90032", "green": "#bc106b", "yellow": "#865800",
            "blue": "#3d6e00", "magenta": "#84154d", "cyan": "#6d5e1a",
        },
        ("stripes", "dark"): {
            "sourceColor": "#82b44b", "background": "#1f2b12", "surface": "#2a3a18",
            "surfaceContainerHighest": "#3e5624", "overSurface": "#f2f3f2", "outline": "#6b7363",
            "primary": "#a9e467", "secondary": "#d68c5c", "tertiary": "#65cdc2", "error": "#cd7840",
            "red": "#ce7840", "lightRed": "#f27e2b", "green": "#a9e467", "yellow": "#c79449",
            "blue": "#65cdc2", "magenta": "#9ef1b7", "cyan": "#e9b696",
        },
        ("stripes", "light"): {
            "sourceColor": "#82b44b", "background": "#e6f0db", "surface": "#dceacd",
            "surfaceContainerHighest": "#cde1b7", "overSurface": "#1a1b18", "outline": "#7b8e63",
            "primary": "#77c322", "secondary": "#a35929", "tertiary": "#2b877d", "error": "#cd7840",
            "red": "#a75518", "lightRed": "#964600", "green": "#457800", "yellow": "#936104",
            "blue": "#16786f", "magenta": "#007b45", "cyan": "#7e421b",
        },
    }
    ACCENTS = ("primary", "secondary", "tertiary", "error", "red", "green", "yellow",
               "blue", "magenta", "cyan", "white")
    TERMINAL = ("red", "green", "yellow", "blue", "magenta", "cyan")

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.fixtures = {"pink": self.root / "pink.png", "stripes": self.root / "stripes.png"}
        pink_accent(self.fixtures["pink"])
        five_stripes(self.fixtures["stripes"])

    def generate(self, name: str, mode: str) -> dict[str, str]:
        return vibrant.generate(self.fixtures[name], mode)

    def test_matches_upstream_noctalia_on_the_same_image(self):
        for (name, mode), expected in self.UPSTREAM.items():
            with self.subTest(fixture=name, mode=mode):
                palette = self.generate(name, mode)
                self.assertEqual({role: palette[role] for role in expected}, expected)

    def test_status_roles_keep_their_hue_and_contrast(self):
        # danger follows upstream's error seed (a red-family image color or
        # #fd4663); only its lightness moves so it reads as text.
        bands = {"warning": (45, 95), "success": (120, 165), "danger": None}
        for name in self.fixtures:
            for mode in ("dark", "light"):
                palette = self.generate(name, mode)
                for role, band in bands.items():
                    with self.subTest(fixture=name, mode=mode, role=role):
                        value = lab(rgb(palette[role]))
                        hue = math.degrees(math.atan2(value[2], value[1])) % 360
                        if band:
                            self.assertTrue(band[0] <= hue <= band[1], f"{role} hue {hue:.0f}")
                        else:
                            self.assertLess(hue_distance(value, lab(rgb(palette["error"]))), 10)
                        title = role[0].upper() + role[1:]
                        self.assertGreaterEqual(contrast(rgb(palette[role]), rgb(palette["over" + title])), 4.5)
                        for surface in ("background", "surface", "surfaceContainerHighest", "surfaceBright"):
                            self.assertGreaterEqual(contrast(rgb(palette[role]), rgb(palette[surface])), 4.5)

    def test_small_saturated_accent_beats_large_muted_area(self):
        self.assertEqual(build_palette(extract(self.fixtures["pink"]), "dark")["sourceColor"], "#aa916a")
        self.assertEqual(self.generate("pink", "dark")["sourceColor"], "#dc2380")

    def test_surfaces_are_visibly_tinted_by_the_wallpaper(self):
        # Panels, panes and cards. The ladder ends near black/white hold less chroma.
        panels = ("background", "surface", "surfaceVariant", "surfaceContainerLow",
                  "surfaceContainerHigh", "surfaceContainerHighest")
        ends = ("surfaceDim", "surfaceBright", "surfaceContainerLowest")
        for name in self.fixtures:
            for mode in ("dark", "light"):
                with self.subTest(fixture=name, mode=mode):
                    palette = self.generate(name, mode)
                    standard = build_palette(extract(self.fixtures[name]), mode)
                    source = lab(rgb(palette["sourceColor"]))
                    for role in panels:
                        # The standard Wallpaper scheme caps surfaces at 0.015 OKLab chroma.
                        self.assertGreater(oklab_chroma(palette[role]), 0.029, role)
                        self.assertGreater(oklab_chroma(palette[role]), 1.8 * oklab_chroma(standard[role]), role)
                    for role in panels + ends:
                        self.assertGreater(oklab_chroma(palette[role]), 0.01, role)
                        self.assertLess(hue_distance(lab(rgb(palette[role])), source), 20, role)

    def test_surface_ladder_is_ordered_and_distinct_in_each_mode(self):
        dark_order = ("surfaceContainerLowest", "surfaceDim", "background", "surfaceContainerLow",
                      "surface", "surfaceContainerHigh", "surfaceContainerHighest")
        light_order = ("surfaceContainerHighest", "surfaceDim", "surfaceContainerHigh", "surface",
                       "surfaceContainerLow", "background", "surfaceBright", "surfaceContainerLowest")
        for name in self.fixtures:
            for mode, order in (("dark", dark_order), ("light", light_order)):
                with self.subTest(fixture=name, mode=mode):
                    palette = self.generate(name, mode)
                    levels = [luminance(palette[role]) for role in order]
                    self.assertEqual(levels, sorted(levels))
                    self.assertEqual(len(set(levels)), len(levels))
                    # Panes and cards (surface) must stand apart from popups (background).
                    self.assertNotEqual(palette["background"], palette["surface"])
                    self.assertEqual(palette["surface"], palette["surfaceContainer"])
                    self.assertEqual(palette["surfaceTint"], palette["primary"])
                    if mode == "dark":
                        self.assertLess(luminance(palette["background"]), 0.05)
                        self.assertEqual(palette["shadow"], palette["background"])
                    else:
                        self.assertGreater(luminance(palette["background"]), 0.6)

    def test_text_and_accent_roles_meet_upstream_contrast(self):
        for name in self.fixtures:
            for mode in ("dark", "light"):
                with self.subTest(fixture=name, mode=mode):
                    palette = self.generate(name, mode)
                    for surface in ("background", "surface", "surfaceContainerHigh"):
                        self.assertGreaterEqual(contrast(rgb(palette["overSurface"]), rgb(palette[surface])), 4.5)
                        self.assertGreaterEqual(contrast(rgb(palette["overBackground"]), rgb(palette[surface])), 4.5)
                    self.assertGreaterEqual(contrast(rgb(palette["overSurfaceVariant"]),
                                                     rgb(palette["surfaceVariant"])), 4.5)
                    self.assertGreaterEqual(contrast(rgb(palette["outline"]), rgb(palette["background"])), 3.0)
                    for role in self.ACCENTS:
                        title = role[0].upper() + role[1:]
                        for suffix in ("", "Container"):
                            self.assertGreaterEqual(contrast(rgb(palette[role + suffix]),
                                                             rgb(palette["over" + title + suffix])), 4.5,
                                                    role + suffix)
                    for role in ("primary", "secondary", "tertiary"):
                        title = role[0].upper() + role[1:]
                        self.assertGreaterEqual(contrast(rgb(palette[role + "Fixed"]),
                                                         rgb(palette["over" + title + "Fixed"])), 4.5)
                        self.assertGreaterEqual(contrast(rgb(palette[role + "FixedDim"]),
                                                         rgb(palette["over" + title + "FixedVariant"])), 4.5)
                    # Legacy slots double as terminal colors drawn on the background.
                    for role in self.TERMINAL:
                        title = role[0].upper() + role[1:]
                        for value in (palette[role], palette["light" + title]):
                            self.assertGreaterEqual(contrast(rgb(value), rgb(palette["background"])), 4.5, role)

    def test_mode_moves_accents_to_the_readable_side(self):
        for name in self.fixtures:
            with self.subTest(fixture=name):
                dark, light = self.generate(name, "dark"), self.generate(name, "light")
                for role in ("primary", "secondary", "tertiary"):
                    self.assertGreater(luminance(dark[role]), luminance(light[role]), role)
                    self.assertLess(luminance(dark[role + "Container"]), luminance(dark[role]), role)
                    self.assertGreater(luminance(light[role + "Container"]), luminance(light[role]), role)
                for role in self.TERMINAL:
                    title = role[0].upper() + role[1:]
                    # Bright terminal colors move away from the background.
                    self.assertGreater(luminance(dark["light" + title]), luminance(dark[role]), role)
                    self.assertLess(luminance(light["light" + title]), luminance(light[role]), role)

    def test_terminal_slots_are_distinct_colors(self):
        for name in self.fixtures:
            for mode in ("dark", "light"):
                with self.subTest(fixture=name, mode=mode):
                    palette = self.generate(name, mode)
                    normals = [vibrant.Hct(tuple(rgb_bytes(palette[role]))) for role in self.TERMINAL]
                    for index, first in enumerate(normals):
                        for second in normals[index + 1:]:
                            self.assertGreater(vibrant.ucs_distance(first, second), 3.0)
                    accents = {palette[role] for role in ("primary", "secondary", "tertiary")}
                    self.assertEqual(len(accents), 3)

    def test_generator_publishes_complete_contract_for_both_modes(self):
        expected = set(json.loads((ROOT / "assets/matugen/colors.json").read_text()))
        output = self.root / "colors.json"
        for mode in ("dark", "light"):
            with self.subTest(mode=mode):
                result = subprocess.run(
                    ["bash", str(ROOT / "scripts/generate_wallpaper_colors.sh"), str(self.fixtures["stripes"]),
                     "scheme-noctalia-vibrant", mode, str(ROOT / "assets/matugen/config.toml"), str(output)],
                    env={**os.environ, "HOME": str(self.root)}, capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                palette = json.loads(output.read_text())
                self.assertEqual(set(palette), expected)
                self.assertEqual(palette, self.generate("stripes", mode))
                for value in palette.values():
                    self.assertRegex(value, r"^#[0-9a-f]{6}$")

    def test_transparent_pixels_do_not_supply_hidden_colors(self):
        image = Image.new("RGBA", (112, 112), (0, 255, 0, 0))
        ImageDraw.Draw(image).rectangle((0, 0, 111, 55), fill=(40, 90, 200, 255))
        path = self.root / "transparent.png"
        image.save(path)
        source = vibrant.Hct(tuple(rgb_bytes(vibrant.generate(path, "dark")["sourceColor"])))
        self.assertLess(abs(source.hue - vibrant.Hct((40, 90, 200)).hue), 10)
        empty = self.root / "empty.png"
        Image.new("RGBA", (20, 20), (255, 0, 0, 0)).save(empty)
        with self.assertRaises(ValueError):
            vibrant.generate(empty, "dark")

    @unittest.skipUnless(os.environ.get("NOCTALIA_PALETTE"), "set NOCTALIA_PALETTE to an upstream harness")
    def test_every_upstream_token_matches_native_harness(self):
        # The harness prints "<mode>\t<token>\t#rrggbb" from Noctalia's generateCustom(Vibrant).
        for name, path in self.fixtures.items():
            output = subprocess.run([os.environ["NOCTALIA_PALETTE"], str(path)],
                                    capture_output=True, text=True, check=True).stdout
            native: dict[str, dict[str, str]] = {"dark": {}, "light": {}}
            for line in output.splitlines():
                mode, token, value = line.split("\t")
                native[mode][token] = value
            seeds = vibrant.extract_palette(vibrant.load_samples(path))
            for mode in ("dark", "light"):
                with self.subTest(fixture=name, mode=mode):
                    tokens = vibrant.generate_tokens(seeds, mode == "dark")
                    for slot, (normal, bright) in vibrant.terminal_colors(tokens).items():
                        tokens["terminal_normal_" + slot] = normal
                        tokens["terminal_bright_" + slot] = bright
                    ours = {key: vibrant.hex_color(value) for key, value in tokens.items() if key in native[mode]}
                    self.assertGreater(len(ours), 60)
                    self.assertEqual(ours, {key: native[mode][key] for key in ours})


def rgb_bytes(value: str) -> list[int]:
    return [int(value[index:index + 2], 16) for index in (1, 3, 5)]



class PresetPaletteTests(unittest.TestCase):
    """Static presets publish the complete contract, keeping authored values."""

    def run_preset(self, *paths: str) -> subprocess.CompletedProcess:
        return subprocess.run(["python3", str(ROOT / "scripts/preset_palette.py"), *paths],
                              capture_output=True, text=True, timeout=30)

    def test_every_bundled_preset_publishes_the_complete_contract(self):
        expected = set(json.loads((ROOT / "assets/matugen/colors.json").read_text()))
        presets = sorted((ROOT / "assets/colors").glob("*/*.json"))
        self.assertTrue(presets)
        for preset in presets:
            with self.subTest(preset=str(preset.relative_to(ROOT))):
                result = self.run_preset(str(preset), "")
                self.assertEqual(result.returncode, 0, result.stderr)
                palette = json.loads(result.stdout)
                self.assertEqual(set(palette), expected)
                authored = json.loads(preset.read_text())
                self.assertEqual(palette["danger"], authored.get("danger", authored["error"]))
                self.assertEqual(palette["warning"], authored.get("warning", authored["yellow"]))
                self.assertEqual(palette["success"], authored.get("success", authored["green"]))
                self.assertEqual({key: palette[key] for key in authored}, authored)

    def test_authored_status_roles_win_and_missing_preset_falls_back(self):
        with tempfile.TemporaryDirectory() as directory:
            fallback = Path(directory) / "user.json"
            fallback.write_text(json.dumps({"yellow": "#111111", "overYellow": "#222222",
                                            "green": "#333333", "overGreen": "#444444",
                                            "warning": "#abcdef"}))
            result = self.run_preset(str(Path(directory) / "missing.json"), str(fallback))
            self.assertEqual(result.returncode, 0, result.stderr)
            palette = json.loads(result.stdout)
            self.assertEqual(palette["warning"], "#abcdef")
            self.assertEqual(palette["overWarning"], "#222222")
            self.assertEqual(palette["success"], "#333333")
            failed = self.run_preset(str(Path(directory) / "missing.json"), "")
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn("error", json.loads(failed.stderr))


if __name__ == "__main__":
    unittest.main()
