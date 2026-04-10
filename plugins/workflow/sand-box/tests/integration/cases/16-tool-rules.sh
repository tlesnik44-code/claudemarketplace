#!/bin/bash
# Test: Tool rules — deny/ask/allow per tool
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Override global config with tool rules
cat > "/tmp/sand-box-test-global.json" << 'EOF'
{
  "userProfiles": ["with-tools"],
  "profiles": {
    "with-tools": {
      "default": { "read": "allow", "write": "allow" },
      "allowedDomains": ["localhost"],
      "tools": {
        "Agent": "deny",
        "Bash(rm *)": "deny",
        "Bash(ls *)": "allow",
        "mcp__atlassian__edit*": "deny",
        "mcp__atlassian__get*": "allow",
        "Read|Grep|Glob": "allow"
      }
    }
  },
  "foldersProfile": {}
}
EOF

# Agent → denied
result=$(run_hook '{"tool_name":"Agent","tool_input":{"prompt":"do something"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "Agent tool is denied"

# Bash rm → denied
result=$(run_hook '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/stuff"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "Bash rm is denied by tool rule"

# Bash ls → allowed (tool allows, path check runs — workspace path OK)
result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls $WORKSPACE/src\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Bash ls in workspace is allowed"

# MCP edit → denied
result=$(run_hook '{"tool_name":"mcp__atlassian__editJiraIssue","tool_input":{},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "MCP edit tool is denied"

# MCP get → allowed (no path check for MCP, exits with no opinion → allow not emitted)
# Actually MCP tools that pass tool check fall through to exit 0 (no opinion)
result=$(run_hook '{"tool_name":"mcp__atlassian__getJiraIssue","tool_input":{},"permission_mode":"default"}')
assert_not_contains "$result" '"permissionDecision":"deny"' "MCP get tool is not denied"

# Read tool → explicitly allowed by pipe-separated rule
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/src/app.js\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Read tool is allowed by pipe rule"

cleanup
print_summary
