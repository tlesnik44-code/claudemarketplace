# Claude Code Hooks — Official Documentation Reference

> **Fetched:** 2026-04-10
> **Source:** https://code.claude.com/docs/en/hooks
> **Refresh policy:** If this date is older than 7 days, re-fetch from source before using.

---

## Hook Lifecycle & Events

Hooks fire at specific points in Claude Code's lifecycle:

| Cadence | Events |
|---------|--------|
| Session-level (once) | `SessionStart`, `SessionEnd` |
| Turn-level (once per prompt) | `UserPromptSubmit`, `Stop`, `StopFailure` |
| Tool-level (per call) | `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied` |
| Async | `WorktreeCreate`, `WorktreeRemove`, `Notification`, `ConfigChange`, `InstructionsLoaded`, `CwdChanged`, `FileChanged` |
| MCP-specific | `Elicitation`, `ElicitationResult` |
| Agent-specific | `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `PreCompact`, `PostCompact` |

---

## Configuration Scopes

| Location | Scope | Shareable |
|----------|-------|-----------|
| `~/.claude/settings.json` | All projects (user) | No |
| `.claude/settings.json` | Single project | Yes |
| `.claude/settings.local.json` | Single project | No (gitignored) |
| Managed policy settings | Organization-wide | Yes |
| Plugin `hooks/hooks.json` | When plugin enabled | Yes |
| Skill/Agent frontmatter | When component active | Yes |

---

## Configuration Structure

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "pattern",
        "hooks": [
          {
            "type": "command|http|prompt|agent",
            "if": "PermissionRule(optional)",
            "timeout": 600,
            "statusMessage": "Custom message",
            "once": false
          }
        ]
      }
    ],
    "disableAllHooks": false
  }
}
```

---

## Matcher Patterns

| Pattern | Evaluated as | Examples |
|---------|--------------|----------|
| `"*"`, `""`, or omitted | Match all | Fires on every event |
| Letters, digits, `_`, `\|` only | Exact string or `\|`-separated list | `Bash`, `Edit\|Write` |
| Contains other characters | JavaScript regex | `^Notebook`, `mcp__memory__.*` |

### Event-Specific Matchers

| Event | Matches Against | Examples |
|-------|-----------------|----------|
| Tool events | Tool name | `Bash`, `Edit\|Write`, `mcp__.*` |
| `SessionStart` | Session source | `startup`, `resume`, `clear`, `compact` |
| `SessionEnd` | End reason | `clear`, `resume`, `logout`, `bypass_permissions_disabled` |
| `Notification` | Notification type | `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog` |
| `SubagentStart`/`SubagentStop` | Agent type | `Bash`, `Explore`, `Plan`, custom |
| `PreCompact`/`PostCompact` | Trigger | `manual`, `auto` |
| `ConfigChange` | Config source | `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills` |
| `FileChanged` | Literal filenames | `.envrc\|.env` |
| `StopFailure` | Error type | `rate_limit`, `authentication_failed`, `billing_error`, `invalid_request`, `server_error`, `max_output_tokens`, `unknown` |
| `InstructionsLoaded` | Load reason | `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact` |
| `Elicitation`/`ElicitationResult` | MCP server name | configured server names |
| No matcher support | Always fire | `UserPromptSubmit`, `Stop`, `TeammateIdle`, `TaskCreated`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove`, `CwdChanged` |

### MCP Tool Naming

MCP tools follow: `mcp__<server>__<tool>` — match all from server: `mcp__memory__.*`

---

## Hook Handler Types

### 1. Command

```json
{
  "type": "command",
  "command": "sh /path/to/script.sh",
  "shell": "bash|powershell",
  "async": false,
  "timeout": 600,
  "if": "PermissionRule"
}
```

- Input: JSON via stdin
- Output: exit code + stdout (JSON) + stderr

### 2. HTTP

```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks/path",
  "headers": { "Authorization": "Bearer $MY_TOKEN" },
  "allowedEnvVars": ["MY_TOKEN"],
  "timeout": 30
}
```

- Input: JSON as POST body (`Content-Type: application/json`)
- Output: HTTP response body (JSON)
- 2xx = success, non-2xx = non-blocking error
- To block: return 2xx with `{decision: "block"}` or permission decision

### 3. Prompt

```json
{
  "type": "prompt",
  "prompt": "Evaluate: $ARGUMENTS",
  "model": "fast-model",
  "timeout": 30
}
```

- Single-turn LLM evaluation, returns yes/no as JSON
- `$ARGUMENTS` replaced with hook input JSON

### 4. Agent

```json
{
  "type": "agent",
  "prompt": "Verify: $ARGUMENTS",
  "model": "optional-override",
  "timeout": 60
}
```

- Spawns subagent with tool access (Read, Grep, Glob, etc.)
- For complex validation

---

## Environment Variables

| Variable | Available In | Purpose |
|----------|-------------|---------|
| `$CLAUDE_PROJECT_DIR` | All hooks | Project root |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin hooks | Plugin directory |
| `${CLAUDE_PLUGIN_DATA}` | Plugin hooks | Plugin persistent data |
| `$CLAUDE_ENV_FILE` | SessionStart, CwdChanged, FileChanged | Persist env vars |
| `$CLAUDE_CODE_REMOTE` | All hooks | "true" in remote web environments |

---

## Common Input Fields (stdin / POST body)

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/dir",
  "permission_mode": "default|plan|acceptEdits|auto|dontAsk|bypassPermissions",
  "hook_event_name": "EventName",
  "agent_id": "optional",
  "agent_type": "optional"
}
```

