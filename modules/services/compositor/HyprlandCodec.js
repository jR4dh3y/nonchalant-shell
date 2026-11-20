.pragma library

function windowId(address) {
    if (typeof address !== "string" || !/^(0x)?[0-9a-f]+$/i.test(address))
        throw new Error("Invalid Hyprland window address");
    const hex = address.replace(/^0x/i, "").replace(/^0+/, "").toLowerCase();
    if (!hex)
        throw new Error("Unaddressed Hyprland window");
    return "0x" + hex;
}

function workspaceId(workspace) {
    return typeof workspace?.address === "string" ? workspace.address : "";
}

function normalize(monitors, workspaces, toplevels) {
    const outputs = monitors.filter(monitor => monitor.name && monitor.width > 0 && monitor.height > 0 && monitor.scale > 0).map(monitor => {
        const raw = monitor.lastIpcObject || {};
        const rotated = [1, 3, 5, 7].indexOf(Number(raw.transform)) !== -1;
        return {
            id: monitor.name,
            name: monitor.name,
            width: (rotated ? monitor.height : monitor.width) / monitor.scale,
            height: (rotated ? monitor.width : monitor.height) / monitor.scale,
            x: Number(monitor.x || 0),
            y: Number(monitor.y || 0),
            scale: monitor.scale,
            refreshRate: Number(raw.refreshRate || 0),
            focused: (raw.focused ?? monitor.focused) === true,
            activeWorkspaceId: workspaceId(monitor.activeWorkspace)
        };
    });
    const workspaceValues = workspaces.filter(workspace => workspaceId(workspace) !== "").map(workspace => {
        const raw = workspace.lastIpcObject || {};
        const special = workspace.name === "special" || String(workspace.name).startsWith("special:");
        const specialMonitor = special ? monitors.find(monitor => {
            const active = monitor.lastIpcObject?.specialWorkspace;
            return active?.name === workspace.name;
        }) : null;
        return {
            id: workspaceId(workspace),
            // HDMI workspaces 11-19 are named "1"-"9"; show and order them by that.
            idx: /^[1-9][0-9]*$/.test(String(workspace.name)) && Number(workspace.id) > 0 ? Number(workspace.name) : Number(workspace.id),
            name: String(workspace.name || workspace.id),
            isNamed: special || Number(workspace.id) < 1 || !/^[1-9][0-9]*$/.test(String(workspace.name)),
            output: specialMonitor?.name || workspace.monitor?.name || "",
            active: special ? specialMonitor != null : workspace.active === true,
            focused: special ? outputs.some(output => output.name === specialMonitor?.name && output.focused) : workspace.focused === true,
            is_urgent: workspace.urgent === true,
            activeWindowId: raw.lastwindow && raw.lastwindow !== "0x0" ? windowId(raw.lastwindow) : "",
            windows: 0,
            special: special
        };
    }).sort((left, right) => left.idx - right.idx || left.name.localeCompare(right.name));

    const addressedWindows = toplevels.filter(window => typeof window.address === "string" && /^(0x)?[0-9a-f]+$/i.test(window.address) && !/^(0x)?0+$/i.test(window.address));
    const activatedWindow = addressedWindows.find(window => window.activated === true);
    // Quickshell initially leaves activeToplevel null until a focus event.
    // Use the most recently focused client on the focused active workspace
    // while no native activation is available, including shell layer grabs.
    const rememberedWindow = activatedWindow ? null : addressedWindows.find(window => {
        const workspace = workspaceValues.find(value => value.id === workspaceId(window.workspace));
        return window.lastIpcObject?.focusHistoryID === 0 && workspace?.active === true
            && workspace.focused && outputs.some(output => output.name === workspace.output && output.focused);
    });
    const windows = addressedWindows.map(window => {
        const raw = window.lastIpcObject || {};
        const workspace = workspaceValues.find(value => value.id === workspaceId(window.workspace));
        const outputName = window.monitor?.name || workspace?.output || "";
        const output = outputs.find(value => value.name === outputName);
        // QVariantList fields are QML sequences, not native JavaScript arrays.
        const at = raw.at ? Array.from(raw.at) : [];
        const size = raw.size ? Array.from(raw.size) : [];
        const geometryKnown = at.length === 2 && size.length === 2
            && at.concat(size).every(value => typeof value === "number" && Number.isFinite(value))
            && size[0] > 0 && size[1] > 0 && output != null;
        if (workspace)
            workspace.windows++;
        const geometry = geometryKnown
            ? [at[0] - output.x, at[1] - output.y, size[0], size[1]]
            : [0, 0, 0, 0];
        // Scrolling fullscreen can apply to a column without covering its
        // monitor. Its internal mode alone must not hide shell chrome.
        const coversOutput = geometryKnown && geometry[0] <= 1 && geometry[1] <= 1
            && geometry[0] + geometry[2] >= output.width - 1
            && geometry[1] + geometry[3] >= output.height - 1;
        const focused = window === activatedWindow || window === rememberedWindow;
        const id = windowId(window.address);
        if (workspace && focused)
            workspace.activeWindowId = id;
        return {
            id: id,
            pid: Number(raw.pid || 0),
            appId: String(raw.class || ""),
            title: String(window.title || ""),
            workspaceId: workspaceId(window.workspace),
            output: outputName,
            floating: raw.floating === true,
            fullscreen: Number(raw.fullscreen) === 2 && raw.hidden !== true
                && (raw.fullscreenHandler !== "scrolling" || coversOutput),
            is_focused: focused,
            urgent: window.urgent === true,
            tiledAtTop: false,
            geometryKnown: geometryKnown,
            geometry: geometry
        };
    });
    // Hyprland lists toplevels in map order, so reordering columns/windows
    // never changes the list. Mirror Niri: order by workspace, then by layout
    // position (left to right, top to bottom), with floating windows last.
    const workspaceIdx = {};
    workspaceValues.forEach(workspace => workspaceIdx[workspace.id] = workspace.idx);
    const mapOrder = new Map(windows.map((window, index) => [window, index]));
    windows.sort((a, b) => {
        const workspaceOrder = (workspaceIdx[a.workspaceId] ?? 0) - (workspaceIdx[b.workspaceId] ?? 0);
        if (workspaceOrder !== 0)
            return workspaceOrder;
        if (a.floating !== b.floating)
            return a.floating ? 1 : -1;
        if (a.geometryKnown && b.geometryKnown) {
            // Compare in layout space; window geometry is already output-relative.
            const columnOrder = a.geometry[0] - b.geometry[0];
            if (columnOrder !== 0)
                return columnOrder;
            const rowOrder = a.geometry[1] - b.geometry[1];
            if (rowOrder !== 0)
                return rowOrder;
        }
        return mapOrder.get(a) - mapOrder.get(b);
    });
    const fullscreenOutputs = outputs.filter(output => windows.some(window => {
        const workspace = workspaceValues.find(value => value.id === window.workspaceId);
        return window.output === output.name && window.fullscreen && workspace?.active === true;
    })).map(output => output.name);
    return { windows: windows, workspaces: workspaceValues, outputs: outputs, overviewOpen: false, fullscreenOutputs: fullscreenOutputs };
}

