---
name: claude-profile
description: Show active Claude Code profile and guide profile switching. Use when user asks about profiles, wants to switch profiles, or manage Claude Code configurations.
user-invocable: true
allowed-tools: Bash, Read
argument-hint: "[list|capture <name>|use <name>|install]"
---

# Claude Profile Manager

You help the user manage their Claude Code profiles using `clp` (Claude Profile).

## First: Check if clp is installed

Run: `command -v clp`

If not found, tell the user:
```
clp is not installed. Run /claude-profile install to set it up.
```

If the argument is `install`, run:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/clp.sh install
```
Then stop.

## Show current state

Detect the current profile from the environment:
```bash
if [[ "${CLAUDE_CONFIG_DIR:-}" =~ clp/profiles/([^/]+) ]]; then
  echo "Current profile: ${BASH_REMATCH[1]}"
else
  echo "Current profile: default (no clp profile active)"
fi
ls ~/.clp/profiles/ 2>/dev/null || echo "No profiles"
cat ~/.clp/commands 2>/dev/null
```

Display the results clearly:
- Current profile (derived from `CLAUDE_CONFIG_DIR`, not from `.active`)
- Available profiles
- Named commands (if any)

## Handle arguments

- **No argument or `list`**: Show current state (above)
- **`capture <name>`**: Run `clp capture <name>` — this copies the current config as a profile (safe to run from within a session, does not kill sessions or switch anything)
- **`use <name>`**: Do NOT run `clp use` directly — it kills all Claude sessions. Instead:
  1. Show the user the command they need to run manually: `clp use <name>`
  2. Warn them: "This will terminate all running Claude Code sessions. Run this command in a separate terminal."
- **`use <name> <command>`**: Run `clp use <name> <command>` — this creates a named wrapper and is safe (doesn't kill sessions)
- **`install`**: Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/clp.sh install`, then follow the **Initial Profile Capture** and **Status Line Setup** steps below

## Initial Profile Capture

After `install` completes, offer to capture the current configuration as a profile to finalize the setup.

1. Propose a profile name based on context — check the git remote, organization name, or directory name to suggest something meaningful (e.g., `work`, `personal`, `client-acme`). Fall back to `default` if nothing better fits.
2. Ask the user: "Would you like to capture your current configuration as a profile? Suggested name: **<name>**"
3. If they agree (with the suggested name or their own), run:
   ```bash
   clp capture <name>
   ```
4. After capture, inform the user they need to activate it with `clp use <name>` or create a named command with `clp use <name> <command>` from a separate terminal.

## Status Line Setup

After profile capture (or if skipped), ask the user:

> Would you like to display the active profile in the Claude Code status line?

### If no existing status line is configured

Check `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json` for a `statusLine` key.

If **not present**, offer to set it up:
1. Copy the statusline script:
```bash
cp "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline-command.sh"
```
2. Add to settings.json:
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```
3. Tell the user: "Status line configured. Restart Claude Code to see it."

### If a status line already exists

If `statusLine` is **already configured**, read the existing command script to check if it already includes profile display logic (look for `clp/profiles` or `_profile_raw` or `profile_badge`).

- If **profile display is already present**: inform the user — no changes needed.
- If **profile display is missing**: ask the user if they'd like to add profile badge display to their existing status line script. If they agree, read their current script and add the profile badge section from `${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh` (the block from "Profile badge" to the `profile_badge` printf). Preserve all existing functionality.

## Important

- NEVER run `clp use <name>` (without a command name) from within a Claude session — it will kill this session
- `clp use <name> <command>` is safe — it creates a named wrapper without switching the active profile
- Profile switching (`clp use`) must be done from an external terminal
