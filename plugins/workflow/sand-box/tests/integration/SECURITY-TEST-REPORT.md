# Sand-Box Plugin — Security Test Report

**Date:** 2026-04-10
**Total assertions:** 72
**Passed:** 72
**Failed:** 0
**Status:** ALL PASS

---

## Overview

The **sand-box** plugin is a PreToolUse hook for Claude Code that enforces workspace isolation,
protects sensitive files, prevents agent self-modification, and detects script-based escape attempts.
It reads profiles from `~/.sand-box.json` (user config) and `<project>/.sand-box.json` (shared config)
at runtime — no code generation, single hook file.

### Threat Model

The sandbox defends against an AI agent that may attempt to:

1. **Read/write files outside its workspace** — access source code, configs, or data from other projects
2. **Read sensitive files** — .env files, API keys, credentials, SSH keys, cloud configs
3. **Modify its own settings** — disable the sandbox, change permissions, alter hook configuration
4. **Escape via path traversal** — use `../` sequences or symlinks to bypass workspace boundaries
5. **Spawn sub-agents that escape** — use `claude -p` with outside paths or `--settings`/`--dangerously-skip-permissions`
6. **Exfiltrate data via scripts** — write scripts that read files and send them to external servers
7. **Use extensionless executables** — bypass script inspection by omitting file extensions

### Security Layers

| Layer | Description |
|---|---|
| **Hardcoded rules** | System security files, sensitive patterns, settings/config protection — always active, non-configurable |
| **Tool rules** | Per-tool allow/deny/ask with glob and wildcard matching |
| **Path rules** | Per-path read/write permissions (allow/deny/ask) for paths inside and outside workspace |
| **Default permission** | Configurable read/write permission for the workspace folder itself |
| **Script inspection** | Static analysis (grep for outside paths, network imports, exfil patterns) + Haiku LLM evaluation |
| **Symlink resolution** | All paths resolved through symlinks before security checks |
| **Config validation** | PostToolUse hook validates config schema — rejects unknown properties, wrong types, invalid values |

### Test Environment

- **Workspace:** `/tmp/sand-box-test-workspace` (simulated project folder)
- **Outside directory:** `/tmp/sand-box-test-parent` (should be inaccessible)
- **Profile:** `generic` with default read=allow, write=allow, allowed domains: localhost, 127.0.0.1
- **Tests 16-18:** Use custom profile overrides for tool rules, default permissions, and path permissions
- **Platform:** bash + jq only (no perl, no python, no node)

---

## Coverage Summary

| Test | Security Domain | Assertions | Status |
|---|---|---|---|
| 01-block-read-outside-pwd | Workspace Boundary (Read) | 3 | PASS |
| 02-block-write-outside-pwd | Workspace Boundary (Write/Edit) | 3 | PASS |
| 03-block-env-files | Sensitive File Protection | 5 | PASS |
| 04-block-passwd-etc | System Security Paths | 6 | PASS |
| 05-block-edit-settings | Agent Settings Protection (Write) | 5 | PASS |
| 06-block-edit-sandbox-config | Sandbox Config Protection | 4 | PASS |
| 07-allow-read-settings | Settings Read Access (Positive) | 3 | PASS |
| 08-allow-read-sandbox-config | Sandbox Config Read Access (Positive) | 1 | PASS |
| 09-allow-normal-workspace-work | Normal Operations (Positive) | 6 | PASS |
| 10-block-dotdot-traversal | Path Traversal Prevention | 6 | PASS |
| 11-block-claude-cli-escape | Claude CLI Escape Prevention | 3 | PASS |
| 12-block-symlink-escape | Bash Path Escape | 4 | PASS |
| 13-block-script-network-exfil | Script Network Exfiltration | 2 | PASS |
| 14-block-script-dynamic-import | Script Exfiltration Pattern | 2 | PASS |
| 15-block-script-file-plus-network | Script Static Path Analysis | 3 | PASS |
| 16-tool-rules | Per-Tool Permission Rules | 6 | PASS |
| 17-default-permission | Default Workspace Permission | 4 | PASS |
| 18-path-ask-permission | Per-Path Permissions with Ask | 4 | PASS |
| 19-script-no-extension | Extensionless Script Inspection | 2 | PASS |

