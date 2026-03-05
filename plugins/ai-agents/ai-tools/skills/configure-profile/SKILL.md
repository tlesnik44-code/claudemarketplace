---
name: configure-profile
description: Create and configure a new Claude Code profile with separate login and statusline badge. Use when the user wants to set up a new Claude Code profile, add a second account, create an alias for another Claude login, or configure multiple Claude Code identities.
argument-hint: [profile-name]
disable-model-invocation: true
allowed-tools: Bash(mkdir *), Bash(cp *), Bash(security *), Bash(echo *), Bash(source *), Bash(ls *), Read, Edit, Write, AskUserQuestion
---

# Configure a New Claude Code Profile

Set up a new Claude Code profile with its own login, config directory, shell alias, and statusline badge.

## Step 1: Gather Information

Use AskUserQuestion to ask the user for the following (ask all at once):

1. **Alias name**: What shell alias to use (e.g., `claude-p`, `claude-work2`). If `$ARGUMENTS` is provided, use it as the default suggestion.
2. **Config path**: Where to store the config. Propose `~/.claude-<profile-name>` based on the alias (e.g., alias `claude-p` -> path `~/.claude-personal`). Let user customize.
3. **Badge label**: Text to show in the statusline badge (e.g., `PERSONAL`, `WORK`, `CLIENT`). Uppercase.
4. **Badge color**: Background color for the badge. Offer these options:
   - Green (recommended for personal) - ANSI code `42`
   - Magenta/Pink (recommended for work) - ANSI code `45`
   - Blue - ANSI code `44`
   - Yellow - ANSI code `43`
   - Red - ANSI code `41`
   - Cyan - ANSI code `46`

## Step 2: Create Config Directory

```bash
mkdir -p <config_path>
```

Copy settings and resources from `~/.claude/` (but NOT credentials):

```bash
cp ~/.claude/settings.json <config_path>/
cp ~/.claude/settings.local.json <config_path>/ 2>/dev/null
cp ~/.claude/statusline-command.sh <config_path>/ 2>/dev/null
cp -r ~/.claude/plugins <config_path>/ 2>/dev/null
cp -r ~/.claude/skills <config_path>/ 2>/dev/null
```

## Step 3: Update Statusline Badge

The statusline is configured in `~/.claude/statusline-command.sh` (global — used by all profiles). It detects the active profile via `CLAUDE_CONFIG_DIR` env var.

Find the profile badge section and add an `elif` for the new profile BEFORE the `else` (default) block:

```bash
elif [[ "$CLAUDE_CONFIG_DIR" == *"<config_dir_name>"* ]]; then
    if [ -n "$sub_label" ]; then
        profile_badge=$(printf "\033[1;97;<ansi_bg_code>m <BADGE_LABEL> · %s \033[0m" "$sub_label")
    else
        profile_badge=$(printf "\033[1;97;<ansi_bg_code>m <BADGE_LABEL> \033[0m")
    fi
```

Where:
- `<config_dir_name>` is the directory name from the config path (e.g., `claude-personal`)
- `<ansi_bg_code>` is the ANSI background color code chosen by the user
- `<BADGE_LABEL>` is the uppercase badge text chosen by the user

## Step 4: Add Shell Alias

Detect the user's shell rc file (`~/.zshrc` or `~/.bashrc`). Add the alias:

```bash
alias <alias_name>="CLAUDE_CONFIG_DIR=<config_path> claude"
```

Add it near any existing `claude` aliases if present, otherwise at the end of the file.

## Step 5: Login & Verify

Tell the user to run:

```bash
source ~/.zshrc  # or ~/.bashrc
<alias_name> login
```

Then verify with:

```bash
<alias_name> whoami
```

## Step 6: Summary

Print a summary of what was configured:
- Alias: `<alias_name>`
- Config path: `<config_path>`
- Badge: `<BADGE_LABEL>` with chosen color
- Shell rc updated: `~/.zshrc` or `~/.bashrc`
- Next step: run `<alias_name> login` to authenticate
