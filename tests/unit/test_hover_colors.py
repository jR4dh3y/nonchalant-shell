"""Check hover color pairing and repair of the old persisted theme default."""

import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = r'''
const fs = require("fs");
const vm = require("vm");
const root = process.argv[1];
function load(path) {
    const scope = {};
    vm.createContext(scope);
    vm.runInContext(fs.readFileSync(root + path, "utf8").replace(/\.pragma\s+library;?/g, ""), scope);
    return scope;
}
const defaults = load("/config/defaults/theme.js").data;
const validator = load("/config/ConfigValidator.js");
const old = JSON.parse(JSON.stringify(defaults));
old.srPrimaryFocus.itemColor = "overPrimary";
const repaired = validator.validate(old, defaults);
const custom = JSON.parse(JSON.stringify(old));
custom.srPrimaryFocus.itemColor = "overBackground";
const customBackground = JSON.parse(JSON.stringify(old));
customBackground.srPrimaryFocus.gradient = [["primary", 0]];
console.log(JSON.stringify({
    defaults,
    repaired,
    repeated: validator.validate(repaired, defaults),
    custom: validator.validate(custom, defaults),
    customBackground: validator.validate(customBackground, defaults),
}));
'''


@unittest.skipUnless(shutil.which("node"), "Node.js is required to exercise the QML validator")
class HoverColorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result = subprocess.run(["node", "-e", SCRIPT, str(ROOT)], capture_output=True,
                                text=True, check=True)
        cls.themes = json.loads(result.stdout)

    def test_default_pairs_hover_background_with_its_foreground(self):
        focus = self.themes["defaults"]["srPrimaryFocus"]
        self.assertEqual(focus["gradient"], [["overPrimaryContainer", 0]])
        self.assertEqual(focus["itemColor"], "primaryContainer")

    def test_repairs_existing_default_and_is_idempotent(self):
        self.assertEqual(self.themes["repaired"]["srPrimaryFocus"]["itemColor"], "primaryContainer")
        self.assertEqual(self.themes["repaired"], self.themes["repeated"])

    def test_preserves_custom_foreground_and_background(self):
        self.assertEqual(self.themes["custom"]["srPrimaryFocus"]["itemColor"], "overBackground")
        focus = self.themes["customBackground"]["srPrimaryFocus"]
        self.assertEqual(focus["gradient"], [["primary", 0]])
        self.assertEqual(focus["itemColor"], "overPrimary")


if __name__ == "__main__":
    unittest.main()
