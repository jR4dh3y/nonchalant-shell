pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Project picker backend — mirrors ~/.local/bin/project-picker.
 * Scans ~/code and ~/random, ranks by recent, opens in code/zed.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string stateDir: {
        const xdg = Quickshell.env("XDG_STATE_HOME");
        return (xdg && xdg.length > 0 ? xdg : home + "/.local/state") + "/project-picker";
    }
    readonly property string recentFile: stateDir + "/recent"
    readonly property string editorFile: stateDir + "/editor"
    readonly property list<string> roots: [home + "/code", home + "/random"]
    readonly property int maxRecent: 100

    property list<string> allProjects: []
    property var projectIcons: ({})
    property list<string> recentProjects: []
    property string editor: "code"
    property list<string> availableEditors: []
    property bool scanning: false
    property bool ready: false
    property bool stateLoaded: false
    property string pendingEditor: ""

    signal projectsUpdated
    signal pathCopied(string path)

    function editorLabel(id) {
        if (id === "code")
            return "VS Code";
        if (id === "zed")
            return "Zed";
        return id || "Editor";
    }

    function editorPrompt(id) {
        if (id === "code")
            return "vscode";
        if (id === "zed")
            return "zed";
        return id || "editor";
    }

    function editorCommand(id) {
        if (id === "code")
            return "code";
        if (id === "zed")
            return "zed";
        return "";
    }

    function displayPath(absPath) {
        if (!absPath)
            return "";
        if (home && absPath.indexOf(home + "/") === 0)
            return "~/" + absPath.slice(home.length + 1);
        if (home && absPath === home)
            return "~";
        return absPath;
    }

    function absolutePath(display) {
        if (!display)
            return "";
        if (display.indexOf("~/") === 0)
            return home + "/" + display.slice(2);
        if (display === "~")
            return home;
        return display;
    }

    function projectName(absPath) {
        if (!absPath)
            return "";
        const parts = absPath.replace(/\/+$/, "").split("/");
        return parts[parts.length - 1] || absPath;
    }

    function projectParent(absPath) {
        if (!absPath)
            return "";
        const trimmed = absPath.replace(/\/+$/, "");
        const idx = trimmed.lastIndexOf("/");
        if (idx <= 0)
            return displayPath(trimmed);
        return displayPath(trimmed.slice(0, idx));
    }

    function projectIcon(absPath) {
        return projectIcons[absPath] || "";
    }

    function isEditorAvailable(id) {
        return availableEditors.indexOf(id) !== -1;
    }

    function toggleEditor() {
        if (availableEditors.length === 0)
            return;
        if (availableEditors.length === 1) {
            setEditor(availableEditors[0]);
            return;
        }
        const idx = availableEditors.indexOf(editor);
        const next = availableEditors[(idx + 1) % availableEditors.length];
        setEditor(next);
    }

    function setEditor(id) {
        if (!id || !isEditorAvailable(id))
            return;
        if (editor === id)
            return;
        editor = id;
        _persistEditor();
    }

    function fuzzyFilter(query) {
        const ordered = _orderedProjects();
        if (!query || query.trim().length === 0)
            return ordered;

        const q = query.trim().toLowerCase();
        const scored = [];
        for (let i = 0; i < ordered.length; i++) {
            const path = ordered[i];
            const display = displayPath(path).toLowerCase();
            const name = projectName(path).toLowerCase();
            let score = -1;
            if (name === q)
                score = 1000;
            else if (name.indexOf(q) === 0)
                score = 800 - name.length;
            else if (name.indexOf(q) !== -1)
                score = 600 - name.indexOf(q);
            else if (display.indexOf(q) !== -1)
                score = 400 - display.indexOf(q);
            if (score >= 0)
                scored.push({ path: path, score: score, order: i });
        }
        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            return a.order - b.order;
        });
        return scored.map(s => s.path);
    }

    function openProject(absPath) {
        if (!absPath)
            return false;
        const cmd = editorCommand(editor);
        if (!cmd || !isEditorAvailable(editor)) {
            console.warn("ProjectPicker: editor not available:", editor);
            return false;
        }
        rememberProject(absPath);
        _runDetached(cmd + " " + _shellQuote(absPath));
        return true;
    }

    function openProjectWithEditor(absPath, editorId) {
        if (editorId && isEditorAvailable(editorId))
            setEditor(editorId);
        return openProject(absPath);
    }

    function copyPath(absPath) {
        if (!absPath)
            return;
        const p = _shellQuote(absPath);
        _runDetached("printf %s " + p + " | wl-copy");
        pathCopied(absPath);
    }

    function rememberProject(absPath) {
        if (!absPath)
            return;
        const next = [absPath];
        for (let i = 0; i < recentProjects.length; i++) {
            if (recentProjects[i] !== absPath)
                next.push(recentProjects[i]);
        }
        recentProjects = next.slice(0, maxRecent);
        _persistRecent();
    }

    function refresh() {
        if (scanning || ready)
            return;
        detectEditors();
        _loadState();
        _scanProjects();
    }

    function detectEditors() {
        detectEditorsProcess.running = false;
        detectEditorsProcess.running = true;
    }

    function _orderedProjects() {
        const seen = {};
        const out = [];
        for (let i = 0; i < recentProjects.length; i++) {
            const p = recentProjects[i];
            if (p && !seen[p] && allProjects.indexOf(p) !== -1) {
                seen[p] = true;
                out.push(p);
            }
        }
        for (let j = 0; j < allProjects.length; j++) {
            const p2 = allProjects[j];
            if (p2 && !seen[p2]) {
                seen[p2] = true;
                out.push(p2);
            }
        }
        return out;
    }

    function _shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function _runDetached(command) {
        const p = Qt.createQmlObject("import Quickshell.Io; Process { }", root);
        p.command = ["bash", "-c", "cd ~ && setsid " + command + " < /dev/null > /dev/null 2>&1 &"];
        p.onExited.connect(() => p.destroy());
        p.running = true;
    }

    function _persistEditor() {
        ensureStateDir.command = [
            "bash", "-c",
            "mkdir -p " + _shellQuote(stateDir) +
            " && printf '%s\\n' " + _shellQuote(editor) + " > " + _shellQuote(editorFile)
        ];
        ensureStateDir.running = true;
    }

    function _persistRecent() {
        const quoted = recentProjects.map(p => _shellQuote(p)).join(" ");
        const writeBody = recentProjects.length > 0
            ? "printf '%s\\n' " + quoted + " > " + _shellQuote(recentFile)
            : ": > " + _shellQuote(recentFile);
        ensureStateDir.command = [
            "bash", "-c",
            "mkdir -p " + _shellQuote(stateDir) + " && " + writeBody
        ];
        ensureStateDir.running = true;
    }

    function _loadState() {
        loadStateProcess.running = false;
        loadStateProcess.running = true;
    }

    function _scanProjects() {
        scanning = true;
        scanProcess.running = false;
        scanProcess.running = true;
    }

    function _resolveEditor(preferred) {
        const eds = availableEditors;
        if (preferred && eds.indexOf(preferred) !== -1)
            return preferred;
        if (eds.length > 0)
            return eds[0];
        return preferred || "code";
    }

    function _applyEditor(preferred) {
        const chosen = _resolveEditor(preferred);
        if (editor !== chosen)
            editor = chosen;
    }

    function _applyLoadedState(editorId, recentText) {
        pendingEditor = editorId || "";
        if (availableEditors.length > 0)
            _applyEditor(pendingEditor);

        const recents = [];
        const lines = (recentText || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length > 0)
                recents.push(line);
        }
        recentProjects = recents;
        stateLoaded = true;
    }

    Process {
        id: detectEditorsProcess
        running: false
        command: [
            "bash", "-c",
            "command -v code >/dev/null 2>&1 && echo code; " +
            "command -v zed >/dev/null 2>&1 && echo zed"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length > 0);
                root.availableEditors = lines;
                root._applyEditor(root.pendingEditor || root.editor);
            }
        }
    }

    Process {
        id: loadStateProcess
        running: false
        command: [
            "bash", "-c",
            "mkdir -p " + root._shellQuote(root.stateDir) + "; " +
            "echo '---EDITOR---'; " +
            "if [ -f " + root._shellQuote(root.editorFile) + " ]; then sed -n '1p' " + root._shellQuote(root.editorFile) + "; fi; " +
            "echo '---RECENT---'; " +
            "if [ -f " + root._shellQuote(root.recentFile) + " ]; then cat " + root._shellQuote(root.recentFile) + "; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text || "";
                const editorMarker = "---EDITOR---\n";
                const recentMarker = "---RECENT---\n";
                let editorId = "";
                let recentText = "";
                const eIdx = raw.indexOf(editorMarker);
                const rIdx = raw.indexOf(recentMarker);
                if (eIdx !== -1) {
                    const start = eIdx + editorMarker.length;
                    const end = rIdx !== -1 ? rIdx : raw.length;
                    editorId = raw.slice(start, end).trim().split("\n")[0] || "";
                }
                if (rIdx !== -1)
                    recentText = raw.slice(rIdx + recentMarker.length);
                Qt.callLater(() => root._applyLoadedState(editorId, recentText));
            }
        }
    }

    Process {
        id: scanProcess
        running: false
        command: [
            "bash", "-c",
            "mapfile -t projects < <(" +
            "  roots=(" + root.roots.map(r => root._shellQuote(r)).join(" ") + "); " +
            "  for scan_root in \"${roots[@]}\"; do " +
            "    [[ -d \"$scan_root\" ]] || continue; " +
            "    find \"$scan_root\" -mindepth 1 -maxdepth 1 -type d 2>/dev/null; " +
            "    if command -v fd >/dev/null 2>&1; then " +
            "      fd -H -t d -d 4 '^\\.git$' \"$scan_root\" 2>/dev/null | sed -E 's#/.git/?$##'; " +
            "    else " +
            "      find \"$scan_root\" -maxdepth 5 -type d -name .git 2>/dev/null | sed -E 's#/.git/?$##'; " +
            "    fi; " +
            "  done | awk '!seen[$0]++'" +
            "); " +
            "for project in \"${projects[@]}\"; do " +
            "  icon=$(find \"$project\" " +
            "    \\( -type d \\( -name .git -o -name node_modules -o -name build -o -name dist -o -name target -o -name .cache -o -name .venv \\) -prune \\) -o " +
            "    \\( -type f " +
            "      \\( -iname '*.svg' -o -iname '*.ico' -o -iname '*.png' \\) " +
            "      \\( -iname 'dev.*' -o -iname 'dev-*' -o -iname 'dev_*' " +
            "         -o -iname 'icon*' -o -iname 'favicon*' -o -iname 'logo*' " +
            "         -o -iname 'io.*' " +
            "         -o -iname 'app-icon*' -o -iname 'app_icon*' -o -iname 'appicon*' " +
            "         -o -iname 'application-icon*' -o -iname 'application_icon*' -o -iname 'applicationicon*' " +
            "         -o -iname 'project-icon*' -o -iname 'project_icon*' -o -iname 'projecticon*' " +
            "         -o -iname 'site-icon*' -o -iname 'site_icon*' -o -iname 'siteicon*' " +
            "         -o -iname 'web-icon*' -o -iname 'web_icon*' -o -iname 'webicon*' " +
            "         -o -iname 'launcher-icon*' -o -iname 'launcher_icon*' -o -iname 'launcher*' " +
            "         -o -iname 'desktop-icon*' -o -iname 'desktop_icon*' " +
            "         -o -iname 'apple-touch-icon*' -o -iname 'android-chrome*' -o -iname 'mstile*' " +
            "         -o -iname 'brand*' -o -iname 'brandmark*' -o -iname 'mark.*' -o -iname 'symbol.*' \\) " +
            // "         -o -iname '*-logo.*' " +
            "      -print -quit \\) 2>/dev/null); " +
            "  printf '%s\\t%s\\n' \"$project\" \"$icon\"; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (text || "").split("\n");
                const projects = [];
                const icons = {};
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    if (line.length === 0)
                        continue;
                    const separator = line.indexOf("\t");
                    const project = (separator === -1 ? line : line.slice(0, separator)).trim();
                    const icon = separator === -1 ? "" : line.slice(separator + 1).trim();
                    if (project.length > 0) {
                        projects.push(project);
                        if (icon.length > 0)
                            icons[project] = icon;
                    }
                }
                Qt.callLater(() => {
                    root.allProjects = projects;
                    root.projectIcons = icons;
                    root.scanning = false;
                    root.ready = true;
                    root.projectsUpdated();
                });
            }
        }
        onExited: code => {
            if (code !== 0 && root.scanning) {
                root.scanning = false;
                root.ready = true;
                root.projectsUpdated();
            }
        }
    }

    Process {
        id: ensureStateDir
        running: false
        command: []
    }

    Component.onCompleted: {
        refresh();
    }
}
