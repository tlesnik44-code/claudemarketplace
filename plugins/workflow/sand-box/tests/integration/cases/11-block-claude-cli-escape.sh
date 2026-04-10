#!/bin/bash
# Test: Claude CLI escape attempts → deny
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# claude with path outside workspace
result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"claude -p /tmp/sand-box-test-parent\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "claude CLI with outside path is denied"

# claude with --settings flag
result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"claude --settings /tmp/evil-settings.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "claude CLI with --settings is denied"

# --dangerously-skip-permissions → hard deny (exit 2)
exit_code=0
run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"claude --dangerously-skip-permissions\"},\"permission_mode\":\"default\"}" || exit_code=$?
assert_exit_code "$exit_code" 2 "Hard-blocks --dangerously-skip-permissions with exit 2"

cleanup
print_summary
