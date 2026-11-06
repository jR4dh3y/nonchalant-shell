.pragma library

// Pure helpers for BluetoothService, kept free of QML so tests can run them
// under Node with fake bluetoothctl output.

// Parse the status command's output: power state, connected devices, paired
// devices and every device BlueZ knows, as four "---"-separated sections.
// BlueZ names devices that never advertised a name after their address
// (AA-BB-...). Those are beacons nobody can pick out, so they are dropped
// unless already paired.
function parseStatus(text) {
    const parts = String(text || "").split("---");
    const enabled = (parts[0] || "").trim() === "powered";
    const result = { enabled: enabled, connectedCount: 0, firstConnectedName: "", devices: [] };
    if (!enabled)
        return result;

    const deviceLines = section => (parts[section] || "").trim().split("\n")
        .map(line => line.trim())
        .filter(line => line.startsWith("Device "));

    const connected = new Set();
    for (const line of deviceLines(1)) {
        const fields = line.split(" ");
        if (fields.length < 2)
            continue;
        connected.add(fields[1]);
        if (!result.firstConnectedName)
            result.firstConnectedName = fields.slice(2).join(" ") || "Connected";
    }
    result.connectedCount = connected.size;

    const paired = new Set(deviceLines(2).map(line => line.split(" ")[1]));

    for (const line of deviceLines(3)) {
        const fields = line.split(" ");
        if (fields.length < 2)
            continue;
        const address = fields[1];
        const name = fields.slice(2).join(" ");
        const isPaired = paired.has(address);
        const unnamed = name === "" || name === address.replace(/:/g, "-");
        if (unnamed && !isPaired)
            continue;
        result.devices.push({
            address: address,
            name: unnamed ? "Unknown device" : name,
            connected: connected.has(address),
            paired: isPaired
        });
    }
    return result;
}

// Pair a discovered device, then trust it so it can reconnect alone, then
// connect. `run` takes an argv list and returns a promise; the chain stops at
// the first step that rejects and rejects with its error.
function pairSequence(run, address) {
    return run(["bluetoothctl", "pair", address])
        .then(() => run(["bluetoothctl", "trust", address]))
        .then(() => run(["bluetoothctl", "connect", address]));
}

// Order devices for the lists: paired before discovered, connected first
// within each group, then by name. Section headers rely on paired devices
// forming one leading block, so paired is the primary key.
function sortDevices(devices) {
    return Array.from(devices).sort((a, b) => {
        if (a.paired !== b.paired)
            return a.paired ? -1 : 1;
        if (a.connected !== b.connected)
            return a.connected ? -1 : 1;
        return (a.name || "").localeCompare(b.name || "");
    });
}