---

## Common Output Fields (stdout / response body)

```json
{
  "continue": true,
  "stopReason": "Message when continue=false",
  "suppressOutput": false,
  "systemMessage": "Warning message to user",
  "hookSpecificOutput": {
    "hookEventName": "EventName"
  }
}
```

**Output size limit:** 10,000 characters (excess saved to file).

---

## Exit Code Behavior (Command Hooks)

| Exit Code | Meaning | JSON | Action |
|-----------|---------|------|--------|
| 0 | Success | Parse stdout | Proceed |
| 2 | Blocking error | Ignored | Block (event-dependent) |
| 1, 3+ | Non-blocking error | Ignored | Continue, log stderr |

### Exit 2 Blocking Per Event

| Event | Blocks? | Effect |
|-------|---------|--------|
| `PreToolUse` | Yes | Blocks tool call |
| `PermissionRequest` | Yes | Denies permission |
| `UserPromptSubmit` | Yes | Blocks & erases prompt |
| `Stop` | Yes | Prevents stopping |
| `SubagentStop` | Yes | Prevents subagent stop |
| `TeammateIdle` | Yes | Prevents idle |
| `TaskCreated` | Yes | Rolls back task |
| `TaskCompleted` | Yes | Prevents completion |
| `ConfigChange` | Yes | Blocks config (except policy) |
| `Elicitation` | Yes | Denies elicitation |
| `ElicitationResult` | Yes | Blocks → decline |
| `WorktreeCreate` | Yes | Any non-zero fails |
| `StopFailure` | No | Ignored |
| `PostToolUse` | No | stderr to Claude |
| `PostToolUseFailure` | No | stderr to Claude |
| `PermissionDenied` | No | Use JSON for retry |
| Others | No | stderr to user |

---

## Decision Control Patterns

### Pattern 1: Top-Level `decision`

Used by: `UserPromptSubmit`, `PostToolUse`, `PostToolUseFailure`, `Stop`, `SubagentStop`, `ConfigChange`

```json
{ "decision": "block", "reason": "Explanation" }
```

