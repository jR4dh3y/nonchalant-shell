const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");

const codec = vm.createContext({});
const source = fs.readFileSync(path.join(__dirname, "../../modules/services/compositor/HyprlandCodec.js"), "utf8");
vm.runInContext(source.replace(/^\.pragma library\s*/, ""), codec);
const plain = value => JSON.parse(JSON.stringify(value));

function fixture() {
    const monitor = {
        name: "HEADLESS-1", width: 2560, height: 1440, scale: 2,
        x: 1280, y: -100, focused: true,
        lastIpcObject: { refreshRate: 60, transform: 0, specialWorkspace: { name: "" } }
    };
    const workspace = {
        address: "7", id: 7, name: "7", active: true, focused: true,
        urgent: false, monitor, lastIpcObject: { lastwindow: "0xabc" }
    };
    monitor.activeWorkspace = workspace;
    const window = {
        address: "abc", title: "Test window", activated: true, urgent: false,
        workspace, monitor,
        lastIpcObject: { class: "test", pid: 42001, at: [1300, -80], size: [640, 480], floating: true, fullscreen: 0 }
    };
    return { monitor, workspace, window };
}

test("addresses remain opaque hexadecimal strings, including values outside JS integer precision", () => {
    assert.equal(codec.windowId("ABCDEF1234567890"), "0xabcdef1234567890");
    assert.equal(codec.windowId("0x000abc"), "0xabc");
    assert.throws(() => codec.windowId("0x0"), /Unaddressed/);
    assert.throws(() => codec.windowId("abc,activewindow"), /Invalid/);
});

test("mixed-scale geometry converts global logical positions into output-local logical coordinates", () => {
    const { monitor, workspace, window } = fixture();
    const state = codec.normalize([monitor], [workspace], [window]);
    assert.equal(state.outputs[0].width, 1280);
    assert.equal(state.outputs[0].height, 720);
    assert.deepEqual(plain(state.windows[0].geometry), [20, 20, 640, 480]);
    assert.equal(state.windows[0].geometryKnown, true);
    assert.equal(state.windows[0].pid, 42001);
    assert.equal(state.workspaces[0].activeWindowId, "0xabc");
    assert.equal(state.workspaces[0].windows, 1);
});

test("authoritative monitor snapshots retain focus when native binding was never initialized", () => {
    const { monitor, workspace } = fixture();
    monitor.focused = false;
    monitor.lastIpcObject.focused = true;
    assert.equal(codec.normalize([monitor], [workspace], []).outputs[0].focused, true);
    monitor.focused = true;
    monitor.lastIpcObject.focused = false;
    assert.equal(codec.normalize([monitor], [workspace], []).outputs[0].focused, false);
});

test("initial native focus absence falls back to the most recent client on the focused active workspace", () => {
    const { monitor, workspace, window } = fixture();
    window.activated = false;
    window.lastIpcObject.focusHistoryID = 0;
    assert.equal(codec.normalize([monitor], [workspace], [window]).windows[0].is_focused, true);
    workspace.active = false;
    assert.equal(codec.normalize([monitor], [workspace], [window]).windows[0].is_focused, false);
    workspace.active = true;
    workspace.focused = false;
    assert.equal(codec.normalize([monitor], [workspace], [window]).windows[0].is_focused, false);
    workspace.focused = true;
    monitor.lastIpcObject.focused = false;
    assert.equal(codec.normalize([monitor], [workspace], [window]).windows[0].is_focused, false);
});

test("native activation wins over focus history and publishes at most one focused window", () => {
    const { monitor, workspace, window } = fixture();
    const recent = { ...window, address: "def", activated: false, lastIpcObject: { ...window.lastIpcObject, focusHistoryID: 0 } };
    let state = codec.normalize([monitor], [workspace], [window, recent]);
    assert.deepEqual(plain(state.windows.filter(value => value.is_focused).map(value => value.id)), ["0xabc"]);
    recent.activated = true;
    state = codec.normalize([monitor], [workspace], [window, recent]);
    assert.equal(state.windows.filter(value => value.is_focused).length, 1);
});

