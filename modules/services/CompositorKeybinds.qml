import QtQuick
import Quickshell.Io
import qs.config
import qs.modules.globals
import "../../config/KeybindActions.js" as KeybindActions

QtObject {
    id: root

    property Process compositorProcess: Process {}

    property var previousNonchalantBinds: ({})
    property var previousCustomBinds: []
    property bool hasPreviousBinds: false

    property Timer applyTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: applyKeybindsInternal()
    }

    function applyKeybinds() {
        applyTimer.restart();
    }

    // Helper function to check if an action is compatible with the current layout
    function isActionCompatibleWithLayout(action) {
        // If no layouts specified or empty array, action works in all layouts
        if (!action.layouts || action.layouts.length === 0)
            return true;

        // Check if current layout is in the allowed list
        const currentLayout = GlobalStates.compositorLayout;
        return action.layouts.indexOf(currentLayout) !== -1;
    }

    function cloneKeybind(keybind) {
        return {
            modifiers: keybind.modifiers ? keybind.modifiers.slice() : [],
            key: keybind.key || ""
        };
    }

    function storePreviousBinds() {
        if (!Config.keybindsLoader.loaded)
            return;

        const nonchalant = Config.keybindsLoader.adapter.nonchalant;

        // Store nonchalant core keybinds
        previousNonchalantBinds = {
            nonchalant: {
                launcher: cloneKeybind(nonchalant.launcher),
                dashboard: cloneKeybind(nonchalant.dashboard),
                assistant: cloneKeybind(nonchalant.assistant),
                clipboard: cloneKeybind(nonchalant.clipboard),
                emoji: cloneKeybind(nonchalant.emoji),
                notes: cloneKeybind(nonchalant.notes),
                tmux: cloneKeybind(nonchalant.tmux),
                wallpapers: cloneKeybind(nonchalant.wallpapers)
            },
            system: {
                overview: cloneKeybind(nonchalant.system.overview),
                powermenu: cloneKeybind(nonchalant.system.powermenu),
                config: cloneKeybind(nonchalant.system.config),
                lockscreen: cloneKeybind(nonchalant.system.lockscreen),
                tools: cloneKeybind(nonchalant.system.tools),
                screenshot: cloneKeybind(nonchalant.system.screenshot),
                screenrecord: cloneKeybind(nonchalant.system.screenrecord),
                lens: cloneKeybind(nonchalant.system.lens),
                reload: nonchalant.system.reload ? cloneKeybind(nonchalant.system.reload) : null,
                quit: nonchalant.system.quit ? cloneKeybind(nonchalant.system.quit) : null
            }
        };

        // Store custom keybinds
        const customBinds = Config.keybindsLoader.adapter.custom;
        previousCustomBinds = [];
        if (customBinds && customBinds.length > 0) {
            for (let i = 0; i < customBinds.length; i++) {
                const bind = customBinds[i];
                if (bind.keys) {
                    let keys = [];
                    for (let k = 0; k < bind.keys.length; k++) {
                        keys.push(cloneKeybind(bind.keys[k]));
                    }
                    previousCustomBinds.push({
                        keys: keys
                    });
                } else {
                    previousCustomBinds.push(cloneKeybind(bind));
                }
            }
        }

        hasPreviousBinds = true;
    }

    // Build an unbind target object (modifiers + key only).
    function makeUnbindTarget(keybind) {
        return {
            modifiers: keybind.modifiers || [],
            key: keybind.key || ""
        };
    }

    // Build a structured bind object from a core keybind (has all fields inline).
    function resolveBindAction(action, fallback) {
        const resolved = KeybindActions.resolveAction(action || fallback);
        if (!resolved) return null;
        return {
            dispatcher: resolved.dispatcher || "",
            argument: resolved.argument || "",
            flags: resolved.flags || ""
        };
    }

    function makeBindFromCore(keybind) {
        const resolved = resolveBindAction(keybind.action, keybind);
        if (!resolved) return null;
        return {
            modifiers: keybind.modifiers || [],
            key: keybind.key || "",
            dispatcher: resolved.dispatcher,
            argument: resolved.argument,
            flags: resolved.flags,
            enabled: true
        };
    }

    // Build a structured bind object from a key + action pair (custom keybinds).
    function makeBindFromKeyAction(keyObj, action) {
        const resolved = resolveBindAction(action, action);
        if (!resolved) return null;
        return {
            modifiers: keyObj.modifiers || [],
            key: keyObj.key || "",
            dispatcher: resolved.dispatcher,
            argument: resolved.argument,
            flags: resolved.flags,
            enabled: true
        };
    }

    function applyKeybindsInternal() {
        // Ensure adapter is loaded.
        if (!Config.keybindsLoader.loaded) {
            console.log("CompositorKeybinds: Esperando que se cargue el adapter...");
            return;
        }

        // Wait for layout to be ready.
        if (!GlobalStates.compositorLayoutReady) {
            console.log("CompositorKeybinds: Esperando que se detecte el layout de NiriService...");
            return;
        }

        console.log("CompositorKeybinds: Aplicando keybindings (layout: " + GlobalStates.compositorLayout + ")...");

        // Build structured payload.
        let payload = { binds: [], unbinds: [] };

        // First, unbind previous keybinds if we have them stored
        if (hasPreviousBinds) {
            // Unbind previous nonchalant core keybinds
            if (previousNonchalantBinds.nonchalant) {
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.nonchalant.launcher));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.nonchalant.dashboard));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.nonchalant.assistant));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.nonchalant.clipboard));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.nonchalant.emoji));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.nonchalant.notes));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.nonchalant.tmux));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.nonchalant.wallpapers));
            }

            // Unbind previous nonchalant system keybinds
            if (previousNonchalantBinds.system) {
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.system.overview));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.system.powermenu));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.system.config));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.system.lockscreen));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.system.tools));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.system.screenshot));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.system.screenrecord));
                payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.system.lens));
                if (previousNonchalantBinds.system.reload) payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.system.reload));
                if (previousNonchalantBinds.system.quit) payload.unbinds.push(makeUnbindTarget(previousNonchalantBinds.system.quit));
            }

            // Unbind previous custom keybinds
            for (let i = 0; i < previousCustomBinds.length; i++) {
                const prev = previousCustomBinds[i];
                if (prev.keys) {
                    for (let k = 0; k < prev.keys.length; k++) {
                        payload.unbinds.push(makeUnbindTarget(prev.keys[k]));
                    }
                } else {
                    payload.unbinds.push(makeUnbindTarget(prev));
                }
            }
        }

        // Process core keybinds.
        const nonchalant = Config.keybindsLoader.adapter.nonchalant;

        // Unbind current core keybinds (ensures clean state before rebinding)
        payload.unbinds.push(makeUnbindTarget(nonchalant.launcher));
        payload.unbinds.push(makeUnbindTarget(nonchalant.dashboard));
        payload.unbinds.push(makeUnbindTarget(nonchalant.assistant));
        payload.unbinds.push(makeUnbindTarget(nonchalant.clipboard));
        payload.unbinds.push(makeUnbindTarget(nonchalant.emoji));
        payload.unbinds.push(makeUnbindTarget(nonchalant.notes));
        payload.unbinds.push(makeUnbindTarget(nonchalant.tmux));
        payload.unbinds.push(makeUnbindTarget(nonchalant.wallpapers));

        // Bind current core keybinds
        [nonchalant.launcher, nonchalant.dashboard, nonchalant.assistant, nonchalant.clipboard, nonchalant.emoji, nonchalant.notes, nonchalant.tmux, nonchalant.wallpapers].forEach(bind => {
            const resolved = makeBindFromCore(bind);
            if (resolved) payload.binds.push(resolved);
        });

        // System keybinds
        const system = nonchalant.system;

        // Unbind current system keybinds
        payload.unbinds.push(makeUnbindTarget(system.overview));
        payload.unbinds.push(makeUnbindTarget(system.powermenu));
        payload.unbinds.push(makeUnbindTarget(system.config));
        payload.unbinds.push(makeUnbindTarget(system.lockscreen));
        payload.unbinds.push(makeUnbindTarget(system.tools));
        payload.unbinds.push(makeUnbindTarget(system.screenshot));
        payload.unbinds.push(makeUnbindTarget(system.screenrecord));
        payload.unbinds.push(makeUnbindTarget(system.lens));
        if (system.reload) payload.unbinds.push(makeUnbindTarget(system.reload));
        if (system.quit) payload.unbinds.push(makeUnbindTarget(system.quit));

        // Bind current system keybinds
        [system.overview, system.powermenu, system.config, system.lockscreen, system.tools, system.screenshot, system.screenrecord, system.lens, system.reload, system.quit].forEach(bind => {
            if (!bind) return;
            const resolved = makeBindFromCore(bind);
            if (resolved) payload.binds.push(resolved);
        });

        // Process custom keybinds (keys[] and actions[] format).
        const customBinds = Config.keybindsLoader.adapter.custom;
        if (customBinds && customBinds.length > 0) {
            for (let i = 0; i < customBinds.length; i++) {
                const bind = customBinds[i];

                // Check if bind has the new format
                if (bind.keys && bind.actions) {
                    // Unbind all keys first (always unbind regardless of layout)
                    for (let k = 0; k < bind.keys.length; k++) {
                        payload.unbinds.push(makeUnbindTarget(bind.keys[k]));
                    }

                    // Only create binds if enabled
                    if (bind.enabled !== false) {
                        // For each key, bind only compatible actions
                        for (let k = 0; k < bind.keys.length; k++) {
                            for (let a = 0; a < bind.actions.length; a++) {
                                const action = bind.actions[a];
                                // Check if this action is compatible with the current layout
                                if (isActionCompatibleWithLayout(action)) {
                                    const resolved = makeBindFromKeyAction(bind.keys[k], action);
                                    if (resolved) payload.binds.push(resolved);
                                }
                            }
                        }
                    }
                } else {
                    // Fallback for old format (shouldn't happen after normalization)
                    payload.unbinds.push(makeUnbindTarget(bind));
                    if (bind.enabled !== false) {
                        const resolved = makeBindFromCore(bind);
                        if (resolved) payload.binds.push(resolved);
                    }
                }
            }
        }

        storePreviousBinds();

        // Send structured payload via axctl keybinds-batch.
        console.log("CompositorKeybinds: Enviando keybinds-batch (" + payload.unbinds.length + " unbinds, " + payload.binds.length + " binds)");
        compositorProcess.command = ["axctl", "config", "keybinds-batch", JSON.stringify(payload)];
        compositorProcess.running = true;
    }

    property Connections configConnections: Connections {
        target: Config.keybindsLoader
        function onFileChanged() {
            applyKeybinds();
        }
        function onLoaded() {
            applyKeybinds();
        }
        function onAdapterUpdated() {
            applyKeybinds();
        }
    }

    // Re-apply keybinds when layout changes
    property Connections globalStatesConnections: Connections {
        target: GlobalStates
        function onCompositorLayoutChanged() {
            console.log("CompositorKeybinds: Layout changed to " + GlobalStates.compositorLayout + ", reapplying keybindings...");
            applyKeybinds();
        }
        function onCompositorLayoutReadyChanged() {
            if (GlobalStates.compositorLayoutReady) {
                applyKeybinds();
            }
        }
    }

    // property Connections compositorConnections: Connections {
    //     target: NiriService
    //     function onRawEvent(event) {
    //         if (event.name === "configreloaded") {
    //             console.log("CompositorKeybinds: Detectado configreloaded, reaplicando keybindings...");
    //             applyKeybinds();
    //         }
    //     }
    // }

    Component.onCompleted: {
        // Apply immediately if loader is ready.
        if (Config.keybindsLoader.loaded) {
            applyKeybinds();
        }
    }
}
