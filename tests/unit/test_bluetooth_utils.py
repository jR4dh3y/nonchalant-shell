"""Behavior tests for Bluetooth status parsing, list order and pairing.

Runs modules/services/bluetooth_utils.js under Node with fake bluetoothctl
output and a fake command runner, so no Bluetooth hardware is needed.
"""

import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]

SCRIPT = r'''
const fs = require("fs");
const vm = require("vm");
const scope = {};
vm.createContext(scope);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8").replace(/\.pragma\s+library;?/g, ""), scope);
const bt = scope;

const status = [
    "powered",
    "---",
    "Device AA:AA:AA:AA:AA:01 Headphones",
    "---",
    "Device AA:AA:AA:AA:AA:01 Headphones",
    "Device AA:AA:AA:AA:AA:02 Keyboard",
    "Device AA:AA:AA:AA:AA:05 AA-AA-AA-AA-AA-05",
    "---",
    "Device AA:AA:AA:AA:AA:01 Headphones",
    "Device AA:AA:AA:AA:AA:02 Keyboard",
    "Device AA:AA:AA:AA:AA:03 Magic Mouse",
    "Device AA:AA:AA:AA:AA:04 AA-AA-AA-AA-AA-04",
    "Device AA:AA:AA:AA:AA:05 AA-AA-AA-AA-AA-05",
].join("\n");

// Fake bluetoothctl: records each argv, rejects the step named in `failAt`.
function runner(failAt) {
    const calls = [];
    const run = argv => {
        calls.push(argv.slice(1).join(" "));
        return argv[1] === failAt ? Promise.reject("Failed to " + failAt + ": org.bluez.Error.AuthenticationFailed")
                                  : Promise.resolve("");
    };
    return { calls, run };
}

async function pair(failAt) {
    const fake = runner(failAt);
    let error = null;
    try {
        await bt.pairSequence(fake.run, "AA:AA:AA:AA:AA:03");
    } catch (e) {
        error = String(e);
    }
    return { calls: fake.calls, error };
}

(async () => {
    const parsed = bt.parseStatus(status);
    const sorted = bt.sortDevices([
        { name: "Zed", paired: false, connected: false },
        { name: "Beta", paired: true, connected: false },
        { name: "Odd", paired: false, connected: true },
        { name: "Alpha", paired: true, connected: true },
        { name: "Ace", paired: false, connected: false },
    ]).map(d => d.name);
    console.log(JSON.stringify({
        off: bt.parseStatus("off\n---\n---\n---\nDevice AA:AA:AA:AA:AA:01 Headphones"),
        empty: bt.parseStatus(""),
        parsed,
        sorted,
        success: await pair(null),
        pairFails: await pair("pair"),
        trustFails: await pair("trust"),
        connectFails: await pair("connect"),
    }));
})();
'''


@unittest.skipIf(shutil.which("node") is None, "node is required")
class BluetoothUtilsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        out = subprocess.run(
            ["node", "-e", SCRIPT, str(ROOT / "modules/services/bluetooth_utils.js")],
            check=True, capture_output=True, text=True,
        ).stdout
        cls.r = json.loads(out)

    def device(self, address):
        return next(d for d in self.r["parsed"]["devices"] if d["address"] == address)

    def test_powered_off_reports_no_devices(self):
        for key in ("off", "empty"):
            self.assertFalse(self.r[key]["enabled"], key)
            self.assertEqual(self.r[key]["devices"], [], key)
            self.assertEqual(self.r[key]["connectedCount"], 0, key)

    def test_paired_state_comes_from_paired_section(self):
        self.assertTrue(self.device("AA:AA:AA:AA:AA:01")["paired"])
        self.assertTrue(self.device("AA:AA:AA:AA:AA:02")["paired"])
        # Known to BlueZ through discovery, but not paired.
        self.assertFalse(self.device("AA:AA:AA:AA:AA:03")["paired"])

    def test_connected_devices(self):
        parsed = self.r["parsed"]
        self.assertEqual(parsed["connectedCount"], 1)
        self.assertEqual(parsed["firstConnectedName"], "Headphones")
        self.assertTrue(self.device("AA:AA:AA:AA:AA:01")["connected"])
        self.assertFalse(self.device("AA:AA:AA:AA:AA:02")["connected"])

    def test_unnamed_devices_hidden_until_paired(self):
        addresses = [d["address"] for d in self.r["parsed"]["devices"]]
        self.assertNotIn("AA:AA:AA:AA:AA:04", addresses)
        self.assertEqual(self.device("AA:AA:AA:AA:AA:05")["name"], "Unknown device")

    def test_paired_devices_form_one_leading_section(self):
        # A connected-but-unpaired device must not split the paired block.
        self.assertEqual(self.r["sorted"], ["Alpha", "Beta", "Odd", "Ace", "Zed"])

    def test_pairing_runs_pair_trust_connect_in_order(self):
        self.assertEqual(self.r["success"]["calls"],
                         ["pair AA:AA:AA:AA:AA:03", "trust AA:AA:AA:AA:AA:03", "connect AA:AA:AA:AA:AA:03"])
        self.assertIsNone(self.r["success"]["error"])

    def test_failed_step_stops_the_chain_and_surfaces_its_error(self):
        self.assertEqual(self.r["pairFails"]["calls"], ["pair AA:AA:AA:AA:AA:03"])
        self.assertIn("Failed to pair", self.r["pairFails"]["error"])
        self.assertEqual(self.r["trustFails"]["calls"], ["pair AA:AA:AA:AA:AA:03", "trust AA:AA:AA:AA:AA:03"])
        self.assertIn("Failed to trust", self.r["trustFails"]["error"])
        self.assertEqual(len(self.r["connectFails"]["calls"]), 3)
        self.assertIn("Failed to connect", self.r["connectFails"]["error"])


if __name__ == "__main__":
    unittest.main()
