#!/bin/bash
# Test: Default workspace permission (ask for writes)
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Override: default write = ask
cat > "/tmp/sand-box-test-global.json" << 'EOF'
{
  "userProfiles": ["ask-write"],
  "profiles": {
    "ask-write": {
      "default": { "read": "allow", "write": "ask" },
      "allowedDomains": ["localhost"]
    }
  },
  "foldersProfile": {}
}
EOF

# Read in workspace → allowed (default.read = allow)
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/src/app.js\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Read in workspace allowed with default.read=allow"

# Write in workspace → ask (default.write = ask, interactive mode)
result=$(run_hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/new.txt\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"ask"' "Write in workspace asks with default.write=ask (interactive)"

# Write in workspace → deny (default.write = ask, auto mode → deny)
result=$(run_hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/new.txt\"},\"permission_mode\":\"auto\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Write in workspace denied with default.write=ask (auto mode)"

# Outside workspace → still denied regardless of default
result=$(run_hook '{"tool_name":"Read","tool_input":{"file_path":"/tmp/sand-box-test-parent/data.txt"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "Outside workspace still denied"

cleanup
print_summary
