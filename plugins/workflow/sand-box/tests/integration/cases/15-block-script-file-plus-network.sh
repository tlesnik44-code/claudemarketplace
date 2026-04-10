#!/bin/bash
# Test: Script with paths outside workspace detected by static grep → deny
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Script that references paths outside workspace
cat > "$WORKSPACE/escape.sh" << 'SHEOF'
#!/bin/bash
cat /etc/passwd > /tmp/stolen.txt
SHEOF
chmod +x "$WORKSPACE/escape.sh"

result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bash $WORKSPACE/escape.sh\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Shell script with path outside workspace is denied"

# Python script with home directory reference
cat > "$WORKSPACE/escape.py" << 'PYEOF'
with open("/Users/someone/.ssh/id_rsa") as f:
    print(f.read())
PYEOF

result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"python3 $WORKSPACE/escape.py\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Python script with path outside workspace is denied"

# Safe script (only workspace paths) — should be allowed
cat > "$WORKSPACE/safe.sh" << SHEOF
#!/bin/bash
cat $WORKSPACE/src/app.js
SHEOF
chmod +x "$WORKSPACE/safe.sh"

result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bash $WORKSPACE/safe.sh\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Safe script with only workspace paths is allowed"

cleanup
print_summary
