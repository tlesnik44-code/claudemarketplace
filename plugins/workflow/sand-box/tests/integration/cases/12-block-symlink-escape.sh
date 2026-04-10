#!/bin/bash
# Test: Bash commands accessing paths outside workspace → deny
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Bash cat outside workspace
result=$(run_hook '{"tool_name":"Bash","tool_input":{"command":"cat /tmp/sand-box-test-parent/data.txt"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "Bash cat outside workspace is denied"

# Bash cp to workspace from outside
result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cp /tmp/sand-box-test-parent/data.txt $WORKSPACE/stolen.txt\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Bash cp from outside workspace is denied"

# Bash redirect outside workspace
result=$(run_hook '{"tool_name":"Bash","tool_input":{"command":"echo hi > /tmp/sand-box-test-parent/evil.txt"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "Bash redirect outside workspace is denied"

# Bash with only workspace paths
result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat $WORKSPACE/src/app.js\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Bash cat inside workspace is allowed"

cleanup
print_summary
