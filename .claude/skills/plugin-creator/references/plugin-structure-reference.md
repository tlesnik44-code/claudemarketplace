# Plugin Structure Reference

## Directory Layout

Every plugin follows this structure. Only `.claude-plugin/plugin.json` is required — all other directories are optional.

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json           # REQUIRED — plugin manifest
├── skills/                   # Agent Skills (auto-invoked by Claude)
│   └── skill-name/
│       ├── SKILL.md          # Skill definition with frontmatter
│       └── references/       # Optional reference docs
├── commands/                 # Slash commands (user-invoked)
│   └── command-name.md       # Command definition
├── agents/                   # Specialized sub-agents
│   └── agent-name.md         # Agent definition
├── hooks/                    # Event handlers
│   └── hooks.json            # Hook configuration
├── .mcp.json                 # MCP server configuration
├── .lsp.json                 # LSP server configuration
└── README.md                 # Plugin documentation
```

## Component Types

### Skills (`skills/`)

Skills are auto-invoked by Claude based on task context. Each skill is a folder with a `SKILL.md` file.

```markdown
---
name: my-skill
description: What it does. When to use it.
disable-model-invocation: true    # Optional: user-only, /plugin-name:skill-name
---

Instructions for Claude when this skill is active.
```

Key frontmatter fields:
- `name` — Skill identifier
- `description` — CRITICAL: must include "what" and "when to use"
- `disable-model-invocation` — `true` = user must invoke manually
- `allowed-tools` — Auto-approved tools without permission prompts

Skills can include `references/` subdirectory for detailed documentation that Claude loads as needed.

### Commands (`commands/`)

Commands are user-invoked via `/plugin-name:command-name`. Each command is a markdown file.

```markdown
---
description: What this command does
---

Instructions for what Claude should do.

User input: $ARGUMENTS
```

Special variables:
- `$ARGUMENTS` — All text after the command name
- `$0`, `$1`, `$2` — Positional arguments
- `${CLAUDE_SESSION_ID}` — Current session ID

### Agents (`agents/`)

Specialized sub-agents that Claude can delegate tasks to. Each agent is a markdown file.

```markdown
---
name: security-reviewer
description: Reviews code for security vulnerabilities
model: opus
allowed-tools: Read, Grep, Glob
---

You are a security review agent. Analyze code for:
- OWASP Top 10 vulnerabilities
- Input validation issues
- Authentication/authorization flaws
```

### Hooks (`hooks/hooks.json`)

Event handlers that trigger at lifecycle points.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh"
          }
        ]
      }
    ],
    "PostToolUse": [...],
    "SessionStart": [...],
    "Stop": [...]
  }
}
```

Use `${CLAUDE_PLUGIN_ROOT}` to reference files within the plugin (plugins are cached, so absolute paths won't work).

### MCP Servers (`.mcp.json`)

External tool integrations via Model Context Protocol.

```json
{
  "mcpServers": {
    "my-server": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/my-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": {
        "API_KEY": "${API_KEY}"
      }
    }
  }
}
```

### LSP Servers (`.lsp.json`)

Language server integrations for code intelligence.

```json
{
  "go": {
    "command": "gopls",
    "args": ["serve"],
    "extensionToLanguage": {
      ".go": "go"
    }
  }
}
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Plugin name | kebab-case | `esky-deploy` |
| Skill folder | kebab-case | `code-review/` |
| Command file | kebab-case.md | `setup-env.md` |
| Agent file | kebab-case.md | `security-reviewer.md` |

## Important Rules

1. **Never put components inside `.claude-plugin/`** — only `plugin.json` goes there
2. **Plugins are cached** — use `${CLAUDE_PLUGIN_ROOT}` for internal file references, never absolute paths
3. **No `..` in paths** — plugins can't reference files outside their directory
4. **Symlinks are followed** — use symlinks to share files between plugins if needed
5. **Namespacing** — all commands/skills are prefixed: `/plugin-name:command-name`

## Example: Complete Plugin

```
esky-deploy/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── deployment-setup/
│       ├── SKILL.md
│       └── references/
│           └── dockerfile-reference.md
├── commands/
│   ├── setup.md
│   └── deploy.md
├── agents/
│   └── deployment-verifier.md
├── hooks/
│   └── hooks.json
├── scripts/
│   └── validate-helm.sh
└── README.md
```
