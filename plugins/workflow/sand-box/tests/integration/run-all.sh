#!/bin/bash
#
# Sand-box v2 — Integration Test Runner + Security Report Generator
#

set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
CASES_DIR="$TEST_DIR/cases"
REPORT_DATA="/tmp/sand-box-report-data.tsv"
REPORT_FILE="$TEST_DIR/SECURITY-TEST-REPORT.md"

TOTAL_PASS=0
TOTAL_FAIL=0

> "$REPORT_DATA"

echo "Sand-box v2 — Integration Tests"
echo "================================"
echo ""

for test_file in "$CASES_DIR"/*.sh; do
  test_name=$(basename "$test_file" .sh)
  echo "▸ $test_name"

  output=$(SAND_BOX_REPORT_FILE="$REPORT_DATA" SAND_BOX_CURRENT_TEST="$test_name" bash "$test_file" 2>&1) || true
  echo "$output" | grep -E '^\s+[✓✗]' || true

  pass=$(echo "$output" | grep -c '✓' || true)
  fail=$(echo "$output" | grep -c '✗' || true)

  TOTAL_PASS=$((TOTAL_PASS + pass))
  TOTAL_FAIL=$((TOTAL_FAIL + fail))
  echo ""
done

echo "================================"
echo "Total: $TOTAL_PASS passed, $TOTAL_FAIL failed"
echo ""

# ═══════════════════════════════════════════════════════════════
# GENERATE SECURITY REPORT
# ═══════════════════════════════════════════════════════════════

# ─── Test descriptions for the report ───
# Format: "domain|description" — lookup by function (bash 3.x compatible, no associative arrays)
_test_desc() {
  case "$1" in
    01-block-read-outside-pwd) echo "Workspace Boundary (Read)|Verifies that the Read tool cannot access files outside the sandboxed workspace directory. The agent is confined to its workspace — any file path resolving outside it is denied." ;;
    02-block-write-outside-pwd) echo "Workspace Boundary (Write/Edit)|Verifies that Write and Edit tools cannot create or modify files outside the workspace. Prevents the agent from planting files in arbitrary locations." ;;
    03-block-env-files) echo "Sensitive File Protection|Blocks access to files matching sensitive patterns (.env, *secret*, *credentials*, *private_key*, *.enc.*, *id_rsa*, *id_ed25519*) even INSIDE the workspace. These files may contain API keys, passwords, or tokens." ;;
    04-block-passwd-etc) echo "System Security Paths|Blocks access to critical system files: /etc/passwd, /etc/shadow, ~/.ssh/*, ~/.gnupg/*, ~/.aws/credentials, ~/.kube/config. These are hardcoded and cannot be overridden by profiles." ;;
    05-block-edit-settings) echo "Agent Settings Protection (Write)|Prevents the agent from modifying its own Claude Code settings (.claude/settings.json), which could disable the sandbox or alter permissions. Read access is allowed for introspection. Subagent escalation is also blocked." ;;
    06-block-edit-sandbox-config) echo "Sandbox Config Protection|Prevents the agent from modifying sand-box configuration files (.sand-box/*, ~/.sand-box.*). The agent cannot weaken or disable its own sandbox. Read access allowed." ;;
    07-allow-read-settings) echo "Settings Read Access (Positive)|Confirms that read-only access to .claude/settings.json and .mcp.json is permitted while writes are blocked. The agent can introspect its config but not change it." ;;
    08-allow-read-sandbox-config) echo "Sandbox Config Read Access (Positive)|Confirms that reading .sand-box/ configuration files is permitted." ;;
    09-allow-normal-workspace-work) echo "Normal Operations (Positive)|Confirms that standard development operations within the workspace are not blocked: Read, Write, Edit, Glob, Grep, and Bash commands all work normally for workspace files." ;;
    10-block-dotdot-traversal) echo "Path Traversal Prevention|Tests that ../ sequences in file paths are properly resolved before boundary checks. Includes deep relative traversal (./../../../../etc/passwd) and multi-segment traversal. Paths that resolve within workspace after traversal are correctly allowed." ;;
    11-block-claude-cli-escape) echo "Claude CLI Escape Prevention|Blocks attempts to spawn sub-agents that escape the sandbox: claude CLI with paths outside workspace, --settings flag (could inject different hooks), and --dangerously-skip-permissions (hard deny via exit 2, non-recoverable)." ;;
    12-block-symlink-escape) echo "Bash Path Escape|Tests that Bash commands accessing files outside workspace via direct paths, cp from outside, and output redirection to outside locations are all denied." ;;
    13-block-script-network-exfil) echo "Script Network Exfiltration|Detects scripts that import network libraries (requests, urllib, fetch, curl, etc.) without visible URL targets — a sign of dynamic URL construction for data exfiltration. Also blocks scripts making requests to non-allowed domains." ;;
    14-block-script-dynamic-import) echo "Script Exfiltration Pattern|Detects scripts that combine file reading operations with network requests — the classic data exfiltration pattern. Even requests to allowed domains (localhost) are flagged when combined with file reads." ;;
    15-block-script-file-plus-network) echo "Script Static Path Analysis|Static grep analysis of script contents for paths outside workspace. Catches both shell scripts and Python scripts that reference files like /etc/passwd or ~/some/path. Safe scripts with only workspace paths are correctly allowed." ;;
    16-tool-rules) echo "Per-Tool Permission Rules|Tests configurable per-tool permissions: exact tool name matching (Agent deny), Bash glob patterns (Bash(rm *) deny, Bash(ls *) allow), MCP wildcard matching (mcp__atlassian__edit* deny), and pipe-separated tool lists (Read|Grep|Glob allow)." ;;
    17-default-permission) echo "Default Workspace Permission|Tests the profile default permission for workspace files. With default.write=ask: reads are allowed, writes prompt for approval in interactive mode and are denied in auto/pipe mode. Outside workspace stays denied regardless." ;;
    18-path-ask-permission) echo "Per-Path Permissions with Ask|Tests configurable per-path read/write permissions including the ask option. Paths outside workspace can be allowed with restrictions (read=allow, write=ask). Paths inside workspace can be denied (TAJNE = deny all)." ;;
    19-script-no-extension) echo "Extensionless Script Inspection|Verifies that executable scripts WITHOUT file extensions (e.g. ./myscript) are still inspected for malicious content. The hook detects executable text files in the workspace and runs the full static analysis pipeline on them." ;;
    *) echo "Unknown Test|No description available." ;;
  esac
}

{
  echo "# Sand-Box Plugin — Security Test Report"
  echo ""
  echo "**Date:** $(date +%Y-%m-%d)"
  echo "**Total assertions:** $((TOTAL_PASS + TOTAL_FAIL))"
  echo "**Passed:** $TOTAL_PASS"
  echo "**Failed:** $TOTAL_FAIL"
  if [[ "$TOTAL_FAIL" -eq 0 ]]; then
    echo "**Status:** ALL PASS"
  else
    echo "**Status:** FAILURES DETECTED"
  fi
  echo ""
  echo "---"
  echo ""

  # Overview
  echo "## Overview"
  echo ""
  echo "The **sand-box** plugin is a PreToolUse hook for Claude Code that enforces workspace isolation,"
  echo "protects sensitive files, prevents agent self-modification, and detects script-based escape attempts."
  echo "It reads profiles from \`~/.sand-box.json\` (user config) and \`<project>/.sand-box.json\` (shared config)"
  echo "at runtime — no code generation, single hook file."
  echo ""
  echo "### Threat Model"
  echo ""
  echo "The sandbox defends against an AI agent that may attempt to:"
  echo ""
  echo "1. **Read/write files outside its workspace** — access source code, configs, or data from other projects"
  echo "2. **Read sensitive files** — .env files, API keys, credentials, SSH keys, cloud configs"
  echo "3. **Modify its own settings** — disable the sandbox, change permissions, alter hook configuration"
  echo "4. **Escape via path traversal** — use \`../\` sequences or symlinks to bypass workspace boundaries"
  echo "5. **Spawn sub-agents that escape** — use \`claude -p\` with outside paths or \`--settings\`/\`--dangerously-skip-permissions\`"
  echo "6. **Exfiltrate data via scripts** — write scripts that read files and send them to external servers"
  echo "7. **Use extensionless executables** — bypass script inspection by omitting file extensions"
  echo ""
  echo "### Security Layers"
  echo ""
  echo "| Layer | Description |"
  echo "|---|---|"
  echo "| **Hardcoded rules** | System security files, sensitive patterns, settings/config protection — always active, non-configurable |"
  echo "| **Tool rules** | Per-tool allow/deny/ask with glob and wildcard matching |"
  echo "| **Path rules** | Per-path read/write permissions (allow/deny/ask) for paths inside and outside workspace |"
  echo "| **Default permission** | Configurable read/write permission for the workspace folder itself |"
  echo "| **Script inspection** | Static analysis (grep for outside paths, network imports, exfil patterns) + Haiku LLM evaluation |"
  echo "| **Symlink resolution** | All paths resolved through symlinks before security checks |"
  echo "| **Config validation** | PostToolUse hook validates config schema — rejects unknown properties, wrong types, invalid values |"
  echo ""
  echo "### Test Environment"
  echo ""
  echo "- **Workspace:** \`/tmp/sand-box-test-workspace\` (simulated project folder)"
  echo "- **Outside directory:** \`/tmp/sand-box-test-parent\` (should be inaccessible)"
  echo "- **Profile:** \`generic\` with default read=allow, write=allow, allowed domains: localhost, 127.0.0.1"
  echo "- **Tests 16-18:** Use custom profile overrides for tool rules, default permissions, and path permissions"
  echo "- **Platform:** bash + jq only (no perl, no python, no node)"
  echo ""
  echo "---"
  echo ""

  # Coverage summary
  echo "## Coverage Summary"
  echo ""
  echo "| Test | Security Domain | Assertions | Status |"
  echo "|---|---|---|---|"

  prev_test=""
  test_pass=0
  test_fail=0
  test_total=0

  while IFS=$'\t' read -r test num desc expected result; do
    if [[ "$test" != "$prev_test" && -n "$prev_test" ]]; then
      status="PASS"
      [[ "$test_fail" -gt 0 ]] && status="**FAIL**"
      domain="$(_test_desc "$prev_test" | cut -d'|' -f1)"
      echo "| $prev_test | $domain | $test_total | $status |"
      test_pass=0
      test_fail=0
      test_total=0
    fi
    prev_test="$test"
    test_total=$((test_total + 1))
    [[ "$result" == "PASS" ]] && test_pass=$((test_pass + 1)) || test_fail=$((test_fail + 1))
  done < "$REPORT_DATA"

  if [[ -n "$prev_test" ]]; then
    status="PASS"
    [[ "$test_fail" -gt 0 ]] && status="**FAIL**"
    domain="$(_test_desc "$prev_test" | cut -d'|' -f1)"
    echo "| $prev_test | $domain | $test_total | $status |"
  fi

  echo ""
  echo "---"
  echo ""

  # Detailed results
  echo "## Detailed Results"
  echo ""

  prev_test=""
  while IFS=$'\t' read -r test num desc expected result; do
    if [[ "$test" != "$prev_test" ]]; then
      [[ -n "$prev_test" ]] && echo ""
      test_info="$(_test_desc "$test")"
      test_domain="${test_info%%|*}"
      test_detail="${test_info#*|}"
      echo "### $test — $test_domain"
      echo ""
      [[ -n "$test_detail" ]] && echo "> $test_detail" && echo ""
      echo "| # | Security Test | Expected | Result |"
      echo "|---|---|---|---|"
      prev_test="$test"
    fi
    echo "| $num | $desc | \`$expected\` | $result |"
  done < "$REPORT_DATA"

  echo ""
  echo "---"
  echo ""
  echo "*Auto-generated by run-all.sh — $(date +%Y-%m-%dT%H:%M:%S)*"

} > "$REPORT_FILE"

echo "Security report: $REPORT_FILE"

rm -f "$REPORT_DATA"

if [[ "$TOTAL_FAIL" -gt 0 ]]; then
  echo "FAILED"
  exit 1
else
  echo "ALL PASSED"
  exit 0
fi
