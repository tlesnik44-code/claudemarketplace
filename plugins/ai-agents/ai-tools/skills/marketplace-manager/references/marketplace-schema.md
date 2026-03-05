# Marketplace & Plugin JSON Schemas

## marketplace.json

Located at `.claude-plugin/marketplace.json` in the repository root.

```json
{
  "name": "marketplace-name",
  "owner": { "name": "Organization Name" },
  "metadata": {
    "description": "Marketplace description",
    "version": "1.0.0",
    "pluginRoot": "./plugins/"
  },
  "plugins": [
    {
      "name": "plugin-name",
      "source": "./plugins/category/plugin-name",
      "description": "What this plugin does",
      "version": "1.0.0",
      "category": "devops|dotnet|ai-agents|workflow",
      "tags": ["tag1", "tag2"],
      "keywords": ["keyword1", "keyword2"]
    }
  ]
}
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Marketplace identifier (kebab-case) |
| `owner` | object | `{ "name": "..." }` — maintainer info |
| `plugins` | array | List of plugin entries |

### Plugin Entry — Required

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Plugin identifier, must match plugin.json `name` |
| `source` | string/object | Where to find the plugin |

### Plugin Entry — Optional

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | Plugin description |
| `version` | string | Semantic version |
| `category` | string | Category for organization |
| `tags` | array | Tags for filtering |
| `keywords` | array | Keywords for discovery |
| `homepage` | string | Documentation URL |
| `repository` | string | Source repo URL |
| `license` | string | SPDX identifier |

### Source Types

**Relative path** (plugins in same repo):
```json
{ "source": "./plugins/category/plugin-name" }
```

**GitHub repository** (external):
```json
{ "source": { "source": "github", "repo": "owner/repo", "ref": "v1.0.0" } }
```

**Git URL** (any git host):
```json
{ "source": { "source": "url", "url": "https://gitlab.com/team/plugin.git" } }
```

---

## plugin.json

Located at `<plugin-dir>/.claude-plugin/plugin.json`.

```json
{
  "name": "plugin-name",
  "description": "Brief description",
  "version": "1.0.0",
  "author": { "name": "Organization" },
  "keywords": ["keyword1", "keyword2"]
}
```

### Required

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Plugin identifier (kebab-case, becomes namespace) |

### Recommended

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | Brief description (under 100 chars) |
| `version` | string | Semantic version (MAJOR.MINOR.PATCH) |
| `author` | object | `{ "name": "...", "email": "..." }` |

---

## Plugin Directory Structure

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json        # REQUIRED — plugin manifest
├── skills/                # Agent skills
│   └── skill-name/
│       ├── SKILL.md       # Skill definition with YAML frontmatter
│       └── references/    # Optional detailed docs
├── commands/              # User-invoked slash commands
│   └── command.md
├── agents/                # Specialized sub-agents
│   └── agent.md
├── hooks/                 # Event handlers
│   └── hooks.json
├── scripts/               # Executable utilities
├── .mcp.json              # MCP server config
├── .lsp.json              # LSP server config
└── README.md              # Plugin documentation
```

Only `.claude-plugin/plugin.json` is required. All other directories are optional.

## SKILL.md Format

```yaml
---
name: skill-name
description: What it does. When to use it.
disable-model-invocation: false
user-invocable: true
allowed-tools: Bash, Read
---

Markdown instructions for the agent.
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (kebab-case) |
| `description` | Recommended | What + when to use |
| `disable-model-invocation` | No | `true` = user must invoke manually |
| `user-invocable` | No | `false` = agent-only (hidden from user) |
| `allowed-tools` | No | Auto-approved tools (Claude-specific) |
| `context` | No | `fork` = run as subagent (Claude-specific) |
| `agent` | No | Subagent type when `context: fork` |
