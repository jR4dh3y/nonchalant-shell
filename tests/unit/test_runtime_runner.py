"""Check runtime-runner failure reporting without starting a compositor."""

import contextlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from tests.runtime import run_compositor as runner


class RuntimeRunnerTests(unittest.TestCase):
    def test_tray_icon_crop_converts_logical_coordinates_to_screenshot_pixels(self):
        from PIL import Image, ImageDraw

        with tempfile.TemporaryDirectory() as directory:
            for scale in (1, 1.2, 2):
                with self.subTest(scale=scale):
                    image = Image.new("RGB", (100, 100))
                    box = tuple(round(value * scale) for value in (20, 20, 40, 40))
                    ImageDraw.Draw(image).rectangle((box[0], box[1], box[2] - 1, box[3] - 1),
                                                   fill=(20, 100, 220))
                    path = Path(directory) / "tray.png"
                    image.save(path)
                    self.assertEqual(runner.tray_icon_pixels(path, (20, 20, 20, 20), scale),
                                     (box[2] - box[0]) * (box[3] - box[1]))

    def test_missing_executable_reports_cause(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = runner.private_environment(root)
            env["PATH"] = str(root / "empty-path")
            try:
                result = subprocess.run(
                    [sys.executable, str(Path(runner.__file__)), "--compositor", "niri",
                     "--inside-session", str(root)],
                    env=env, capture_output=True, text=True, timeout=5)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("FileNotFoundError", result.stderr)
                self.assertIn("weston", result.stderr)
                report = json.loads((root / "result.json").read_text())
                self.assertIn("FileNotFoundError", report["error"])
                self.assertIn("weston", report["error"])
            finally:
                shutil.rmtree(env["XDG_RUNTIME_DIR"])

    def test_private_runtime_is_removed_when_artifact_copy_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = runner.private_environment(root)
            argv = ["run_compositor.py", "--compositor", "niri", "--artifacts", str(root)]
            with patch.object(sys, "argv", argv), \
                    patch.object(runner, "private_environment", return_value=env), \
                    patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)), \
                    patch.object(runner.shutil, "copytree", side_effect=OSError("copy failed")):
                with self.assertRaisesRegex(OSError, "copy failed"):
                    runner.main()
            self.assertFalse(Path(env["XDG_RUNTIME_DIR"]).exists())

    def run_fixture(self, root, exercise):
        argv = ["run_compositor.py", "--compositor", "niri", "--inside-session", str(root)]
        with patch.object(sys, "argv", argv), \
                patch.object(runner, "start_compositor"), \
                patch.object(runner.Session, "run", return_value="test version"), \
                patch.object(runner, "exercise", side_effect=exercise), \
                contextlib.redirect_stdout(io.StringIO()):
            return runner.main()

    def test_unexpected_exceptions_and_interrupts_are_recorded_and_propagated(self):
        for error in (KeyError("missing state"), StopIteration(), KeyboardInterrupt()):
            with self.subTest(error=type(error).__name__), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                with self.assertRaises(type(error)):
                    self.run_fixture(root, error)
                report = json.loads((root / "result.json").read_text())
                self.assertIn(type(error).__name__, report["error"])

    def test_qml_errors_fail_but_missing_optional_tools_do_not(self):
        for log, expected in (("ERROR: qs: broken component\n", 1),
                              ("Process failed to start: optional helper\n", 0)):
            with self.subTest(log=log), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)

                def exercise(*args):
                    (root / "shell.log").write_text(log)

                self.assertEqual(self.run_fixture(root, exercise), expected)
                report = json.loads((root / "result.json").read_text())
                self.assertEqual("error" in report, expected != 0)


if __name__ == "__main__":
    unittest.main()
