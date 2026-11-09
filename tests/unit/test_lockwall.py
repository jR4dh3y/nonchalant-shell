"""Frame generation must preserve other screens' cached backgrounds."""
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
            for name, color in (("A", "red"), ("B", "blue")):
                source = home / (name + ".mp4")
                subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i",
                                f"color={color}:s=32x32:d=0.1", str(source)], check=True,
                               capture_output=True, timeout=20)
            def generate(name):
                result = subprocess.run(["python3", str(ROOT / "scripts/lockwall.py"),
                                         str(home / (name + ".mp4")), str(cache)],
                                        capture_output=True, text=True, timeout=40)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            generate("A")
            frame_a = cache / "lockscreen/A.mp4.jpg"
            original = frame_a.read_bytes()
            generate("B")
            self.assertEqual(frame_a.read_bytes(), original)
            frame_b = cache / "lockscreen/B.mp4.jpg"
            other = frame_b.read_bytes()
            generate("A")
            self.assertEqual(frame_b.read_bytes(), other)
            self.assertEqual(frame_a.read_bytes(), original)
