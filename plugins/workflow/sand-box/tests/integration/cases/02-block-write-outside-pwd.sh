#!/bin/bash
# Test: Write/Edit tool targeting path outside workspace → deny
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Write outside workspace
result=$(run_hook '{"tool_name":"Write","tool_input":{"file_path":"/tmp/sand-box-test-parent/evil.txt"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "Write outside workspace is denied"

# Edit outside workspace
result=$(run_hook '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/sand-box-test-parent/data.txt"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "Edit outside workspace is denied"

# Write inside workspace
result=$(run_hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/new-file.txt\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Write inside workspace is allowed"

cleanup
print_summary
