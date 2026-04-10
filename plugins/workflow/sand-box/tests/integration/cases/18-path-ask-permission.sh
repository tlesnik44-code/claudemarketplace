#!/bin/bash
# Test: Path rules with ask permission
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Override: path with ask permission
cat > "/tmp/sand-box-test-global.json" << EOF
{
  "userProfiles": ["path-ask"],
  "profiles": {
    "path-ask": {
      "default": { "read": "allow", "write": "allow" },
      "paths": {
        "/tmp/sand-box-test-parent": { "read": "allow", "write": "ask" },
        "TAJNE": { "read": "deny", "write": "deny" }
      }
    }
  },
  "foldersProfile": {}
}
EOF

# Create TAJNE dir in workspace
mkdir -p "$WORKSPACE/TAJNE"
echo "top secret" > "$WORKSPACE/TAJNE/data.txt"

# Read from allowed outside path → allow
result=$(run_hook '{"tool_name":"Read","tool_input":{"file_path":"/tmp/sand-box-test-parent/data.txt"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"allow"' "Read from allowed outside path"

# Write to outside path with ask → ask (interactive)
result=$(run_hook '{"tool_name":"Write","tool_input":{"file_path":"/tmp/sand-box-test-parent/new.txt"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"ask"' "Write to outside path asks (interactive)"

# Read from denied workspace subpath → deny
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/TAJNE/data.txt\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Read from TAJNE denied"

# Write to denied workspace subpath → deny
result=$(run_hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/TAJNE/evil.txt\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Write to TAJNE denied"

cleanup
print_summary