function luaString(value) {
    return '"' + String(value).replace(/[\\"\x00-\x1f\x7f]/g, character => {
        if (character === '"' || character === "\\")
            return "\\" + character;
        return "\\" + String(character.charCodeAt(0)).padStart(3, "0");
    }) + '"';
}

function workspaceSelector(workspace) {
    if (!workspace || !workspace.id)
        throw new Error("Workspace no longer exists");
    // Select by Hyprland's address ("2"), never the display name: on Hyprland
    // 0.57 focusing "dev" creates a second, empty named workspace "dev".
    return luaString(String(workspace.id));
}

function focusWorkspace(workspace) {
    if (workspace?.special)
        throw new Error("Special workspaces are excluded from ordinary workspace navigation");
    return "hl.dsp.focus({ workspace = " + workspaceSelector(workspace) + " })";
}

function focusWindow(id) {
    return "hl.dsp.focus({ window = " + luaString("address:" + windowId(id)) + " })";
}

function closeWindow(id) {
    return "hl.dsp.window.close({ window = " + luaString("address:" + windowId(id)) + " })";
}

function moveWindowToWorkspace(id, workspace, follow) {
    const selector = "address:" + windowId(id);
    const target = workspaceSelector(workspace);
    return "hl.dsp.window.move({ window = " + luaString(selector) + ", workspace = " + target + ", follow = " + (follow ? "true" : "false") + " })";
}

function focusMonitor(name) {
    if (typeof name !== "string" || !name)
        throw new Error("Invalid output name");
    return "hl.dsp.focus({ monitor = " + luaString(name) + " })";
}

function logoutCommand() {
    return "hl.dsp.exit()";
}

function powerCommand(enabled) {
    return "hl.dsp.dpms({ action = \"" + (enabled ? "enable" : "disable") + "\" })";
}

function adjacentWorkspace(workspaces, output, direction) {
    if (direction !== -1 && direction !== 1)
        throw new Error("Workspace direction must be -1 or 1");
    const visible = workspaces.filter(workspace => workspace.output === output && !workspace.special)
        .sort((left, right) => left.idx - right.idx || left.name.localeCompare(right.name));
    const index = visible.findIndex(workspace => workspace.active);
    return index < 0 ? null : visible[index + direction] || null;
}
