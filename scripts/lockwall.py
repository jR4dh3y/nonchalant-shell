#!/usr/bin/env python3
"""
Lockscreen Wallpaper Frame Extractor for Nonchalant
Extracts a cached still for video, GIF, WebP and AVIF wallpapers.
"""

import hashlib
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional, Tuple

# Supported extensions for processing
VIDEO_EXTENSIONS = {".mp4", ".webm", ".mov", ".avi", ".mkv"}
GIF_EXTENSIONS = {".gif"}
WEB_IMAGE_EXTENSIONS = {".webp", ".avif"}


class LockscreenWallpaperGenerator:
    def __init__(self, wallpaper_path: str, data_path: str):
        self.current_wallpaper = Path(wallpaper_path).expanduser()
        self.data_path = Path(data_path)
        self.lockscreen_dir: Optional[Path] = None

    def validate_wallpaper(self) -> bool:
        """Validate wallpaper exists."""
        if not self.current_wallpaper.exists():
            print(f"ERROR: Wallpaper not found: {self.current_wallpaper}")
            return False

        # Setup lockscreen directory in QuickShell data path
        self.lockscreen_dir = self.data_path / "lockscreen"
        self.lockscreen_dir.mkdir(parents=True, exist_ok=True)

        print(f"✓ Current wallpaper: {self.current_wallpaper.name}")
        print(f"✓ Lockscreen cache: {self.lockscreen_dir}")
        return True

    def needs_frame(self) -> bool:
        ext = self.current_wallpaper.suffix.lower()
        return ext in VIDEO_EXTENSIONS | GIF_EXTENSIONS | WEB_IMAGE_EXTENSIONS

    def get_output_path(self) -> Path:
        """Get output path for lockscreen wallpaper."""
        if self.lockscreen_dir is None:
            raise RuntimeError("Lockscreen directory not initialized")

        output_name = hashlib.md5(os.fsencode(self.current_wallpaper), usedforsecurity=False).hexdigest() + ".jpg"
        return self.lockscreen_dir / output_name

    def extract_first_frame(self) -> Tuple[bool, str]:
        """Decode a still that the shell can load as a JPEG."""
        output_path = self.get_output_path()

        try:
            if self.current_wallpaper.suffix.lower() in WEB_IMAGE_EXTENSIONS | GIF_EXTENSIONS:
                from PIL import Image, ImageOps

                with tempfile.TemporaryDirectory(dir=output_path.parent) as directory:
                    staged = Path(directory) / "frame.jpg"
                    with Image.open(self.current_wallpaper) as image:
                        ImageOps.exif_transpose(image).convert("RGB").save(staged, quality=95)
                    staged.replace(output_path)
                return True, "Success"

            with tempfile.TemporaryDirectory(dir=output_path.parent) as directory:
                staged = Path(directory) / "frame.jpg"
                result = subprocess.run(
                    ["ffmpeg", "-nostdin", "-v", "error", "-i", str(self.current_wallpaper),
                     "-frames:v", "1", "-q:v", "2", str(staged)],
                    capture_output=True, text=True, timeout=30)
                if result.returncode != 0 or not staged.exists():
                    return False, result.stderr.strip() or "No drawable video frame"
                staged.replace(output_path)
            return True, "Success"

        except subprocess.TimeoutExpired:
            return False, "Timeout"
        except Exception as e:
            return False, str(e)

    def run(self) -> int:
        """Main execution function."""
        print("🔒 Nonchalant Lockscreen Wallpaper Generator")
        print("=" * 40)

        # Validate wallpaper
        if not self.validate_wallpaper():
            return 1

        if not self.needs_frame():
            ext = self.current_wallpaper.suffix.lower()
            print(f"ℹ️  Wallpaper is a regular image ({ext})")
            print("ℹ️  No processing needed - use wallpaper directly")
            return 0

        # Other screens may still use any previously generated frame.
        # Extract first frame
        success, message = self.extract_first_frame()

        if success:
            print("🎉 Lockscreen wallpaper ready!")
            return 0
        else:
            print(f"❌ Failed to extract frame: {message}")
            return 1


def main():
    """Entry point."""
    if len(sys.argv) != 3:
        print("Usage: python3 lockscreen_wallpaper.py <wallpaper_path> <data_path>")
        print(
            "Example: python3 lockscreen_wallpaper.py /path/to/video.mp4 ~/.local/share/quickshell"
        )
        return 1

    wallpaper_path = sys.argv[1]
    data_path = sys.argv[2]
    generator = LockscreenWallpaperGenerator(wallpaper_path, data_path)
    return generator.run()


if __name__ == "__main__":
    sys.exit(main())
