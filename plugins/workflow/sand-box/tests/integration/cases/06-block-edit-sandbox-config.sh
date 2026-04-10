#!/bin/bash
# Test: Write to .sand-box/* → deny
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Edit sand-box config
result=$(run_hook "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.sand-box/test-profile.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Edit .sand-box/ denied"

# Write to sand-box
result=$(run_hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.sand-box/evil.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Write .sand-box/ denied"

# Read sand-box → allowed
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.sand-box/test-profile.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Read .sand-box/ allowed"

# Write to ~/.sand-box/ → denied (outside workspace + protected)
result=$(run_hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$HOME/.sand-box/evil.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Write ~/.sand-box/ denied"

cleanup
print_summary
