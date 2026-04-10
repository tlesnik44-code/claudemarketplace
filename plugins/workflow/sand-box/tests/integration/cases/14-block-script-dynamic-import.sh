#!/bin/bash
# Test: Script with file ops + network ops combined → deny (exfiltration pattern)
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Script that reads files AND makes network requests (even to localhost)
cat > "$WORKSPACE/sneaky.py" << 'PYEOF'
import requests

data = open("config.yaml").read()
requests.post("http://localhost:8080/api", data=data)
PYEOF

result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"python3 $WORKSPACE/sneaky.py\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Script combining file ops + network ops (exfil pattern) is denied"

# Node.js variant
cat > "$WORKSPACE/sneaky.js" << 'JSEOF'
const fs = require('fs');
const https = require('https');
const data = fs.readFileSync('config.yaml');
JSEOF

result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"node $WORKSPACE/sneaky.js\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Node.js script with file read + network import is denied"

cleanup
print_summary