---

## Detailed Results

### 01-block-read-outside-pwd — Workspace Boundary (Read)

> Verifies that the Read tool cannot access files outside the sandboxed workspace directory. The agent is confined to its workspace — any file path resolving outside it is denied.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Read outside workspace is denied | `"permissionDecision":"deny"` | PASS |
| 2 | Reason mentions outside workspace | `access outside workspace` | PASS |
| 3 | Read inside workspace is allowed | `"permissionDecision":"allow"` | PASS |

### 02-block-write-outside-pwd — Workspace Boundary (Write/Edit)

> Verifies that Write and Edit tools cannot create or modify files outside the workspace. Prevents the agent from planting files in arbitrary locations.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Write outside workspace is denied | `"permissionDecision":"deny"` | PASS |
| 2 | Edit outside workspace is denied | `"permissionDecision":"deny"` | PASS |
| 3 | Write inside workspace is allowed | `"permissionDecision":"allow"` | PASS |

### 03-block-env-files — Sensitive File Protection

> Blocks access to files matching sensitive patterns (.env, *secret*, *credentials*, *private_key*, *.enc.*, *id_rsa*, *id_ed25519*) even INSIDE the workspace. These files may contain API keys, passwords, or tokens.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | .env file is denied | `"permissionDecision":"deny"` | PASS |
| 2 | Reason mentions sensitive | `sensitive file` | PASS |
| 3 | .env.local file is denied | `"permissionDecision":"deny"` | PASS |
| 4 | secret-named file is denied | `"permissionDecision":"deny"` | PASS |
| 5 | credentials file is denied | `"permissionDecision":"deny"` | PASS |

### 04-block-passwd-etc — System Security Paths

