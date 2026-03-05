---
name: plugin-creator
description: Create a new Claude Code plugin in the marketplace. Use when creating plugins, adding new plugins to the marketplace, or scaffolding plugin structure with skills, commands, agents, hooks, or MCP servers.
argument-hint: "[plugin-name]"
allowed-tools: Read, Write, Edit, Bash(mkdir *), Bash(chmod *)
---

# Plugin Creator

You are creating a new plugin for the **esky-flightcontent-marketplace**. Follow this workflow exactly.

## Step 1: Gather Requirements

Ask the user for:
1. **Plugin name** (kebab-case, e.g. `my-awesome-plugin`) — use `$ARGUMENTS` if provided
2. **Description** — what does it do and when should it be used
3. **Category** — which directory: `devops`, `dotnet`, `ai-agents`, or `workflow`
4. **Components needed** (multi-select):
   - Skills (auto-invoked by Claude based on context)
   - Commands (user-invoked slash commands)
   - Agents (specialized sub-agents)
   - Hooks (event handlers for PreToolUse, PostToolUse, etc.)
   - MCP servers (external tool integrations)
   - LSP servers (language server protocol)

## Step 2: Scaffold the Plugin

Create the directory structure under `plugins/<category>/<plugin-name>/`:

```
plugins/<category>/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json           # Required — see references/plugin-json-reference.md
├── skills/                   # If skills selected
│   └── <skill-name>/
│       └── SKILL.md
├── commands/                 # If commands selected
│   └── <command-name>.md
├── agents/                   # If agents selected
│   └── <agent-name>.md
├── hooks/                    # If hooks selected
│   └── hooks.json
├── .mcp.json                 # If MCP servers selected
├── .lsp.json                 # If LSP servers selected
└── README.md                 # Always include
```

### plugin.json Template

```json
{
  "name": "<plugin-name>",
  "description": "<description>",
  "version": "1.0.0",
  "author": {
    "name": "Esky Group"
  },
  "keywords": []
}
```

### SKILL.md Template

```markdown
---
name: <skill-name>
description: <What it does>. <When to use it>.
---

<Instructions for Claude when this skill is active>
```

### Command .md Template

```markdown
---
description: <What this command does>
---

<Instructions for what Claude should do when this command is invoked>

User input: $ARGUMENTS
```

## Step 3: Register in Marketplace

Read the current `.claude-plugin/marketplace.json` and add a new entry to the `plugins` array:

```json
{
  "name": "<plugin-name>",
  "source": "./plugins/<category>/<plugin-name>",
  "description": "<description>",
  "version": "1.0.0",
  "category": "<category>",
  "tags": [],
  "keywords": []
}
```

Use `source` as `<category>/<plugin-name>` (relative to `pluginRoot` which is `./plugins`).

## Step 4: Create README.md

Include:
- Plugin name and description
- Installation command: `/plugin install <name>@esky-flightcontent-marketplace`
- Usage examples for each command/skill
- Directory structure diagram

## Step 5: Validate

After creating, run:
```bash
claude plugin validate .
```

If validation is not available, manually verify:
- `.claude-plugin/plugin.json` exists with valid JSON and required `name` field
- All SKILL.md files have valid frontmatter with `name` and `description`
- The marketplace.json entry source path matches the actual directory

## Reference Documentation

For detailed schemas and conventions, read these reference files:
- `references/plugin-json-reference.md` — Full plugin.json schema
- `references/marketplace-reference.md` — marketplace.json format and plugin entries
- `references/plugin-structure-reference.md` — Directory layout, naming, component types
