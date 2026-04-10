#!/bin/bash
# Test: Read tool targeting path outside workspace → deny
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Read file outside workspace
result=$(run_hook '{"tool_name":"Read","tool_input":{"file_path":"/tmp/sand-box-test-parent/data.txt"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "Read outside workspace is denied"
assert_contains "$result" "access outside workspace" "Reason mentions outside workspace"

# Read file in workspace
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/src/app.js\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Read inside workspace is allowed"

cleanup
print_summary
