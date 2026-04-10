#!/bin/bash
# Test: Read .sand-box/* → allowed (read-only access)
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Read sand-box config → allowed
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.sand-box/test-profile.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Read .sand-box/ is allowed"

cleanup
print_summary
