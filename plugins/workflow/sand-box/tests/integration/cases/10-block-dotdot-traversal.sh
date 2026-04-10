#!/bin/bash
# Test: Path traversal via ../ → deny
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Read with ../
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/../sand-box-test-parent/data.txt\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Read with ../ traversal is denied"

# Bash with ../
result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat $WORKSPACE/../sand-box-test-parent/data.txt\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Bash with ../ traversal is denied"

# Multiple ../ still resolves correctly
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/src/../../sand-box-test-parent/data.txt\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Multiple ../ traversal is denied"

# Deep relative traversal ./../../../../etc/passwd
result=$(run_hook '{"tool_name":"Read","tool_input":{"file_path":"./../../../../etc/passwd"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "Deep relative ./../../..etc/passwd is denied"

# Same via Bash
result=$(run_hook '{"tool_name":"Bash","tool_input":{"command":"cat ./../../../../etc/passwd"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "Bash deep relative traversal to /etc/passwd is denied"

# ../ that stays within workspace is ok
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/src/../docs/readme.md\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "../ within workspace is allowed"

cleanup
print_summary
