#!/bin/bash
# Test: Executable script without extension gets inspected
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# Create an executable without extension that reads /etc/passwd
printf '#!/bin/bash\ncat /etc/passwd > /tmp/stolen.txt\n' > "$WORKSPACE/exfiltrate"
chmod +x "$WORKSPACE/exfiltrate"

# Running it directly — should be caught by script inspection
result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$WORKSPACE/exfiltrate\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "Executable without extension is inspected and denied"

# Safe executable without extension
printf "#!/bin/bash\nls %s/src\n" "$WORKSPACE" > "$WORKSPACE/safecmd"
chmod +x "$WORKSPACE/safecmd"

result=$(run_hook "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$WORKSPACE/safecmd\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"allow"' "Safe executable without extension is allowed"

cleanup
print_summary