### Pattern 2: PreToolUse `permissionDecision`

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask|defer",
    "permissionDecisionReason": "Why",
    "updatedInput": { "modified": "fields" },
    "additionalContext": "Context for Claude"
  }
}
```

- `allow` — skip permission prompt (deny/ask rules still apply)
- `deny` — prevent tool call
- `ask` — prompt user for confirmation
- `defer` — exit gracefully, tool resumes later (requires `-p` flag)

Multiple hook precedence: `deny` > `defer` > `ask` > `allow`

### Pattern 3: PermissionRequest `decision` Object

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow|deny",
      "updatedInput": { "modified": "input" },
      "updatedPermissions": [{
        "type": "addRules|replaceRules|removeRules|setMode|addDirectories|removeDirectories",
        "rules": [{"toolName": "Bash", "ruleContent": "pattern"}],
        "behavior": "allow|deny|ask",
        "destination": "session|localSettings|projectSettings|userSettings"
      }],
      "message": "Why denied"
    }
  }
}
```

### Pattern 4: PermissionDenied `retry`

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionDenied",
    "retry": true
  }
}
```

### Pattern 5: WorktreeCreate Path Return

Command: print path to stdout. HTTP: `hookSpecificOutput.worktreePath`

### Pattern 6: Elicitation Control

```json
{
  "hookSpecificOutput": {
    "hookEventName": "Elicitation",
    "action": "accept|decline|cancel",
    "content": { "field": "value" }
  }
}
```

---

## Detailed Event Input/Output

### SessionStart

**Matchers:** `startup`, `resume`, `clear`, `compact`

Input:
```json
{ "source": "startup|resume|clear|compact", "model": "claude-sonnet-4-6" }
```

Output:
```json
{
  "additionalContext": "Context for Claude",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "More context"
  }
}
```

Special: `$CLAUDE_ENV_FILE` for persisting env vars.

### UserPromptSubmit

**No matchers** (always fires). **Blocking: Yes.**

Input:
```json
{ "prompt": "User's text" }
```

Output:
```json
{
  "decision": "block",
  "reason": "Why blocked",
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Context for Claude",
    "sessionTitle": "Auto-generated title"
  }
}
```

### PreToolUse

**Matchers:** Tool names. **Blocking: Yes.**

Input (examples):

```json
// Bash
{ "tool_name": "Bash", "tool_input": { "command": "npm test", "description": "Run tests", "timeout": 120000, "run_in_background": false }, "tool_use_id": "toolu_01ABC..." }

// Write
{ "tool_name": "Write", "tool_input": { "file_path": "/path/to/file.txt", "content": "content" }, "tool_use_id": "toolu_01ABC..." }

// Edit
{ "tool_name": "Edit", "tool_input": { "file_path": "/path/to/file.txt", "old_string": "original", "new_string": "replacement", "replace_all": false }, "tool_use_id": "toolu_01ABC..." }

// Read
{ "tool_name": "Read", "tool_input": { "file_path": "/path/to/file.txt", "offset": 10, "limit": 50 }, "tool_use_id": "toolu_01ABC..." }

