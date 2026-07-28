pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.services

// ACP client and chat-state adapter for the assistant sidebar.
//
// The shell deliberately does not implement an AI harness. OpenCode, Grok
// Build, and Codex run as local ACP agents and retain ownership of auth,
// models, tools, permissions, and conversation context.
Singleton {
    id: root

    readonly property bool featureEnabled: Config.aiReady && (Config.ai.enabled ?? true)

    // ============================================
    // AGENTS
    // ============================================

    readonly property var builtInAgents: [
        {
            id: "opencode",
            name: "OpenCode",
            description: "OpenCode coding agent over ACP",
            icon: Qt.resolvedUrl("../../../assets/aiproviders/openrouter.svg"),
            command: ["opencode", "acp", "--print-logs", "--log-level", "ERROR"],
            authMethod: "opencode-login",
            installHint: "Install OpenCode, then run: opencode auth login",
            provider: "acp",
            api_format: "ACP",
            model: "opencode"
        },
        {
            id: "grok",
            name: "Grok Build",
            description: "xAI Grok Build coding agent over ACP",
            icon: Qt.resolvedUrl("../../../assets/aiproviders/xai.svg"),
            command: ["grok", "agent", "stdio"],
            authMethod: "cached_token",
            installHint: "Install Grok Build and complete its normal login flow",
            provider: "acp",
            api_format: "ACP",
            model: "grok"
        },
        {
            id: "codex",
            name: "Codex",
            description: "OpenAI Codex coding agent through the official ACP adapter",
            icon: Qt.resolvedUrl("../../../assets/aiproviders/openai.svg"),
            command: ["sh", "-lc", "CODEX_PATH=\"$(command -v codex)\" exec npx -y @agentclientprotocol/codex-acp"],
            authMethod: "chatgpt",
            installHint: "Install Codex and Node.js; the ACP adapter reuses your Codex login",
            provider: "acp",
            api_format: "ACP",
            model: "codex"
        }
    ]

    property var models: builtInAgents
    property var currentModel: models.length > 0 ? models[0] : null
    property string currentAgentId: currentModel ? currentModel.id : "opencode"
    property string processAgentId: ""
    property bool fetchingModels: false

    function normalizeAgent(configured, fallback) {
        let command = configured && Array.isArray(configured.command) ? configured.command : fallback.command;
        if (!command || command.length === 0)
            command = fallback.command;
        return {
            id: configured && configured.id ? configured.id : fallback.id,
            name: configured && configured.name ? configured.name : fallback.name,
            description: configured && configured.description ? configured.description : fallback.description,
            icon: fallback.icon,
            command: command,
            authMethod: configured && configured.authMethod ? configured.authMethod : fallback.authMethod,
            installHint: configured && configured.installHint ? configured.installHint : fallback.installHint,
            provider: "acp",
            api_format: "ACP",
            model: configured && configured.id ? configured.id : fallback.id
        };
    }

    function refreshAgents() {
        let configured = Config.ai && Array.isArray(Config.ai.agents) ? Config.ai.agents : [];
        let next = [];
        for (let i = 0; i < builtInAgents.length; i++) {
            let fallback = builtInAgents[i];
            let override = null;
            for (let j = 0; j < configured.length; j++) {
                if (configured[j] && configured[j].id === fallback.id) {
                    override = configured[j];
                    break;
                }
            }
            next.push(normalizeAgent(override, fallback));
        }
        models = next;

        let restored = findAgent(currentAgentId);
        if (!restored) {
            let preferred = Config.ai && Config.ai.defaultAgent ? Config.ai.defaultAgent : "opencode";
            restored = findAgent(preferred) || models[0];
        }
        if (restored) {
            currentModel = restored;
            currentAgentId = restored.id;
        }
    }

    function findAgent(value) {
        let needle = (value || "").toLowerCase();
        for (let i = 0; i < models.length; i++) {
            let agent = models[i];
            if (agent.id.toLowerCase() === needle || agent.name.toLowerCase() === needle)
                return agent;
        }
        return null;
    }

    function setModel(value) {
        let agent = findAgent(value);
        if (!agent) {
            pushSystemMessage("Unknown ACP agent: " + value);
            return;
        }
        if (agent.id === currentAgentId)
            return;

        cancelGeneration(false);
        currentModel = agent;
        currentAgentId = agent.id;
        StateService.set("lastAiAgent", agent.id);
        createNewChat();
    }

    function fetchAvailableModels() {
        fetchingModels = true;
        refreshAgents();
        refreshTimer.restart();
    }

    function reconnectAgent() {
        if (!featureEnabled)
            return;
        cancelGeneration(false);
        sessionReady = false;
        currentSessionId = "";
        pendingSessionAction = {
            kind: "new"
        };
        restartAgentProcess();
    }

    Timer {
        id: refreshTimer
        interval: 250
        onTriggered: root.fetchingModels = false
    }

    // ============================================
    // ACP CONNECTION
    // ============================================

    readonly property int protocolVersion: 1
    property bool initialized: false
    property bool authenticated: false
    property bool sessionReady: false
    property bool expectedProcessStop: false
    property bool restartPending: false
    property bool suppressReplay: false
    property var agentCapabilities: ({})
    property var authMethods: []
    property var pendingRpc: ({})
    property int nextRpcId: 1
    property int activePromptRequestId: -1
    property var pendingSessionAction: null
    property var queuedPrompt: null
    property string agentStderrTail: ""
    property bool turnFailureHandled: false

    property var sessionConfigOptions: []
    property var sessionModels: []
    property string currentSessionModelId: ""
    property var availableCommands: []
    property string currentModeId: ""
    property int contextUsed: 0
    property int contextSize: 0
    property real sessionCost: 0
    property string sessionCostCurrency: ""

    function workingDirectory() {
        let configured = Config.ai && Config.ai.workingDirectory ? Config.ai.workingDirectory.trim() : "";
        if (!configured)
            return Quickshell.env("HOME");
        if (configured === "~")
            return Quickshell.env("HOME");
        if (configured.startsWith("~/"))
            return Quickshell.env("HOME") + configured.substring(1);
        if (configured.startsWith("/"))
            return configured;
        return Quickshell.env("HOME") + "/" + configured;
    }

    function resetConnectionState() {
        initialized = false;
        authenticated = false;
        sessionReady = false;
        agentCapabilities = {};
        authMethods = [];
        pendingRpc = {};
        activePromptRequestId = -1;
        sessionConfigOptions = [];
        sessionModels = [];
        currentSessionModelId = "";
        availableCommands = [];
        currentModeId = "";
        processAgentId = "";
        agentStderrTail = "";
    }

    function startAgentProcess() {
        if (!featureEnabled || !currentModel)
            return;
        resetConnectionState();
        processAgentId = currentAgentId;
        agentProcess.command = currentModel.command;
        agentProcess.workingDirectory = workingDirectory();
        expectedProcessStop = false;
        statusText = "Starting " + currentModel.name + "…";
        agentProcess.running = true;
    }

    function restartAgentProcess() {
        if (!featureEnabled) {
            shutdown();
            return;
        }
        if (agentProcess.running) {
            restartPending = true;
            expectedProcessStop = true;
            agentProcess.running = false;
            return;
        }
        restartPending = false;
        startAgentProcess();
    }

    function ensureConnection(action) {
        if (!featureEnabled)
            return;
        pendingSessionAction = action;
        if (agentProcess.running && processAgentId === currentAgentId && authenticated) {
            performSessionAction();
            return;
        }
        if (!agentProcess.running || processAgentId !== currentAgentId) {
            restartAgentProcess();
            return;
        }
        statusText = "Connecting to " + currentModel.name + "…";
    }

    function sendEnvelope(envelope) {
        if (!agentProcess.running)
            return false;
        agentProcess.write(JSON.stringify(envelope) + "\n");
        return true;
    }

    function sendRequest(method, params, kind, context) {
        let id = nextRpcId++;
        let pending = Object.assign({}, pendingRpc);
        pending[String(id)] = {
            kind: kind || method,
            method: method,
            context: context || {}
        };
        pendingRpc = pending;
        if (!sendEnvelope({
            jsonrpc: "2.0",
            id: id,
            method: method,
            params: params || {}
        })) {
            delete pending[String(id)];
            pendingRpc = pending;
            return -1;
        }
        return id;
    }

    function sendNotification(method, params) {
        sendEnvelope({
            jsonrpc: "2.0",
            method: method,
            params: params || {}
        });
    }

    function sendResponse(id, result) {
        sendEnvelope({
            jsonrpc: "2.0",
            id: id,
            result: result
        });
    }

    function sendErrorResponse(id, code, message) {
        sendEnvelope({
            jsonrpc: "2.0",
            id: id,
            error: {
                code: code,
                message: message
            }
        });
    }

    function startInitialization() {
        sendRequest("initialize", {
            protocolVersion: protocolVersion,
            clientCapabilities: {
                fs: {
                    readTextFile: false,
                    writeTextFile: false
                },
                terminal: false
            },
            clientInfo: {
                name: "nonchalant-shell",
                title: "Nonchalant Shell",
                version: "1.0.0"
            }
        }, "initialize");
    }

    function chooseAuthMethod(result) {
        let methods = result && Array.isArray(result.authMethods) ? result.authMethods : [];
        if (methods.length === 0)
            return "";

        let preferred = currentModel ? currentModel.authMethod : "";
        if (currentAgentId === "codex") {
            if (Quickshell.env("CODEX_API_KEY"))
                preferred = "codex-api-key";
            else if (Quickshell.env("OPENAI_API_KEY"))
                preferred = "openai-api-key";
        }
        if (result._meta && result._meta.defaultAuthMethodId && currentAgentId !== "codex")
            preferred = result._meta.defaultAuthMethodId;

        for (let i = 0; i < methods.length; i++) {
            if (methods[i].id === preferred)
                return preferred;
        }
        return methods[0].id || "";
    }

    function performSessionAction() {
        if (!authenticated || !pendingSessionAction)
            return;

        let action = pendingSessionAction;
        pendingSessionAction = null;
        let params = {
            cwd: action.cwd || workingDirectory(),
            mcpServers: []
        };

        if (action.kind === "load" && action.sessionId) {
            let sessionCapabilities = agentCapabilities && agentCapabilities.sessionCapabilities
                ? agentCapabilities.sessionCapabilities : {};
            if (sessionCapabilities.resume !== undefined && sessionCapabilities.resume !== null) {
                params.sessionId = action.sessionId;
                sendRequest("session/resume", params, "session_resume", action);
                statusText = "Resuming " + currentModel.name + " session…";
                return;
            }
            if (agentCapabilities && agentCapabilities.loadSession === true) {
                params.sessionId = action.sessionId;
                suppressReplay = true;
                sendRequest("session/load", params, "session_load", action);
                statusText = "Loading " + currentModel.name + " session…";
                return;
            }
            pushSystemMessage(currentModel.name + " cannot restore this ACP session. A new session was started.");
        }

        sendRequest("session/new", params, "session_new", action);
        statusText = "Opening " + currentModel.name + " session…";
    }

    function applySessionSetup(result) {
        let setup = result || {};
        if (setup.sessionId)
            currentSessionId = setup.sessionId;
        sessionReady = currentSessionId.length > 0;
        suppressReplay = false;
        updateSessionConfiguration(setup);
        statusText = queuedPrompt ? "Thinking…" : "";
        saveCurrentChat();
        if (queuedPrompt)
            dispatchQueuedPrompt();
    }

    function updateSessionConfiguration(payload) {
        let data = payload || {};
        if (Array.isArray(data.configOptions))
            sessionConfigOptions = data.configOptions;

        if (data.models) {
            currentSessionModelId = data.models.currentModelId || currentSessionModelId;
            sessionModels = Array.isArray(data.models.availableModels) ? data.models.availableModels : sessionModels;
        }

        let modelOption = null;
        for (let i = 0; i < sessionConfigOptions.length; i++) {
            let option = sessionConfigOptions[i];
            if (option && (option.category === "model" || option.id === "model")) {
                modelOption = option;
                break;
            }
        }
        if (modelOption) {
            currentSessionModelId = String(modelOption.currentValue || "");
            let mapped = [];
            let choices = Array.isArray(modelOption.options) ? modelOption.options : [];
            for (let i = 0; i < choices.length; i++) {
                mapped.push({
                    modelId: String(choices[i].value || ""),
                    name: choices[i].name || String(choices[i].value || ""),
                    description: choices[i].description || ""
                });
            }
            sessionModels = mapped;
        }
    }

    function setSessionConfigOption(configId, value) {
        if (!sessionReady)
            return;
        let params = {
            sessionId: currentSessionId,
            configId: configId,
            value: value
        };
        if (typeof value === "boolean")
            params.type = "boolean";
        sendRequest("session/set_config_option", params, "set_config_option", {
            configId: configId,
            value: value
        });
    }

    function setSessionModel(modelId) {
        if (!sessionReady || !modelId)
            return;
        for (let i = 0; i < sessionConfigOptions.length; i++) {
            let option = sessionConfigOptions[i];
            if (option && (option.category === "model" || option.id === "model")) {
                setSessionConfigOption(option.id, modelId);
                return;
            }
        }
        sendRequest("session/set_model", {
            sessionId: currentSessionId,
            modelId: modelId
        }, "set_model", {
            modelId: modelId
        });
    }

    function formatRpcError(error) {
        if (!error)
            return "Unknown ACP error";
        let message = error.message || "ACP request failed";
        if (error.data) {
            if (typeof error.data === "string")
                message += ": " + error.data;
            else if (error.data.message)
                message += ": " + error.data.message;
            else if (error.data.detail)
                message += ": " + error.data.detail;
        }
        return message;
    }

    function handleRpcError(entry, error) {
        let message = formatRpcError(error);
        console.warn("ACP " + (entry ? entry.method : "request") + " failed: " + message);
        turnWatchdog.stop();

        if (entry && (entry.kind === "session_load" || entry.kind === "session_resume")) {
            suppressReplay = false;
            pushSystemMessage("Could not restore the ACP session: " + message + ". Starting a new session.");
            pendingSessionAction = {
                kind: "new"
            };
            performSessionAction();
            return;
        }

        lastError = message;
        isLoading = false;
        agentTurnActive = false;
        toolRunning = false;
        statusText = "";
        let hint = currentModel && currentModel.installHint ? "\n\n" + currentModel.installHint : "";
        pushSystemMessage(message + hint);
    }

    function handleResponse(message) {
        let key = String(message.id);
        let entry = pendingRpc[key];
        let next = Object.assign({}, pendingRpc);
        delete next[key];
        pendingRpc = next;
        if (!entry)
            return;
        if (message.error) {
            handleRpcError(entry, message.error);
            return;
        }

        let result = message.result || {};
        switch (entry.kind) {
        case "initialize": {
            if (result.protocolVersion !== protocolVersion) {
                handleRpcError(entry, {
                    message: "Unsupported ACP protocol version " + result.protocolVersion
                });
                return;
            }
            initialized = true;
            agentCapabilities = result.agentCapabilities || {};
            authMethods = Array.isArray(result.authMethods) ? result.authMethods : [];
            if (result._meta && result._meta.modelState) {
                currentSessionModelId = result._meta.modelState.currentModelId || "";
                sessionModels = result._meta.modelState.availableModels || [];
            }
            let authMethod = chooseAuthMethod(result);
            if (authMethod) {
                statusText = "Authenticating " + currentModel.name + "…";
                sendRequest("authenticate", {
                    methodId: authMethod
                }, "authenticate");
            } else {
                authenticated = true;
                performSessionAction();
            }
            break;
        }
        case "authenticate":
            authenticated = true;
            performSessionAction();
            break;
        case "session_new":
        case "session_load":
        case "session_resume":
            applySessionSetup(result);
            break;
        case "prompt":
            if (message.id === activePromptRequestId)
                activePromptRequestId = -1;
            turnWatchdog.stop();
            isLoading = false;
            agentTurnActive = false;
            toolRunning = false;
            statusText = "";
            activeAssistantIndex = -1;
            activeAssistantMessageId = "";
            saveCurrentChat();
            break;
        case "set_config_option":
            updateSessionConfiguration(result);
            statusText = "";
            break;
        case "set_model":
            currentSessionModelId = entry.context.modelId || currentSessionModelId;
            statusText = "";
            break;
        }
    }

    function handleAgentRequest(message) {
        if (message.method === "session/request_permission") {
            handlePermissionRequest(message.id, message.params || {});
            return;
        }

        // These capabilities are intentionally not advertised. Rejecting a
        // non-conforming request is safer than silently touching the system.
        if (message.id !== undefined)
            sendErrorResponse(message.id, -32601, "ACP client method not supported: " + message.method);
    }

    function handleAcpLine(line) {
        let trimmed = (line || "").trim();
        if (!trimmed)
            return;
        let message;
        try {
            message = JSON.parse(trimmed);
        } catch (e) {
            console.warn("Ignoring non-JSON ACP stdout: " + trimmed.substring(0, 200));
            return;
        }

        if (message.method) {
            if (message.method === "session/update") {
                handleSessionUpdate(message.params || {});
            } else {
                handleAgentRequest(message);
            }
            return;
        }
        if (message.id !== undefined)
            handleResponse(message);
    }

    Process {
        id: agentProcess
        stdinEnabled: true

        stdout: SplitParser {
            onRead: data => root.handleAcpLine(data)
        }

        stderr: SplitParser {
            onRead: data => root.handleAgentStderr(data)
        }

        onStarted: root.startInitialization()

        onExited: (exitCode, exitStatus) => {
            let wasExpected = root.expectedProcessStop;
            let shouldRestart = root.restartPending;
            let stderrText = root.agentStderrTail.trim();
            root.expectedProcessStop = false;
            root.restartPending = false;
            turnWatchdog.stop();
            root.resetConnectionState();

            if (shouldRestart) {
                Qt.callLater(root.startAgentProcess);
                return;
            }
            if (!wasExpected) {
                root.isLoading = false;
                root.agentTurnActive = false;
                root.toolRunning = false;
                root.statusText = "";
                let detail = stderrText.length > 0 ? stderrText.split("\n").slice(-3).join("\n")
                    : ("Agent process exited with code " + exitCode);
                let hint = root.currentModel && root.currentModel.installHint
                    ? "\n\n" + root.currentModel.installHint : "";
                root.pushSystemMessage(detail + hint);
            }
        }
    }

    function handleAgentStderr(data) {
        let line = (data || "").trim();
        if (!line)
            return;
        agentStderrTail = (agentStderrTail + "\n" + line).slice(-6000);
        if (!agentTurnActive || turnFailureHandled)
            return;

        let lower = line.toLowerCase();
        if (lower.includes("quota reached") || lower.includes("quota_exhausted")
                || lower.includes("resource_exhausted")) {
            failActiveTurn(
                currentModel.name + " reported that the active model's provider quota is exhausted."
                + "\n\nChoose another model with `/model`, or update the model in "
                + currentModel.name + "."
            );
        } else if (lower.includes("rate limit") || lower.includes("status\":429")
                || lower.includes("[429]")) {
            failActiveTurn(
                currentModel.name + " was rate-limited by the active model provider."
                + "\n\nWait for the provider reset or choose another model with `/model`."
            );
        } else if (lower.includes("unauthorized") || lower.includes("authentication failed")
                || lower.includes("invalid api key")) {
            failActiveTurn(
                currentModel.name + " could not authenticate with the active model provider."
                + "\n\nComplete the agent's login flow, then reconnect it."
            );
        }
    }

    // ============================================
    // ACP SESSION UPDATES
    // ============================================

    property string activeAssistantMessageId: ""
    property int activeAssistantIndex: -1
    property var pendingPermissions: ({})

    function contentBlockText(content) {
        if (!content)
            return "";
        if (content.type === "text")
            return content.text || "";
        if (content.type === "resource" && content.resource)
            return content.resource.text || content.resource.uri || "";
        if (content.type === "resource_link")
            return content.name || content.uri || "";
        if (content.type === "image")
            return "[Image]";
        if (content.type === "audio")
            return "[Audio]";
        return "";
    }

    function toolContentText(content) {
        if (!Array.isArray(content))
            return "";
        let parts = [];
        for (let i = 0; i < content.length; i++) {
            let item = content[i];
            if (!item)
                continue;
            if (item.type === "content")
                parts.push(contentBlockText(item.content));
            else if (item.type === "diff") {
                let diff = "Changed " + (item.path || "file");
                if (item.newText)
                    diff += "\n\n" + item.newText;
                parts.push(diff);
            } else if (item.type === "terminal")
                parts.push(item.output || "");
        }
        return parts.filter(part => part && part.length > 0).join("\n\n");
    }

    function appendAgentMessage(update) {
        let text = contentBlockText(update.content);
        if (!text)
            return;
        let messageId = update.messageId || "";
        let shouldCreate = activeAssistantIndex < 0 || activeAssistantIndex >= currentChat.length;
        if (!shouldCreate && messageId && activeAssistantMessageId && messageId !== activeAssistantMessageId)
            shouldCreate = true;

        let chat = Array.from(currentChat);
        if (shouldCreate) {
            chat.push({
                role: "assistant",
                content: text,
                model: activeAgentLabel(),
                acpMessageId: messageId
            });
            activeAssistantIndex = chat.length - 1;
            activeAssistantMessageId = messageId;
        } else {
            let existing = chat[activeAssistantIndex] || {};
            chat[activeAssistantIndex] = Object.assign({}, existing, {
                content: (existing.content || "") + text,
                model: activeAgentLabel(),
                acpMessageId: messageId || existing.acpMessageId || ""
            });
        }
        currentChat = chat;
    }

    function findToolMessageIndex(toolCallId) {
        for (let i = currentChat.length - 1; i >= 0; i--) {
            let msg = currentChat[i];
            if (msg && msg.functionCall && msg.functionCall.id === toolCallId)
                return i;
        }
        return -1;
    }

    function updateToolRunning() {
        let running = false;
        let turnStart = 0;
        for (let i = currentChat.length - 1; i >= 0; i--) {
            if (currentChat[i] && currentChat[i].role === "user") {
                turnStart = i;
                break;
            }
        }
        for (let i = turnStart; i < currentChat.length; i++) {
            let msg = currentChat[i];
            if (msg && msg.toolStatus && (msg.toolStatus === "pending" || msg.toolStatus === "in_progress")) {
                running = true;
                break;
            }
        }
        toolRunning = running;
    }

    function upsertToolCall(update) {
        let toolCallId = update.toolCallId || ("tool_" + Date.now());
        let index = findToolMessageIndex(toolCallId);
        let chat = Array.from(currentChat);
        let status = update.status || "pending";
        let title = update.title || update.kind || "Tool";
        let output = toolContentText(update.content);
        let args = update.rawInput || {};

        if (index < 0) {
            chat.push({
                role: "assistant",
                content: output,
                model: activeAgentLabel(),
                functionCall: {
                    id: toolCallId,
                    name: title,
                    args: args
                },
                functionPending: false,
                functionApproved: status === "completed" ? true : undefined,
                toolStatus: status,
                toolKind: update.kind || "other"
            });
        } else {
            let existing = chat[index];
            let existingCall = existing.functionCall || {};
            chat[index] = Object.assign({}, existing, {
                content: output || existing.content || "",
                functionCall: {
                    id: toolCallId,
                    name: update.title || existingCall.name || title,
                    args: update.rawInput || existingCall.args || {}
                },
                functionApproved: status === "completed" ? true
                    : (status === "failed" ? false : existing.functionApproved),
                toolStatus: status,
                toolKind: update.kind || existing.toolKind || "other"
            });
        }
        currentChat = chat;
        updateToolRunning();
        if (status === "completed" || status === "failed")
            saveCurrentChat();
    }

    function handlePermissionRequest(requestId, params) {
        let tool = params.toolCall || {};
        let toolCallId = tool.toolCallId || ("permission_" + requestId);
        upsertToolCall(tool);
        let index = findToolMessageIndex(toolCallId);
        if (index < 0) {
            sendResponse(requestId, {
                outcome: {
                    outcome: "cancelled"
                }
            });
            return;
        }

        let permissions = Object.assign({}, pendingPermissions);
        permissions[String(requestId)] = {
            requestId: requestId,
            toolCallId: toolCallId,
            options: Array.isArray(params.options) ? params.options : []
        };
        pendingPermissions = permissions;

        let chat = Array.from(currentChat);
        chat[index] = Object.assign({}, chat[index], {
            functionPending: true,
            permissionRequestId: requestId
        });
        currentChat = chat;
        turnWatchdog.stop();
        statusText = "Waiting for permission…";
    }

    function choosePermissionOption(options, allow) {
        let preferredKinds = allow ? ["allow_once", "allow_always"] : ["reject_once", "reject_always"];
        for (let p = 0; p < preferredKinds.length; p++) {
            for (let i = 0; i < options.length; i++) {
                if (options[i].kind === preferredKinds[p])
                    return options[i].optionId;
            }
        }
        return options.length > 0 ? options[0].optionId : "";
    }

    function resolvePermission(index, allow) {
        if (index < 0 || index >= currentChat.length)
            return;
        let message = currentChat[index];
        let requestId = message.permissionRequestId;
        let permission = pendingPermissions[String(requestId)];
        if (!permission)
            return;

        let optionId = choosePermissionOption(permission.options, allow);
        if (optionId) {
            sendResponse(requestId, {
                outcome: {
                    outcome: "selected",
                    optionId: optionId
                }
            });
        } else {
            sendResponse(requestId, {
                outcome: {
                    outcome: "cancelled"
                }
            });
        }

        let permissions = Object.assign({}, pendingPermissions);
        delete permissions[String(requestId)];
        pendingPermissions = permissions;
        let chat = Array.from(currentChat);
        chat[index] = Object.assign({}, chat[index], {
            functionPending: false,
            functionApproved: allow
        });
        currentChat = chat;
        statusText = allow ? "Running tool…" : "Tool rejected";
        if (allow && agentTurnActive)
            turnWatchdog.restart();
        saveCurrentChat();
    }

    function approveCommand(index) {
        resolvePermission(index, true);
    }

    function rejectCommand(index) {
        resolvePermission(index, false);
    }

    function handleSessionUpdate(params) {
        if (params.sessionId && currentSessionId && params.sessionId !== currentSessionId)
            return;
        if (suppressReplay)
            return;
        if (agentTurnActive)
            turnWatchdog.restart();

        let update = params.update || {};
        switch (update.sessionUpdate) {
        case "agent_message_chunk":
            appendAgentMessage(update);
            statusText = "Responding…";
            break;
        case "agent_thought_chunk": {
            let thought = contentBlockText(update.content).trim();
            statusText = thought ? thought.substring(0, 100) : "Thinking…";
            break;
        }
        case "tool_call":
        case "tool_call_update":
            upsertToolCall(update);
            if (update.status === "in_progress")
                statusText = update.title || "Running tool…";
            break;
        case "plan":
        case "plan_update":
            statusText = "Planning…";
            break;
        case "available_commands_update":
            availableCommands = update.availableCommands || update.commands || [];
            break;
        case "current_mode_update":
            currentModeId = update.currentModeId || update.modeId || "";
            break;
        case "config_option_update":
            updateSessionConfiguration(update);
            break;
        case "usage_update":
            contextUsed = update.used || 0;
            contextSize = update.size || 0;
            if (update.cost) {
                sessionCost = update.cost.amount || 0;
                sessionCostCurrency = update.cost.currency || "";
            }
            break;
        }
    }

    // ============================================
    // CHAT API
    // ============================================

    property bool isLoading: false
    property bool toolRunning: false
    property bool agentTurnActive: false
    readonly property bool isBusy: isLoading || toolRunning || agentTurnActive
    readonly property bool supportsMessageEditing: false
    readonly property bool supportsRegeneration: false
    property string statusText: ""
    property string lastError: ""

    Timer {
        id: turnWatchdog
        interval: 120000
        repeat: false
        onTriggered: root.failActiveTurn(
            "The ACP agent produced no updates for two minutes, so the stalled turn was cancelled."
            + "\n\nCheck the agent's provider connection or select another agent/model."
        )
    }

    property var currentChat: []
    property string currentChatId: ""
    property string currentChatAgentId: ""
    property string currentSessionId: ""
    property string currentChatCwd: ""
    property var chatHistory: []

    signal chatModelChanged
    signal historyModelChanged

    function activeAgentLabel() {
        let agent = currentModel ? currentModel.name : "ACP";
        if (currentSessionModelId)
            return agent + " · " + currentSessionModelId;
        return agent;
    }

    function pushSystemMessage(message) {
        if (!message)
            return;
        let chat = Array.from(currentChat);
        chat.push({
            role: "system",
            content: message
        });
        currentChat = chat;
        saveCurrentChat();
    }

    function failActiveTurn(message) {
        if (!agentTurnActive || turnFailureHandled)
            return;
        turnFailureHandled = true;
        cancelGeneration(false);
        lastError = message;
        pushSystemMessage(message);
    }

    function commandHelp() {
        let lines = [
            "🤖 **ACP Assistant Commands**",
            "",
            "**`/new`** — start a fresh ACP session",
            "**`/agent`** — list OpenCode, Grok Build, and Codex",
            "**`/agent <name>`** — switch ACP agent",
            "**`/model`** — list models exposed by the active agent",
            "**`/model <id>`** — select an agent model",
            "**`/status`** — show the active ACP connection"
        ];
        if (availableCommands.length > 0) {
            lines.push("", "**Agent commands**");
            for (let i = 0; i < availableCommands.length; i++) {
                let command = availableCommands[i];
                lines.push("`/" + (command.name || "") + "` — " + (command.description || ""));
            }
        }
        return lines.join("\n");
    }

    function handleLocalCommand(message) {
        if (!message.startsWith("/"))
            return false;
        let parts = message.substring(1).trim().split(/\s+/);
        let command = (parts.shift() || "").toLowerCase();
        let argument = parts.join(" ").trim();

        if (command === "new") {
            createNewChat();
            return true;
        }
        if (command === "help") {
            pushSystemMessage(commandHelp());
            return true;
        }
        if (command === "agent") {
            if (argument) {
                setModel(argument);
            } else {
                let names = models.map(agent => "`" + agent.id + "` — " + agent.name);
                pushSystemMessage("Available ACP agents:\n\n" + names.join("\n"));
            }
            return true;
        }
        if (command === "model") {
            if (argument) {
                setSessionModel(argument);
            } else if (sessionModels.length > 0) {
                let max = Math.min(sessionModels.length, 40);
                let names = [];
                for (let i = 0; i < max; i++) {
                    let model = sessionModels[i];
                    names.push("`" + (model.modelId || "") + "` — " + (model.name || model.modelId || ""));
                }
                if (sessionModels.length > max)
                    names.push("…and " + (sessionModels.length - max) + " more");
                pushSystemMessage("Active model: `" + currentSessionModelId + "`\n\n" + names.join("\n"));
            } else {
                pushSystemMessage("The active ACP agent has not exposed a model selector.");
            }
            return true;
        }
        if (command === "status") {
            pushSystemMessage(
                "**Agent:** " + (currentModel ? currentModel.name : "None")
                + "\n**ACP:** " + (sessionReady ? "connected" : "disconnected")
                + "\n**Session:** `" + (currentSessionId || "none") + "`"
                + "\n**Model:** `" + (currentSessionModelId || "agent default") + "`"
                + "\n**Working directory:** `" + workingDirectory() + "`"
            );
            return true;
        }
        return false;
    }

    function sendMessage(message, attachments) {
        let text = message || "";
        if (handleLocalCommand(text))
            return;
        if (!text.trim() && (!attachments || attachments.length === 0))
            return;
        if (isBusy) {
            pushSystemMessage("The active ACP turn is still running. Stop it before sending another message.");
            return;
        }

        if (!currentChatId)
            currentChatId = String(Date.now());
        let chat = Array.from(currentChat);
        chat.push({
            role: "user",
            content: text,
            attachments: attachments || []
        });
        currentChat = chat;
        currentChatAgentId = currentAgentId;
        currentChatCwd = workingDirectory();
        saveCurrentChat();

        queuedPrompt = {
            text: text,
            attachments: attachments || []
        };
        isLoading = true;
        agentTurnActive = true;
        turnFailureHandled = false;
        lastError = "";
        statusText = sessionReady ? "Thinking…" : "Connecting to " + currentModel.name + "…";
        activeAssistantIndex = -1;
        activeAssistantMessageId = "";

        if (sessionReady && agentProcess.running && processAgentId === currentAgentId)
            dispatchQueuedPrompt();
        else
            ensureConnection({
                kind: currentSessionId ? "load" : "new",
                sessionId: currentSessionId,
                cwd: currentChatCwd
            });
    }

    function dispatchQueuedPrompt() {
        if (!queuedPrompt || !sessionReady)
            return;
        let queued = queuedPrompt;
        queuedPrompt = null;
        let prompt = [];
        if (queued.text)
            prompt.push({
                type: "text",
                text: queued.text
            });

        let supportsImages = agentCapabilities && agentCapabilities.promptCapabilities
            && agentCapabilities.promptCapabilities.image === true;
        let attachments = queued.attachments || [];
        for (let i = 0; i < attachments.length; i++) {
            let attachment = attachments[i];
            if (supportsImages && attachment && attachment.base64) {
                prompt.push({
                    type: "image",
                    mimeType: attachment.mimeType || "image/png",
                    data: attachment.base64
                });
            }
        }
        if (attachments.length > 0 && !supportsImages)
            pushSystemMessage(currentModel.name + " does not advertise ACP image support; attachments were omitted.");

        activePromptRequestId = sendRequest("session/prompt", {
            sessionId: currentSessionId,
            prompt: prompt
        }, "prompt");
        turnWatchdog.restart();
        statusText = "Thinking…";
    }

    function cancelGeneration(announce) {
        turnWatchdog.stop();
        if (currentSessionId && agentProcess.running) {
            sendNotification("session/cancel", {
                sessionId: currentSessionId
            });
            if (activePromptRequestId >= 0) {
                sendNotification("$/cancel_request", {
                    id: activePromptRequestId
                });
            }
        }

        let permissionKeys = Object.keys(pendingPermissions);
        for (let i = 0; i < permissionKeys.length; i++) {
            let pending = pendingPermissions[permissionKeys[i]];
            sendResponse(pending.requestId, {
                outcome: {
                    outcome: "cancelled"
                }
            });
        }
        pendingPermissions = {};
        activePromptRequestId = -1;
        queuedPrompt = null;
        isLoading = false;
        agentTurnActive = false;
        toolRunning = false;
        statusText = announce ? "Stopped" : "";

        let chat = Array.from(currentChat);
        for (let i = 0; i < chat.length; i++) {
            if (chat[i] && chat[i].functionPending === true) {
                chat[i] = Object.assign({}, chat[i], {
                    functionPending: false,
                    functionApproved: false,
                    toolStatus: "failed"
                });
            }
        }
        currentChat = chat;
        saveCurrentChat();
    }

    function createNewChat() {
        cancelGeneration(false);
        currentChat = [];
        currentChatId = String(Date.now());
        currentChatAgentId = currentAgentId;
        currentChatCwd = workingDirectory();
        currentSessionId = "";
        sessionReady = false;
        activeAssistantIndex = -1;
        activeAssistantMessageId = "";
        pendingPermissions = {};
        chatModelChanged();
        if (featureEnabled) {
            ensureConnection({
                kind: "new",
                cwd: currentChatCwd
            });
        }
    }

    function regenerateResponse(index) {
        pushSystemMessage("Regeneration is owned by the ACP agent. Ask it to reconsider or regenerate the response.");
    }

    function updateMessage(index, newContent) {
        pushSystemMessage("ACP session history is agent-owned, so previous turns cannot be edited locally.");
    }

    // ============================================
    // CHAT PERSISTENCE
    // ============================================

    property string chatDir: Quickshell.env("HOME") + "/.local/share/nonchalant/chats"
    property string pendingSavePath: ""
    property string pendingSaveData: ""

    FileView {
        id: chatFileView
        printErrors: false
        atomicWrites: true
    }

    function chatEnvelope() {
        return {
            version: 2,
            protocol: "acp",
            agentId: currentChatAgentId || currentAgentId,
            sessionId: currentSessionId,
            cwd: currentChatCwd || workingDirectory(),
            messages: currentChat
        };
    }

    function saveCurrentChat() {
        if (!currentChatId || currentChat.length === 0)
            return;
        pendingSavePath = chatDir + "/" + currentChatId + ".json";
        pendingSaveData = JSON.stringify(chatEnvelope(), null, 2);
        if (!ensureChatDirProcess.running) {
            ensureChatDirProcess.command = ["/usr/bin/mkdir", "-p", chatDir];
            ensureChatDirProcess.running = true;
        }
    }

    Process {
        id: ensureChatDirProcess
        onExited: exitCode => {
            if (exitCode !== 0 || !root.pendingSavePath)
                return;
            chatFileView.path = root.pendingSavePath;
            chatFileView.setText(root.pendingSaveData);
            root.pendingSavePath = "";
            root.pendingSaveData = "";
            root.reloadHistory();
        }
    }

    function deleteChat(id) {
        if (!id)
            return;
        if (id === currentChatId)
            createNewChat();
        deleteChatProcess.command = ["/usr/bin/rm", "-f", chatDir + "/" + id + ".json"];
        deleteChatProcess.running = true;
    }

    Process {
        id: deleteChatProcess
        onExited: root.reloadHistory()
    }

    function reloadHistory() {
        let pyScript = `import glob, json, os
chat_dir = ${JSON.stringify(chatDir)}
os.makedirs(chat_dir, exist_ok=True)
files = sorted(glob.glob(os.path.join(chat_dir, "*.json")), key=os.path.getmtime, reverse=True)
for path in files:
    chat_id = os.path.basename(path)[:-5]
    title = "New Chat"
    agent = ""
    try:
        with open(path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        messages = payload if isinstance(payload, list) else payload.get("messages", [])
        agent = "" if isinstance(payload, list) else payload.get("agentId", "")
        for message in messages:
            if message.get("role") == "user":
                value = message.get("content", "").replace("\\n", " ").strip()
                title = value[:40] + ("..." if len(value) > 40 else "")
                break
    except Exception:
        pass
    print(json.dumps({"id": chat_id, "title": title, "agentId": agent}))
`;
        listHistoryProcess.command = ["python3", "-c", pyScript];
        listHistoryProcess.running = true;
    }

    Process {
        id: listHistoryProcess
        stdout: SplitParser {
            onRead: data => {
                try {
                    let item = JSON.parse(data);
                    root._historyBuffer.push({
                        id: item.id,
                        title: item.title || "New Chat",
                        agentId: item.agentId || "",
                        path: root.chatDir + "/" + item.id + ".json"
                    });
                } catch (e) {
                    console.warn("Failed to parse chat history entry: " + e);
                }
            }
        }
        onRunningChanged: {
            if (running)
                root._historyBuffer = [];
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.chatHistory = root._historyBuffer.slice();
                root.historyModelChanged();
            }
        }
    }
    property var _historyBuffer: []

    function loadChat(id) {
        if (!id)
            return;
        cancelGeneration(false);
        loadChatProcess.targetId = id;
        loadChatProcess.command = ["/usr/bin/cat", chatDir + "/" + id + ".json"];
        loadChatProcess.running = true;
    }

    Process {
        id: loadChatProcess
        property string targetId: ""
        stdout: StdioCollector {
            id: loadChatStdout
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                return;
            try {
                let payload = JSON.parse(loadChatStdout.text);
                let isLegacy = Array.isArray(payload);
                let agentId = isLegacy ? root.currentAgentId : (payload.agentId || root.currentAgentId);
                let agent = root.findAgent(agentId) || root.currentModel;
                root.currentModel = agent;
                root.currentAgentId = agent.id;
                root.currentChatAgentId = agent.id;
                root.currentChat = isLegacy ? payload : (payload.messages || []);
                root.currentChatId = targetId;
                root.currentSessionId = isLegacy ? "" : (payload.sessionId || "");
                root.currentChatCwd = isLegacy ? root.workingDirectory() : (payload.cwd || root.workingDirectory());
                root.sessionReady = false;
                root.activeAssistantIndex = -1;
                root.activeAssistantMessageId = "";
                root.pendingPermissions = {};
                root.chatModelChanged();
                root.ensureConnection({
                    kind: root.currentSessionId ? "load" : "new",
                    sessionId: root.currentSessionId,
                    cwd: root.currentChatCwd
                });
            } catch (e) {
                root.pushSystemMessage("Failed to load chat: " + e);
            }
        }
    }

    // ============================================
    // INITIALIZATION
    // ============================================

    property bool bootstrapped: false

    function shutdown() {
        refreshTimer.stop();
        turnWatchdog.stop();
        restartPending = false;
        expectedProcessStop = true;
        pendingSessionAction = null;
        queuedPrompt = null;
        pendingPermissions = {};
        activePromptRequestId = -1;
        isLoading = false;
        agentTurnActive = false;
        toolRunning = false;
        statusText = "";
        if (agentProcess.running)
            agentProcess.running = false;
        if (ensureChatDirProcess.running)
            ensureChatDirProcess.running = false;
        if (deleteChatProcess.running)
            deleteChatProcess.running = false;
        if (listHistoryProcess.running)
            listHistoryProcess.running = false;
        if (loadChatProcess.running)
            loadChatProcess.running = false;
        resetConnectionState();
        bootstrapped = false;
    }

    function bootstrap() {
        if (!featureEnabled || bootstrapped)
            return;
        bootstrapped = true;
        refreshAgents();
        let preferred = StateService.get(
            "lastAiAgent",
            Config.ai && Config.ai.defaultAgent ? Config.ai.defaultAgent : "opencode"
        );
        let agent = findAgent(preferred) || models[0];
        if (agent) {
            currentModel = agent;
            currentAgentId = agent.id;
        }
        reloadHistory();
        createNewChat();
    }

    Connections {
        target: StateService
        function onStateLoaded() {
            if (root.featureEnabled && !root.bootstrapped)
                root.bootstrap();
        }
    }

    Connections {
        target: Config
        function onAiReadyChanged() {
            if (root.featureEnabled) {
                root.refreshAgents();
                if (!root.bootstrapped)
                    root.bootstrap();
            }
        }
    }

    Connections {
        target: Config.ai
        function onEnabledChanged() {
            if (root.featureEnabled)
                root.bootstrap();
            else
                root.shutdown();
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            if (root.featureEnabled && !root.bootstrapped)
                root.bootstrap();
        });
    }
}