test("rotated monitor dimensions apply transform before scale", () => {
    const { monitor, workspace } = fixture();
    monitor.lastIpcObject.transform = 1;
    const output = codec.normalize([monitor], [workspace], []).outputs[0];
    assert.equal(output.width, 720);
    assert.equal(output.height, 1280);
});

test("native QVariantList geometry accepts QML sequence values rather than requiring JavaScript arrays", () => {
    const { monitor, workspace, window } = fixture();
    window.lastIpcObject.at = { 0: 1300, 1: -80, length: 2 };
    window.lastIpcObject.size = { 0: 640, 1: 480, length: 2 };
    const normalized = codec.normalize([monitor], [workspace], [window]).windows[0];
    assert.equal(normalized.geometryKnown, true);
    assert.deepEqual(plain(normalized.geometry), [20, 20, 640, 480]);
});

test("missing or malformed window geometry remains unknown rather than hiding the bar at zero", () => {
    const { monitor, workspace, window } = fixture();
    window.lastIpcObject.at = [NaN, 0];
    const normalized = codec.normalize([monitor], [workspace], [window]).windows[0];
    assert.equal(normalized.geometryKnown, false);
    assert.deepEqual(plain(normalized.geometry), [0, 0, 0, 0]);
    assert.equal(normalized.tiledAtTop, false);
});

test("fullscreen uses compositor state and only visible workspaces", () => {
    const { monitor, workspace, window } = fixture();
    window.lastIpcObject.fullscreen = 1;
    window.lastIpcObject.fullscreenClient = 2;
    assert.deepEqual(plain(codec.normalize([monitor], [workspace], [window]).fullscreenOutputs), []);
    window.lastIpcObject.fullscreen = 2;
    assert.deepEqual(plain(codec.normalize([monitor], [workspace], [window]).fullscreenOutputs), [monitor.name]);
    workspace.active = false;
    assert.deepEqual(plain(codec.normalize([monitor], [workspace], [window]).fullscreenOutputs), []);
    workspace.active = true;
    window.lastIpcObject.hidden = true;
    assert.deepEqual(plain(codec.normalize([monitor], [workspace], [window]).fullscreenOutputs), []);
});

test("unaddressed windows and uninitialized outputs are excluded", () => {
    const { monitor, workspace, window } = fixture();
    window.address = "0";
    monitor.width = 0;
    const state = codec.normalize([monitor], [workspace], [window]);
    assert.equal(state.windows.length, 0);
    assert.equal(state.outputs.length, 0);
});

test("scrolling layout fullscreen columns hide shell chrome only when they cover the output", () => {
    const { monitor, workspace, window } = fixture();
    window.lastIpcObject.fullscreen = 2;
    window.lastIpcObject.fullscreenHandler = "scrolling";
    assert.deepEqual(plain(codec.normalize([monitor], [workspace], [window]).fullscreenOutputs), []);
    window.lastIpcObject.at = [monitor.x, monitor.y];
    window.lastIpcObject.size = [1280, 720];
    assert.deepEqual(plain(codec.normalize([monitor], [workspace], [window]).fullscreenOutputs), [monitor.name]);
});

test("visible special workspaces retain windows and fullscreen without joining ordinary navigation", () => {
    const { monitor, workspace, window } = fixture();
    const special = { ...workspace, address: "-99", id: -99, name: "special:scratch", active: false, focused: false };
    monitor.lastIpcObject.specialWorkspace.name = special.name;
    window.workspace = special;
    window.lastIpcObject.fullscreen = 2;
    const state = codec.normalize([monitor], [workspace, special], [window]);
    const normalizedSpecial = state.workspaces.find(value => value.special);
    assert.equal(normalizedSpecial.active, true);
    assert.equal(normalizedSpecial.focused, true);
    assert.equal(normalizedSpecial.windows, 1);
    assert.deepEqual(plain(state.fullscreenOutputs), [monitor.name]);
    assert.throws(() => codec.focusWorkspace(normalizedSpecial, true), /Special/);
});

