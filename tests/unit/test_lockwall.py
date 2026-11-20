"""Frame generation must preserve other screens' cached backgrounds."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg required")
class LockwallTests(unittest.TestCase):
    def test_two_screens_and_regeneration(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cache = home / "cache"
            sources = [home / name / "same.mp4" for name in ("A", "B")]
            for source, color in zip(sources, ("red", "blue")):
                source.parent.mkdir()
                subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i",
                                f"color={color}:s=32x32:d=0.1", str(source)], check=True,
                               capture_output=True, timeout=20)
            def generate(source):
                result = subprocess.run(["python3", str(ROOT / "scripts/lockwall.py"),
                                         str(source), str(cache)],
                                        capture_output=True, text=True, timeout=40)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            def frame(source):
                return cache / "lockscreen" / (hashlib.md5(os.fsencode(source), usedforsecurity=False).hexdigest() + ".jpg")

            generate(sources[0])
            frame_a = frame(sources[0])
            original = frame_a.read_bytes()
            generate(sources[1])
            self.assertEqual(frame_a.read_bytes(), original)
            frame_b = frame(sources[1])
            other = frame_b.read_bytes()
            generate(sources[0])
            self.assertEqual(frame_b.read_bytes(), other)
            self.assertEqual(frame_a.read_bytes(), original)
