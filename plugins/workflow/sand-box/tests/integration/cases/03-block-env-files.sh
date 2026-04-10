#!/bin/bash
# Test: Sensitive files (.env, secrets, credentials) → deny even inside workspace
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# .env file
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.env\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' ".env file is denied"
assert_contains "$result" "sensitive file" "Reason mentions sensitive"

# .env.local file
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/.env.local\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' ".env.local file is denied"

# File with "secret" in name
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/my-secret-config.yml\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "secret-named file is denied"

# File with "credentials" in name
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$WORKSPACE/credentials.json\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "credentials file is denied"

cleanup
print_summary