// Agent
{ "tool_name": "Agent", "tool_input": { "prompt": "Find all API endpoints", "description": "Find API endpoints", "subagent_type": "Explore", "model": "sonnet" }, "tool_use_id": "toolu_01ABC..." }
```

### PostToolUse

**Matchers:** Tool names. **Non-blocking.**

Input:
```json
{ "tool_name": "Write", "tool_input": { "file_path": "/path", "content": "..." }, "tool_response": { "filePath": "/path", "success": true }, "tool_use_id": "toolu_01ABC..." }
```

Output:
```json
{ "decision": "block", "reason": "Feedback", "hookSpecificOutput": { "hookEventName": "PostToolUse", "additionalContext": "...", "updatedMCPToolOutput": "Replacement for MCP tools only" } }
```

### PostToolUseFailure

Input:
```json
{ "tool_name": "Bash", "tool_input": { "command": "npm test" }, "tool_use_id": "toolu_01ABC...", "error": "Command exited with non-zero status code 1", "is_interrupt": false }
```

### PermissionRequest

**Matchers:** Tool names. **Blocking: Yes.**

Input:
```json
{
  "tool_name": "Bash",
  "tool_input": { "command": "rm -rf node_modules" },
  "permission_suggestions": [{
    "type": "addRules",
    "rules": [{"toolName": "Bash", "ruleContent": "rm -rf node_modules"}],
    "behavior": "allow",
    "destination": "localSettings"
  }]
}
```

### PermissionDenied

**Matchers:** Tool names. **Non-blocking.** Only in `auto` mode.

Input:
```json
{ "tool_name": "Bash", "tool_input": { "command": "rm -rf /tmp/build" }, "tool_use_id": "toolu_01ABC...", "reason": "Auto mode denied: command targets a path outside the project" }
```

### Stop

**No matchers. Blocking: Yes.**

Output:
```json
{ "decision": "block", "reason": "Continue because...", "hookSpecificOutput": { "hookEventName": "Stop", "additionalContext": "..." } }
```

### StopFailure

**Matchers:** Error type (`rate_limit`, `authentication_failed`, `billing_error`, `invalid_request`, `server_error`, `max_output_tokens`, `unknown`). **Non-blocking** (output/exit ignored).

### Notification

**Matchers:** `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`. **Non-blocking.**

Input:
```json
{ "message": "Claude needs your permission...", "title": "Permission needed", "notification_type": "permission_prompt" }
```

### SubagentStart / SubagentStop

**Matchers:** Agent type. SubagentStop is **blocking** (uses Stop pattern).

### TaskCreated / TaskCompleted

**No matchers. Blocking: Yes.**

### TeammateIdle

**No matchers. Blocking: Yes.**

### CwdChanged

**No matchers. Non-blocking.** `$CLAUDE_ENV_FILE` available.

Input:
```json
{ "old_cwd": "/path/to/old", "new_cwd": "/path/to/new" }
```

### FileChanged

**Matchers:** Literal filenames. **Non-blocking.** `$CLAUDE_ENV_FILE` available.

Input:
```json
{ "file_path": "/path/to/file", "change_type": "created|modified|deleted" }
```

### WorktreeCreate / WorktreeRemove

**No matchers.** Create is **blocking** (any non-zero fails). Remove is **non-blocking.**

### ConfigChange

**Matchers:** Config source. **Blocking** (except `policy_settings`).

### InstructionsLoaded

**Matchers:** Load reason. **Non-blocking** (observability only).

### Elicitation / ElicitationResult

**Matchers:** MCP server name. **Blocking: Yes.**

### PreCompact / PostCompact

**Matchers:** `manual`, `auto`. **Non-blocking.**

### SessionEnd

**Matchers:** End reason. **Non-blocking.**

---

## `if` Conditional Execution

```json
{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "if": "Bash(rm *)",
    "command": "/path/to/block-rm.sh"
  }]
}
```

Only runs hook if the `if` permission rule matches.

---

## Async Hooks

```json
{ "type": "command", "command": "/path/to/script.sh", "async": true }
```

Runs without blocking. Non-blocking error on failure.

---

## Disable All Hooks

```json
{ "disableAllHooks": true }
```

Managed `disableAllHooks` cannot be overridden by user/project settings.

---

## Permission Mode Reference

| Mode | Description |
|------|-------------|
| `default` | Ask user for each tool |
| `plan` | Ask before major changes |
| `acceptEdits` | Auto-approve file edits |
| `auto` | Classifier decides |
| `dontAsk` | Auto-approve all but destructive |
| `bypassPermissions` | No prompts |

---

## Troubleshooting

- **JSON validation failed** — check shell profile doesn't print on startup; stdout must be only JSON
- **Hook not running** — check matcher (regex vs exact), `if` condition, use `/hooks` to inspect
- **Commands not executing** — verify exit 0/2, check stderr, use `--debug`
