"""Exercise app discovery and search across real desktop-file changes."""

import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import tempfile
import time
import unittest


SOURCE = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which("qs") and shutil.which("dbus-run-session"),
                     "requires Quickshell and dbus-run-session")
class AppSearchRuntimeTests(unittest.TestCase):
    def test_install_update_and_remove(self):
        with tempfile.TemporaryDirectory(prefix="appsearch-runtime-") as directory:
            root = Path(directory)
            services = root / "modules/services"
            services.mkdir(parents=True)
            shutil.copy2(SOURCE / "modules/services/AppSearch.qml", services)
            (services / "UsageTracker.qml").write_text(
                "pragma Singleton\nimport Quickshell\n"
                "Singleton { signal usageChanged(); signal usageDataReady();\n"
                "    function getUsageScore(id) { return 0; } }\n"
            )
            apps = root / "data/applications"
            apps.mkdir(parents=True)
            desktop = apps / "appimage-refresh-fixture.desktop"
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import qs.modules.services
ShellRoot {
    readonly property int count: AppSearch.list.length
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            const apps = AppSearch.getAllApps()
                .filter(a => a.id === "appimage-refresh-fixture");
            const matches = AppSearch.fuzzyQuery("AppImageAfter")
                .filter(a => a.id === "appimage-refresh-fixture");
            console.log("RESULT " + JSON.stringify({
                apps: apps.map(a => a.name), matches: matches.map(a => a.name)
            }));
        }
    }
}''')
            runtime = root / "runtime"
            runtime.mkdir(mode=0o700)
            env = {**os.environ, "XDG_RUNTIME_DIR": str(runtime),
                   "XDG_DATA_HOME": str(root / "data"),
                   "XDG_CONFIG_HOME": str(root / "config"),
                   "XDG_CACHE_HOME": str(root / "cache"),
                   "QT_QPA_PLATFORM": "offscreen", "QT_QPA_PLATFORMTHEME": "",
                   "QT_QUICK_BACKEND": "software"}
            env.pop("WAYLAND_DISPLAY", None)
            env.pop("DISPLAY", None)
            process = subprocess.Popen(
                ["dbus-run-session", "--", "qs", "-p", str(root), "--no-color"],
                env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            output = ""
            pending = ""
            selector = selectors.DefaultSelector()
            selector.register(process.stdout, selectors.EVENT_READ)

            def wait_for(names, matches):
                nonlocal output, pending
                deadline = time.monotonic() + 10
                while time.monotonic() < deadline:
                    for key, _ in selector.select(timeout=0.2):
                        chunk = os.read(key.fileobj.fileno(), 65536).decode()
                        if not chunk:
                            self.fail("Quickshell exited:\n" + output)
                        output += chunk
                        pending += chunk
                        while "\n" in pending:
                            line, pending = pending.split("\n", 1)
                            if "RESULT " in line:
                                result = json.loads(line.split("RESULT ", 1)[1])
                                if result == {"apps": names, "matches": matches}:
                                    return
                self.fail("App index did not refresh:\n" + output)

            def install(name):
                # Package managers and AppImage integrators write a temporary
                # file and rename it over the entry. Quickshell watches the
                # directory, which reports renames but not in-place edits.
                staged = apps / ".appimage-refresh-fixture.desktop.tmp"
                staged.write_text("[Desktop Entry]\nType=Application\nName="
                                  + name + "\nExec=/bin/true\nIcon=image-missing\n")
                os.replace(staged, desktop)

            try:
                wait_for([], [])
                install("AppImageBefore")
                wait_for(["AppImageBefore"], [])
                install("AppImageAfter")
                wait_for(["AppImageAfter"], ["AppImageAfter"])
                desktop.unlink()
                wait_for([], [])
            finally:
                selector.close()
                process.terminate()
                process.wait(timeout=5)
                process.stdout.close()


if __name__ == "__main__":
    unittest.main()
