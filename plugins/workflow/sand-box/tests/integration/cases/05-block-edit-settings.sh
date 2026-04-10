#!/bin/bash
# Test: Write to .claude/settings.json → deny
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Edit settings.json in workspace
result=$(run_hook "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.claude/settings.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Edit .claude/settings.json denied"

# Write settings.json
result=$(run_hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.claude/settings.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Write .claude/settings.json denied"

# Read settings.json → allowed (read-only)
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.claude/settings.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Read .claude/settings.json allowed"

# Edit user settings.json → denied (outside workspace)
result=$(run_hook "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$HOME/.claude/settings.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Edit ~/.claude/settings.json denied"

# Subagent with default mode → still denied (not ask)
result=$(run_hook "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.claude/settings.json\"},\"permission_mode\":\"default\",\"agent_id\":\"sub-123\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Subagent edit settings.json denied"

cleanup
print_summary
