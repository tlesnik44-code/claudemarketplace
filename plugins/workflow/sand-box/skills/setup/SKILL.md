---
name: sand-box
description: >
  Create and activate a workspace sandbox that isolates Claude Code to a specific folder with
  configurable permissions. Use when the user says /sand-box, wants to sandbox a folder, isolate
  a workspace, restrict Claude's access to specific directories, or set up workspace security.
  Covers: workspace isolation, folder restriction, agent sandboxing, permission hooks, security boundaries, profiles.
---

# Sand-box Setup

**DO NOT explore the plugin directory. DO NOT search for scripts or files. Everything you need is below.**

The sand-box plugin is a single hook that reads config at runtime from two files:
- `~/.sand-box.json` — global config (profiles, user-scoped profiles, folder mappings)
- `<project>/.sand-box.json` — per-folder shared config (profile references + optional inline profile)

To configure it, edit these files. Nothing else. A PostToolUse validation hook checks your edits automatically.

## Global config schema: `~/.sand-box.json`

All three top-level fields are **required**.

```json
{
  "userProfiles": ["generic"],
  "profiles": {
    "generic": {
      "default": { "read": "allow", "write": "allow" },
      "allowedDomains": ["localhost", "127.0.0.1"],
      "scriptChecking": true,
      "paths": {},
      "tools": {}
    },
    "readonly": {
      "default": { "read": "allow", "write": "ask" },
      "paths": {
        "secrets": { "read": "deny", "write": "deny" }
      },
      "tools": {
        "Bash(rm *)": "deny",
        "Bash(ls *)": "allow",
        "Agent": "deny"
      }
    },
    "multi-repo": {
      "default": { "read": "allow", "write": "allow" },
      "allowedDomains": ["localhost", "127.0.0.1", "*.eskyspace.com"],
      "paths": {
        "/Users/tlesnik/repo/shared-lib": { "read": "allow", "write": "deny" },
        "/Users/tlesnik/repo/output": { "read": "allow", "write": "allow" },
        "TAJNE": { "read": "deny", "write": "deny" }
      },
      "tools": {
        "mcp__atlassian__getJiraIssue": "allow",
        "mcp__atlassian__edit*": "deny",
        "mcp__atlassian__*": "ask"
      }
    }
  },
  "foldersProfile": {
    "/Users/tlesnik/projects/my-app": "readonly",
    "/Users/tlesnik/projects/web": ["generic", "multi-repo"]
  }
}
```

### Global config fields

| Field | Type | Required | Description |
|---|---|---|---|
| `userProfiles` | `string[]` | Yes | Profile names that fire for EVERY session. Can be `[]`. |
| `profiles` | `object` | Yes | Profile definitions. Keys = names, values = profile config. |
| `foldersProfile` | `object` | Yes | Maps absolute folder paths to profile name(s). Value: `string` or `string[]`. Can be `{}`. |

### Profile config fields

| Field | Type | Default | Description |
|---|---|---|---|
| `default` | `{read, write}` | `{read:"allow",write:"allow"}` | Permission for workspace (pwd) folder. Values: `"allow"`, `"deny"`, `"ask"`. |
| `paths` | `object` | `{}` | Per-path read/write permissions. Keys: absolute (outside workspace) or relative (inside workspace). Values: `{"read":"allow\|deny\|ask","write":"allow\|deny\|ask"}`. |
| `tools` | `object` | `{}` | Per-tool permissions. Keys: tool patterns. Values: `"allow"`, `"deny"`, `"ask"`. See tool matching below. |
| `allowedDomains` | `string[]` | `["localhost","127.0.0.1"]` | Domains allowed in script network checks. Wildcards: `"*.example.com"`. |
| `scriptChecking` | `boolean` | `true` | Enable Haiku LLM script evaluation. |

### Tool matching patterns

| Pattern | Matches | Example |
|---|---|---|
| `"ToolName"` | Exact tool name | `"Agent"`, `"Read"`, `"Write"` |
| `"Bash(glob)"` | Bash commands matching glob | `"Bash(ls *)"`, `"Bash(rm *)"`, `"Bash(npm *)"` |
| `"name*"` | Wildcard on tool name | `"mcp__atlassian__*"`, `"mcp__*"` |
| `"A\|B\|C"` | Any of listed tools | `"Read\|Grep\|Glob"` |

Tool permission values: `allow` (tool OK, path checks still run), `deny` (immediate block), `ask` (prompt user).

### Permission precedence

Most restrictive wins across profiles: `deny` > `ask` > `allow`.

## Local config schema: `<project>/.sand-box.json`

```json
{
  "profile": {
    "default": { "read": "allow", "write": "ask" },
    "paths": { "secrets": { "read": "deny", "write": "deny" } },
    "tools": { "Bash(rm *)": "deny" }
  }
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `profile` | `object` | Yes | Inline profile definition (same schema as global profiles). Self-contained, no dependency on `~/.sand-box.json`. |

## Profile resolution order

All matching profiles fire. Most restrictive decision wins.

1. **userProfiles** from `~/.sand-box.json` (every session)
2. **foldersProfile** from `~/.sand-box.json` (if folder matches)
3. **profile** from `<project>/.sand-box.json` (inline definition, shared with team)

If zero profiles → hook exits, no protection.

## Evaluation order per tool call

1. **Tool rules** — deny/ask exits immediately. allow = continue to path checks.
2. **Hardcoded rules** — system security, sensitive files, protected files (always win).
3. **Path rules** — per-path read/write from profiles.
4. **Workspace default** — profile `default.read`/`default.write` for pwd files.
5. **Outside workspace** — denied.

## What to do

### Create a profile
1. Read `~/.sand-box.json` (create with empty schema if missing)
2. Add profile under `.profiles.<name>`
3. Write back

### Sandbox a folder
1. Read `~/.sand-box.json`
2. Add folder under `.foldersProfile.<absolute-path>`
3. Write back

### Set user-scoped profiles
1. Read `~/.sand-box.json`
2. Set `.userProfiles` array
3. Write back

### Shared/team config
1. Create `<project>/.sand-box.json` with inline `profile` object
