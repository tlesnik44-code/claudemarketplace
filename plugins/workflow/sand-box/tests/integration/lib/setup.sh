#!/bin/bash
# Sand-box v2 — Test workspace setup

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$(cd "$TEST_DIR/../.." && pwd)"
HOOK_FILE="$PLUGIN_DIR/hooks/sand-box.sh"

# Test workspace
WORKSPACE="/tmp/sand-box-test-workspace"
PARENT_DIR="/tmp/sand-box-test-parent"

setup_workspace() {
  rm -rf "$WORKSPACE" "$PARENT_DIR"
  mkdir -p "$WORKSPACE"/{src,docs}
  mkdir -p "$PARENT_DIR"

  # Create test files in workspace
  echo "console.log('hello');" > "$WORKSPACE/src/app.js"
  echo "# README" > "$WORKSPACE/docs/readme.md"
  echo "normal config" > "$WORKSPACE/config.yaml"

  # Create sensitive files in workspace
  echo "SECRET=abc123" > "$WORKSPACE/.env"
  echo "DB_PASS=secret" > "$WORKSPACE/.env.local"

  # Create files outside workspace (in parent)
  echo "parent secret" > "$PARENT_DIR/secret.txt"
  echo "parent data" > "$PARENT_DIR/data.txt"

  # Create .claude directory in workspace
  mkdir -p "$WORKSPACE/.claude"
  echo '{"hooks":{}}' > "$WORKSPACE/.claude/settings.json"

  # Create .sand-box directory in workspace
  mkdir -p "$WORKSPACE/.sand-box"
  echo '{"name":"test"}' > "$WORKSPACE/.sand-box/test-profile.json"

  # Create a sand-box.json profile in the workspace (shared config)
  echo '{"profile":{"default":{"read":"allow","write":"allow"}}}' > "$WORKSPACE/.sand-box.json"

  # Create global config with generic profile
  cat > "/tmp/sand-box-test-global.json" << 'EOF'
{
  "userProfiles": ["generic"],
  "profiles": {
    "generic": {
      "default": { "read": "allow", "write": "allow" },
      "allowedDomains": ["localhost", "127.0.0.1"],
      "scriptChecking": true,
      "paths": {},
      "tools": {}
    }
  },
  "foldersProfile": {}
}
EOF
}

# Run the hook with simulated input JSON
# Overrides HOME to use test global config
run_hook() {
  local hook_or_input="$1"
  local input_json="${2:-$1}"

  # If called with 2 args, first is ignored (backward compat)
  [[ $# -eq 2 ]] && input_json="$2"

  local result
  local exit_code

  result=$(echo "$input_json" | \
    CLAUDE_PROJECT_DIR="$WORKSPACE" \
    CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" \
    SAND_BOX_GLOBAL_CONFIG="/tmp/sand-box-test-global.json" \
    bash "$HOOK_FILE" 2>/tmp/sand-box-test-stderr) || exit_code=$?
  exit_code=${exit_code:-0}

  echo "$result"
  return "$exit_code"
}

cleanup() {
  rm -rf "$WORKSPACE" "$PARENT_DIR" /tmp/sand-box-test-stderr /tmp/sand-box-test-global.json
}
