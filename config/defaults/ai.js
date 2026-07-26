var data = {
    "defaultAgent": "opencode",
    "workingDirectory": "",
    "agents": [
        {
            "id": "opencode",
            "name": "OpenCode",
            "command": ["opencode", "acp", "--print-logs", "--log-level", "ERROR"],
            "authMethod": "opencode-login"
        },
        {
            "id": "grok",
            "name": "Grok Build",
            "command": ["grok", "agent", "stdio"],
            "authMethod": "cached_token"
        },
        {
            "id": "codex",
            "name": "Codex",
            "command": ["sh", "-lc", "CODEX_PATH=\"$(command -v codex)\" exec npx -y @agentclientprotocol/codex-acp"],
            "authMethod": "chatgpt"
        }
    ],
    "sidebarWidth": 400,
    "sidebarPosition": "right",
    "sidebarPinnedOnStartup": false
}
