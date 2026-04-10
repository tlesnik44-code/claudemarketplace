#!/bin/bash
# Test: Read .claude/settings.json → allowed (read-only access)
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Read settings.json in workspace → allowed (protected but read is ok)
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.claude/settings.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Read .claude/settings.json is allowed"

# Read .mcp.json → allowed
echo '{}' > "$WORKSPACE/.mcp.json"
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.mcp.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Read .mcp.json is allowed"

# Write .mcp.json → denied
result=$(run_hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.mcp.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Write .mcp.json is denied"

cleanup
print_summary