> Blocks access to critical system files: /etc/passwd, /etc/shadow, ~/.ssh/*, ~/.gnupg/*, ~/.aws/credentials, ~/.kube/config. These are hardcoded and cannot be overridden by profiles.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | /etc/passwd is denied | `"permissionDecision":"deny"` | PASS |
| 2 | Reason mentions system security | `system security` | PASS |
| 3 | /etc/shadow is denied | `"permissionDecision":"deny"` | PASS |
| 4 | ~/.ssh/id_rsa is denied | `"permissionDecision":"deny"` | PASS |
| 5 | ~/.aws/credentials is denied | `"permissionDecision":"deny"` | PASS |
| 6 | ~/.kube/config is denied | `"permissionDecision":"deny"` | PASS |

### 05-block-edit-settings — Agent Settings Protection (Write)

> Prevents the agent from modifying its own Claude Code settings (.claude/settings.json), which could disable the sandbox or alter permissions. Read access is allowed for introspection. Subagent escalation is also blocked.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Edit .claude/settings.json denied | `"permissionDecision":"deny"` | PASS |
| 2 | Write .claude/settings.json denied | `"permissionDecision":"deny"` | PASS |
| 3 | Read .claude/settings.json allowed | `"permissionDecision":"allow"` | PASS |
| 4 | Edit ~/.claude/settings.json denied | `"permissionDecision":"deny"` | PASS |
| 5 | Subagent edit settings.json denied | `"permissionDecision":"deny"` | PASS |

### 06-block-edit-sandbox-config — Sandbox Config Protection

> Prevents the agent from modifying sand-box configuration files (.sand-box/*, ~/.sand-box.*). The agent cannot weaken or disable its own sandbox. Read access allowed.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Edit .sand-box/ denied | `"permissionDecision":"deny"` | PASS |
| 2 | Write .sand-box/ denied | `"permissionDecision":"deny"` | PASS |
| 3 | Read .sand-box/ allowed | `"permissionDecision":"allow"` | PASS |
| 4 | Write ~/.sand-box/ denied | `"permissionDecision":"deny"` | PASS |

### 07-allow-read-settings — Settings Read Access (Positive)

> Confirms that read-only access to .claude/settings.json and .mcp.json is permitted while writes are blocked. The agent can introspect its config but not change it.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Read .claude/settings.json is allowed | `"permissionDecision":"allow"` | PASS |
| 2 | Read .mcp.json is allowed | `"permissionDecision":"allow"` | PASS |
| 3 | Write .mcp.json is denied | `"permissionDecision":"deny"` | PASS |

### 08-allow-read-sandbox-config — Sandbox Config Read Access (Positive)

> Confirms that reading .sand-box/ configuration files is permitted.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Read .sand-box/ is allowed | `"permissionDecision":"allow"` | PASS |

### 09-allow-normal-workspace-work — Normal Operations (Positive)

> Confirms that standard development operations within the workspace are not blocked: Read, Write, Edit, Glob, Grep, and Bash commands all work normally for workspace files.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Read src/app.js is allowed | `"permissionDecision":"allow"` | PASS |
| 2 | Write src/new.js is allowed | `"permissionDecision":"allow"` | PASS |
| 3 | Edit config.yaml is allowed | `"permissionDecision":"allow"` | PASS |
| 4 | Glob in workspace is allowed | `"permissionDecision":"allow"` | PASS |
| 5 | Grep in workspace is allowed | `"permissionDecision":"allow"` | PASS |
| 6 | Bash ls in workspace is allowed | `"permissionDecision":"allow"` | PASS |

### 10-block-dotdot-traversal — Path Traversal Prevention

> Tests that ../ sequences in file paths are properly resolved before boundary checks. Includes deep relative traversal (./../../../../etc/passwd) and multi-segment traversal. Paths that resolve within workspace after traversal are correctly allowed.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Read with ../ traversal is denied | `"permissionDecision":"deny"` | PASS |
| 2 | Bash with ../ traversal is denied | `"permissionDecision":"deny"` | PASS |
| 3 | Multiple ../ traversal is denied | `"permissionDecision":"deny"` | PASS |
| 4 | Deep relative ./../../..etc/passwd is denied | `"permissionDecision":"deny"` | PASS |
| 5 | Bash deep relative traversal to /etc/passwd is denied | `"permissionDecision":"deny"` | PASS |
| 6 | ../ within workspace is allowed | `"permissionDecision":"allow"` | PASS |

### 11-block-claude-cli-escape — Claude CLI Escape Prevention

> Blocks attempts to spawn sub-agents that escape the sandbox: claude CLI with paths outside workspace, --settings flag (could inject different hooks), and --dangerously-skip-permissions (hard deny via exit 2, non-recoverable).

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | claude CLI with outside path is denied | `"permissionDecision":"deny"` | PASS |
| 2 | claude CLI with --settings is denied | `"permissionDecision":"deny"` | PASS |
| 3 | Hard-blocks --dangerously-skip-permissions with exit 2 | `exit=2` | PASS |

### 12-block-symlink-escape — Bash Path Escape

> Tests that Bash commands accessing files outside workspace via direct paths, cp from outside, and output redirection to outside locations are all denied.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Bash cat outside workspace is denied | `"permissionDecision":"deny"` | PASS |
| 2 | Bash cp from outside workspace is denied | `"permissionDecision":"deny"` | PASS |
| 3 | Bash redirect outside workspace is denied | `"permissionDecision":"deny"` | PASS |
| 4 | Bash cat inside workspace is allowed | `"permissionDecision":"allow"` | PASS |

### 13-block-script-network-exfil — Script Network Exfiltration

> Detects scripts that import network libraries (requests, urllib, fetch, curl, etc.) without visible URL targets — a sign of dynamic URL construction for data exfiltration. Also blocks scripts making requests to non-allowed domains.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Script with network import + no visible URLs is denied | `"permissionDecision":"deny"` | PASS |
| 2 | Script with request to non-allowed domain is denied | `"permissionDecision":"deny"` | PASS |

### 14-block-script-dynamic-import — Script Exfiltration Pattern

> Detects scripts that combine file reading operations with network requests — the classic data exfiltration pattern. Even requests to allowed domains (localhost) are flagged when combined with file reads.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Script combining file ops + network ops (exfil pattern) is denied | `"permissionDecision":"deny"` | PASS |
| 2 | Node.js script with file read + network import is denied | `"permissionDecision":"deny"` | PASS |

### 15-block-script-file-plus-network — Script Static Path Analysis

> Static grep analysis of script contents for paths outside workspace. Catches both shell scripts and Python scripts that reference files like /etc/passwd or ~/some/path. Safe scripts with only workspace paths are correctly allowed.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Shell script with path outside workspace is denied | `"permissionDecision":"deny"` | PASS |
| 2 | Python script with path outside workspace is denied | `"permissionDecision":"deny"` | PASS |
| 3 | Safe script with only workspace paths is allowed | `"permissionDecision":"allow"` | PASS |

### 16-tool-rules — Per-Tool Permission Rules

> Tests configurable per-tool permissions: exact tool name matching (Agent deny), Bash glob patterns (Bash(rm *) deny, Bash(ls *) allow), MCP wildcard matching (mcp__atlassian__edit* deny), and pipe-separated tool lists (Read|Grep|Glob allow).

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Agent tool is denied | `"permissionDecision":"deny"` | PASS |
| 2 | Bash rm is denied by tool rule | `"permissionDecision":"deny"` | PASS |
| 3 | Bash ls in workspace is allowed | `"permissionDecision":"allow"` | PASS |
| 4 | MCP edit tool is denied | `"permissionDecision":"deny"` | PASS |
| 5 | MCP get tool is not denied | `NOT "permissionDecision":"deny"` | PASS |
| 6 | Read tool is allowed by pipe rule | `"permissionDecision":"allow"` | PASS |

### 17-default-permission — Default Workspace Permission

> Tests the profile default permission for workspace files. With default.write=ask: reads are allowed, writes prompt for approval in interactive mode and are denied in auto/pipe mode. Outside workspace stays denied regardless.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Read in workspace allowed with default.read=allow | `"permissionDecision":"allow"` | PASS |
| 2 | Write in workspace asks with default.write=ask (interactive) | `"permissionDecision":"ask"` | PASS |
| 3 | Write in workspace denied with default.write=ask (auto mode) | `"permissionDecision":"deny"` | PASS |
| 4 | Outside workspace still denied | `"permissionDecision":"deny"` | PASS |

### 18-path-ask-permission — Per-Path Permissions with Ask

> Tests configurable per-path read/write permissions including the ask option. Paths outside workspace can be allowed with restrictions (read=allow, write=ask). Paths inside workspace can be denied (TAJNE = deny all).

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Read from allowed outside path | `"permissionDecision":"allow"` | PASS |
| 2 | Write to outside path asks (interactive) | `"permissionDecision":"ask"` | PASS |
| 3 | Read from TAJNE denied | `"permissionDecision":"deny"` | PASS |
| 4 | Write to TAJNE denied | `"permissionDecision":"deny"` | PASS |

### 19-script-no-extension — Extensionless Script Inspection

> Verifies that executable scripts WITHOUT file extensions (e.g. ./myscript) are still inspected for malicious content. The hook detects executable text files in the workspace and runs the full static analysis pipeline on them.

| # | Security Test | Expected | Result |
|---|---|---|---|
| 1 | Executable without extension is inspected and denied | `"permissionDecision":"deny"` | PASS |
| 2 | Safe executable without extension is allowed | `"permissionDecision":"allow"` | PASS |

---

*Auto-generated by run-all.sh — 2026-04-10T16:15:18*