test("named workspace identities use addresses rather than display names or numeric compatibility ids", () => {
    const { monitor, workspace } = fixture();
    workspace.address = "ws:deadbeef";
    workspace.id = -1337;
    workspace.name = "Design";
    const normalized = codec.normalize([monitor], [workspace], []).workspaces[0];
    assert.equal(normalized.id, "ws:deadbeef");
    assert.equal(normalized.isNamed, true);
    assert.equal(normalized.special, false);
    assert.equal(codec.focusWorkspace(normalized), 'hl.dsp.focus({ workspace = "ws:deadbeef" })');
    workspace.id = 1;
    assert.equal(codec.normalize([monitor], [workspace], []).workspaces[0].isNamed, true);
});

test("numbered workspaces focus by address and label by their numeric display name", () => {
    const { monitor, workspace } = fixture();
    workspace.address = "11";
    workspace.id = 11;
    workspace.name = "1";
    const normalized = codec.normalize([monitor], [workspace], []).workspaces[0];
    assert.equal(normalized.idx, 1);
    assert.equal(normalized.isNamed, false);
    assert.equal(codec.focusWorkspace(normalized), 'hl.dsp.focus({ workspace = "11" })');
});

test("targeted close never requires a focus command or defaults to the active window", () => {
    assert.equal(codec.closeWindow("0xabc"), 'hl.dsp.window.close({ window = "address:0xabc" })');
    assert.throws(() => codec.closeWindow(""), /Invalid/);
});

test("workspace moves preserve the explicit follow policy", () => {
    const workspace = { id: "1", idx: 1, name: "Web", isNamed: true, special: false };
    assert.equal(codec.moveWindowToWorkspace("abc", workspace, false), 'hl.dsp.window.move({ window = "address:0xabc", workspace = "1", follow = false })');
    assert.equal(codec.moveWindowToWorkspace("abc", workspace, true), 'hl.dsp.window.move({ window = "address:0xabc", workspace = "1", follow = true })');
});

test("logout and monitor power use the Lua dispatchers", () => {
    assert.equal(codec.logoutCommand(), "hl.dsp.exit()");
    assert.equal(codec.powerCommand(true), 'hl.dsp.dpms({ action = "enable" })');
    assert.equal(codec.powerCommand(false), 'hl.dsp.dpms({ action = "disable" })');
});

test("Lua quoting handles quotes, slashes, control characters, and Unicode without code injection", () => {
    assert.equal(codec.luaString('A"\\\n雪'), '"A\\"\\\\\\010雪"');
    const workspace = { id: 'a\",follow=true})', idx: -1, name: "x", isNamed: true, special: false };
    assert.match(codec.focusWorkspace(workspace), /workspace = "a\\",follow=true\}\)"/);
});

test("adjacent navigation stays on the output, excludes special workspaces, and stops at boundaries", () => {
    const workspaces = [
        { id: "3", idx: 3, name: "3", output: "A", active: false, special: false },
        { id: "1", idx: 1, name: "1", output: "A", active: true, special: false },
        { id: "2", idx: 2, name: "2", output: "B", active: true, special: false },
        { id: "s", idx: -99, name: "special:s", output: "A", active: true, special: true }
    ];
    assert.equal(codec.adjacentWorkspace(workspaces, "A", 1).id, "3");
    assert.equal(codec.adjacentWorkspace(workspaces, "A", -1), null);
    assert.equal(codec.adjacentWorkspace(workspaces, "missing", 1), null);
    assert.throws(() => codec.adjacentWorkspace(workspaces, "A", 0), /direction/);
});

test("windows follow layout position rather than map order so reordering columns reorders the list", () => {
    const { monitor, workspace } = fixture();
    const make = (address, at, floating = false) => ({
        address, title: address, activated: false, urgent: false, workspace, monitor,
        lastIpcObject: { class: address, pid: 1, at, size: [400, 400], floating, fullscreen: 0 }
    });
    // Map order a, b, c, f; layout order is c, a, b with a floating window last.
    const toplevels = [make("a", [1700, -80]), make("b", [2200, -80]), make("c", [1300, -80]), make("f", [1290, -90], true)];
    const order = () => codec.normalize([monitor], [workspace], toplevels).windows.map(window => window.id);
    assert.deepEqual(order(), ["0xc", "0xa", "0xb", "0xf"]);
    // Stacked tiles in one column order top to bottom.
    toplevels[1].lastIpcObject.at = [1700, 400];
    assert.deepEqual(order(), ["0xc", "0xa", "0xb", "0xf"]);
});
