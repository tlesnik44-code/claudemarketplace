---
name: hook-master
description: Create, configure, and manage Claude Code hooks across user, project, and local scopes. Use when user wants to create a hook, add a PreToolUse/PostToolUse/SessionStart hook, configure hook matchers, set up permission hooks, block commands with hooks, auto-approve tools, manage hooks.json, or troubleshoot hooks. Trigger when user mentions "create hook", "add hook", "hook for", "PreToolUse", "PostToolUse", "block command", "auto-approve", "hook matcher", "permission hook", or wants to automate Claude Code behavior via hooks.
user-invocable: true
argument-hint: "[create|list|remove|explain] [event-name]"
allowed-tools: Read, Write, Edit, Bash(cat *), Bash(jq *), Bash(chmod *), Glob, Grep
---

# Hook Master

Create, configure, and manage Claude Code hooks.

## Documentation Freshness Check

Before doing any work, check the `Fetched:` date in [hooks-official-docs.md](references/hooks-official-docs.md).
- If older than **7 days** from today, re-fetch from `https://code.claude.com/docs/en/hooks` using WebFetch and update the reference file with fresh content and today's date.
- If within 7 days, proceed using the cached reference.

## Determine Intent

Based on `$ARGUMENTS` and user message:

| Intent | Action |
|--------|--------|
| `create` / "add hook" / "hook for X" | → **Create Hook** workflow |
| `list` / "show hooks" / "what hooks" | → **List Hooks** workflow |
| `remove` / "delete hook" | → **Remove Hook** workflow |
| `explain` / "how does" / "what is" | → **Explain** workflow |
| No clear intent | → Ask what they need |

---

## Create Hook Workflow

### Step 1: Gather Requirements

Ask (or infer from context):

1. **Event** — Which hook event? (PreToolUse, PostToolUse, SessionStart, Stop, UserPromptSubmit, etc.)
2. **Scope** — Where should it live?
   - `user` → `~/.claude/settings.json` (all projects)
   - `project` → `.claude/settings.json` (shared with team)
   - `local` → `.claude/settings.local.json` (personal, gitignored)
3. **Handler type** — `command`, `http`, `prompt`, or `agent`?
4. **Matcher** — Which tools/events to match? (e.g., `Bash`, `Edit|Write`, `mcp__.*`)
5. **Purpose** — Block, allow, log, modify, inject context?

If user provides enough context, skip questions and proceed.

### Step 2: Choose the Right Decision Pattern

Consult [hooks-official-docs.md](references/hooks-official-docs.md) for the correct output pattern:

| Event | Pattern | Key Fields |
|-------|---------|------------|
| `PreToolUse` | `hookSpecificOutput.permissionDecision` | `allow\|deny\|ask\|defer` |
| `PermissionRequest` | `hookSpecificOutput.decision` object | `behavior: allow\|deny` |
| `UserPromptSubmit`, `Stop`, `PostToolUse` | Top-level `decision` | `block` + `reason` |
| `PermissionDenied` | `hookSpecificOutput.retry` | `true\|false` |
| `WorktreeCreate` | stdout path / `hookSpecificOutput.worktreePath` | path string |
| `Elicitation` | `hookSpecificOutput.action` | `accept\|decline\|cancel` |

### Step 3: Build the Hook

For **command** hooks, create a bash script:

```bash
#!/bin/bash
# Read input JSON from stdin
INPUT=$(cat)

# Extract fields with jq
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Your logic here...

# Output decision as JSON (or just exit 0 for pass-through)
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Reason here"
  }
}'
```

**Exit code rules:**
- `exit 0` — success, parse stdout JSON
- `exit 2` — hard block (most reliable for enforcement), stderr goes to Claude
- `exit 1/3+` — non-blocking error, logged and skipped

**For hard blocks, prefer `exit 2`** — it blocks even if JSON generation fails. Use `exit 0` + JSON deny when you need structured feedback or conditional logic.

### Step 4: Register the Hook

Read the target settings file, merge the hook config, and write back.

**Target files by scope:**
- User: `~/.claude/settings.json`
- Project: `.claude/settings.json`
- Local: `.claude/settings.local.json`

**Structure:**
```json
{
  "hooks": {
    "EVENT_NAME": [
      {
        "matcher": "PATTERN",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/script-name.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

For command hooks, store scripts in `.claude/hooks/` and make them executable (`chmod +x`).

### Step 5: Validate

- Verify JSON is valid in the settings file
- Verify script is executable (command hooks)
- Verify matcher pattern is correct (exact vs regex)
- Suggest testing with `/hooks` menu

---

## List Hooks Workflow

1. Read all three settings files (user, project, local) if they exist
2. For each, extract the `hooks` key
3. Present a table:

```
| Scope   | Event        | Matcher     | Type    | Command/URL            |
|---------|-------------|-------------|---------|------------------------|
| user    | PreToolUse  | Bash        | command | ~/.claude/hooks/x.sh   |
| project | PostToolUse | Edit|Write  | http    | http://localhost:8080   |
```

Also mention: "Run `/hooks` in Claude Code for the full interactive view."

---

## Remove Hook Workflow

1. Ask which hook to remove (or infer from context)
2. Read the appropriate settings file
3. Remove the hook entry
4. Write back the updated settings
5. If a script file was associated, ask if it should be deleted too

---

## Explain Workflow

Use [hooks-official-docs.md](references/hooks-official-docs.md) to answer questions about:
- How specific events work
- What input JSON looks like for a given event
- What output JSON is expected
- Matcher syntax
- Exit code behavior
- Decision control patterns

Always cite the specific event documentation section.

---

## Common Hook Recipes

### Block destructive bash commands (exit 2 — hard block)

```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if echo "$COMMAND" | grep -qE 'rm -rf|drop table|truncate|format'; then
  echo "Destructive command blocked: $COMMAND" >&2
  exit 2
fi
exit 0
```

### Auto-approve safe read-only tools

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Read|Glob|Grep",
      "hooks": [{
        "type": "command",
        "command": "echo '{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\"}}'"
      }]
    }]
  }
}
```

### Inject context on session start

```bash
#!/bin/bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=development' >> "$CLAUDE_ENV_FILE"
fi
echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Project uses Node 20, pnpm, TypeScript strict mode."}}'
exit 0
```

### Log all tool usage (async, non-blocking)

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/log-tool.sh",
        "async": true
      }]
    }]
  }
}
```

### Conditional hook with `if`

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "if": "Bash(rm *)",
        "command": ".claude/hooks/confirm-delete.sh"
      }]
    }]
  }
}
```

---

## Key Rules

1. **Always use `"$CLAUDE_PROJECT_DIR"`** prefix for project-relative script paths in shared hooks
2. **Always `chmod +x`** script files
3. **Scripts must output only JSON to stdout** — no debug prints, no shell greeting messages
4. **Use `exit 2` for hard security blocks** — most reliable, no JSON parsing dependency
5. **Use `exit 0` + JSON for structured decisions** — when you need allow/deny/ask/defer with reasons
6. **Matcher precedence**: `deny` > `defer` > `ask` > `allow` (when multiple hooks fire)
7. **Test with `/hooks`** in Claude Code to verify configuration
