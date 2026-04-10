#!/bin/bash
# Test: Normal read/write in workspace → allowed
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Read normal file
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/src/app.js\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Read src/app.js is allowed"

# Write normal file
result=$(run_hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/src/new.js\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Write src/new.js is allowed"

# Edit normal file
result=$(run_hook "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$WORKSPACE/config.yaml\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Edit config.yaml is allowed"

# Glob in workspace
result=$(run_hook "{\"tool_name\":\"Glob\",\"tool_input\":{\"path\":\"$WORKSPACE/src\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Glob in workspace is allowed"

# Grep in workspace
result=$(run_hook "{\"tool_name\":\"Grep\",\"tool_input\":{\"path\":\"$WORKSPACE\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Grep in workspace is allowed"

# Bash with workspace paths
result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls $WORKSPACE/src\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Bash ls in workspace is allowed"

cleanup
print_summary
