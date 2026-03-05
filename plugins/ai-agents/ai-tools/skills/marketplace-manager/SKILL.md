---
name: marketplace-manager
description: Manage Claude Code plugin marketplaces and install plugins for any AI agent (Claude, Cursor, Windsurf, Augment, Codex). Use when downloading/adding marketplaces, listing/viewing/installing/uninstalling/updating plugins, or converting plugin skills to native agent rules for non-Claude environments.
allowed-tools: Bash, Read, Glob, Grep, Write, Edit
---

# Marketplace Manager

Portable plugin marketplace client for all AI coding agents. Provides the same capabilities as Claude Code's `/plugin` commands through filesystem operations and a CLI script.

## Script Location

All operations are available via the helper script:

```bash
.claude/skills/marketplace-manager/scripts/marketplace.sh
```

Run `marketplace.sh help` to see all commands.

## Quick Reference

```bash
SCRIPT=".claude/skills/marketplace-manager/scripts/marketplace.sh"

# Marketplace operations
$SCRIPT marketplace add <git-url>          # Clone and register a marketplace
$SCRIPT marketplace update [<name>]        # Pull latest from remote
$SCRIPT marketplace list                   # Show all registered marketplaces
$SCRIPT marketplace remove <name>          # Unregister and delete marketplace

# Plugin operations
$SCRIPT plugins [<marketplace>]            # List available plugins
$SCRIPT view <plugin>[@<marketplace>]      # Show plugin details and skills
$SCRIPT install <plugin>[@<marketplace>] [--agent <agent>] [--target <dir>]
$SCRIPT uninstall <plugin> [--agent <agent>] [--target <dir>]
$SCRIPT update-plugin <plugin>[@<marketplace>] [--agent <agent>] [--target <dir>]
```

Agent values: `claude`, `augment`, `cursor`, `windsurf`, `codex`, `all`

## How It Works

### State Directory

All state is stored in `.ai-marketplace/` at the project root:

```
.ai-marketplace/
├── config.json          # Registered marketplaces
├── installed.json       # Installed plugin tracking
└── sources/             # Cloned marketplace repositories
    └── <marketplace-name>/
```

### Local Marketplace Detection

If the current repository contains `.claude-plugin/marketplace.json`, it is automatically registered as a local marketplace. No `add` step needed — plugins from the local marketplace are immediately available.

### Agent Auto-Detection

When `--agent` is omitted, the script detects the current agent:
1. `.cursor/` exists → cursor
2. `.windsurf/` exists → windsurf
3. `.augment/` exists → augment
4. `.claude/` exists → claude
5. Falls back to → codex (AGENTS.md)

You can always override with `--agent <name>`.

## Marketplace Operations

### Add a Marketplace

```bash
$SCRIPT marketplace add https://github.com/eskygroup/esky-ai-knowledge-base
```

Clones the repository, reads `.claude-plugin/marketplace.json`, and registers it by name.

### Update a Marketplace

```bash
$SCRIPT marketplace update                              # Update all
$SCRIPT marketplace update esky-flightcontent-marketplace  # Update specific
```

Runs `git pull` in the cloned source directory.

### List Marketplaces

```bash
$SCRIPT marketplace list
```

Shows all registered marketplaces (both local and remote).

### Remove a Marketplace

```bash
$SCRIPT marketplace remove esky-flightcontent-marketplace
```

Unregisters and deletes the cloned source. Does not uninstall already-installed plugins.

## Plugin Operations

### List Plugins

```bash
$SCRIPT plugins                                  # All marketplaces
$SCRIPT plugins esky-flightcontent-marketplace    # Specific marketplace
```

Displays a table of available plugins with name, version, category, and description.

### View Plugin Details

```bash
$SCRIPT view esky-devops
$SCRIPT view esky-devops@esky-flightcontent-marketplace
```

Shows plugin.json metadata, README content, and lists all skills with descriptions.

### Install a Plugin

```bash
$SCRIPT install esky-devops                          # Auto-detect agent
$SCRIPT install esky-devops --agent cursor            # Specific agent
$SCRIPT install esky-devops --agent all               # All agents
$SCRIPT install esky-devops --agent cursor --target ~/my-project
```

For Claude: copies the plugin directory to `.claude/plugins/`.
For other agents: converts each skill's SKILL.md to the agent's native rule format.

### Uninstall a Plugin

```bash
$SCRIPT uninstall esky-devops                        # Auto-detect agent
$SCRIPT uninstall esky-devops --agent cursor
```

Removes the installed rule files for the specified plugin and agent.

### Update a Plugin

```bash
$SCRIPT update-plugin esky-devops                    # Re-install from source
```

Equivalent to uninstall + install. Updates the marketplace source first if remote.

## Installation Formats by Agent

| Agent | Output Location | File Format | Limits |
|-------|----------------|-------------|--------|
| Claude | `.claude/plugins/<plugin>/` | Full plugin copy | None |
| Augment | `.augment/rules/` | `<plugin>--<skill>.md` | 49K total |
| Cursor | `.cursor/rules/` | `<plugin>--<skill>.mdc` | None |
| Windsurf | `.windsurf/rules/` | `<plugin>--<skill>.md` | 6K per file |
| Codex | `AGENTS.md` | Appended sections | 32K total |

### What Transfers

- Skill name, description, and instruction body
- Reference file content (inlined where space permits)
- Script documentation (paths sanitized)

### What Doesn't Transfer

- `allowed-tools` — no equivalent in other agents
- `context: fork` / `agent` — Claude subagent feature
- Dynamic context `!` — only Claude executes these
- Tool-specific permissions — agent-specific

## Manual Operations (Without Script)

If the script is not available, perform operations manually:

### List Plugins Manually

Read `.claude-plugin/marketplace.json` and parse the `plugins` array. Each entry has `name`, `description`, `version`, `category`, and `source` (path to plugin directory).

### Install Plugin Manually

1. Locate plugin source via `source` field in marketplace.json
2. Read each `skills/*/SKILL.md` in the plugin
3. Parse YAML frontmatter (`name`, `description`)
4. Extract body content (everything after second `---`)
5. Write in target agent format (see [agent-formats.md](references/agent-formats.md))

### Marketplace JSON Schema

See [marketplace-schema.md](references/marketplace-schema.md) for the complete marketplace.json and plugin.json schemas.

## Examples

```bash
SCRIPT=".claude/skills/marketplace-manager/scripts/marketplace.sh"

# Full workflow: add marketplace, browse, install
$SCRIPT marketplace add https://github.com/eskygroup/esky-ai-knowledge-base
$SCRIPT plugins
$SCRIPT view esky-devops
$SCRIPT install esky-devops --agent cursor

# Install all plugins for all agents
$SCRIPT plugins | # review what's available
$SCRIPT install esky-devops --agent all
$SCRIPT install esky-dotnet --agent all

# Update everything
$SCRIPT marketplace update
$SCRIPT update-plugin esky-devops --agent cursor
```

## Prerequisites

- `git` — for cloning marketplace repositories
- `jq` — for JSON parsing (install: `brew install jq` / `apt install jq`)
