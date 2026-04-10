#!/bin/bash
# Test: System security paths (/etc/passwd, ~/.ssh/*, etc.) → deny
source "$(dirname "$0")/../lib/setup.sh"
source "$(dirname "$0")/../lib/assert.sh"

setup_workspace

# /etc/passwd
result=$(run_hook '{"tool_name":"Read","tool_input":{"file_path":"/etc/passwd"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "/etc/passwd is denied"
assert_contains "$result" "system security" "Reason mentions system security"

# /etc/shadow
result=$(run_hook '{"tool_name":"Read","tool_input":{"file_path":"/etc/shadow"},"permission_mode":"default"}')
assert_contains "$result" '"permissionDecision":"deny"' "/etc/shadow is denied"

# ~/.ssh/id_rsa
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$HOME/.ssh/id_rsa\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "~/.ssh/id_rsa is denied"

# ~/.aws/credentials
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$HOME/.aws/credentials\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "~/.aws/credentials is denied"

# ~/.kube/config
result=$(run_hook "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$HOME/.kube/config\"},\"permission_mode\":\"default\"}")
assert_contains "$result" '"permissionDecision":"deny"' "~/.kube/config is denied"

cleanup
print_summary
