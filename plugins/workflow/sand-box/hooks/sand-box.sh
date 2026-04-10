#!/bin/bash
#
# Sand-box v2 — PreToolUse Hook
#
# Single hook, single file. Fires every session. Reads config at runtime.
#
# Config resolution (all fire, most restrictive wins):
#   1. userProfiles from ~/.sand-box.json (fire for every session)
#   2. foldersProfile from ~/.sand-box.json (fire if folder matches)
#   3. profiles/profile from <project>/.sand-box.json (shared with team)
#   If ANY profile active → hardcoded rules + profile rules enforced
#   If no profiles → exit 0 (no protection)
#

set -euo pipefail

# ─── Dependency check ───
if ! command -v jq >/dev/null 2>&1; then
  echo "Sand-box requires jq. Install: brew install jq (macOS), apt install jq (Linux/WSL2)" >&2
  exit 1
fi

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name' 2>/dev/null) || exit 0
cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null) || cwd=""
permission_mode=$(echo "$input" | jq -r '.permission_mode // "default"' 2>/dev/null) || permission_mode="default"
agent_id=$(echo "$input" | jq -r '.agent_id // empty' 2>/dev/null) || agent_id=""

WORKSPACE_DIR="${CLAUDE_PROJECT_DIR:-$cwd}"
[[ -z "$WORKSPACE_DIR" ]] && exit 0

GLOBAL_CONFIG="${SAND_BOX_GLOBAL_CONFIG:-$HOME/.sand-box.json}"
LOCAL_CONFIG="$WORKSPACE_DIR/.sand-box.json"
SCRIPT_EXTS="py|sh|bash|js|ts|rb|pl|cs"

# ═══════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════

is_interactive() {
  [[ "$permission_mode" == "default" && -z "$agent_id" ]]
}

deny() {
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"Sand-box: $1\"}}"
  exit 0
}

allow() {
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
}

ask() {
  if is_interactive; then
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"Sand-box: $1\"}}"
  else
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"Sand-box (non-interactive → deny): $1\"}}"
  fi
  exit 0
}

hard_deny() {
  echo "$1" >&2
  exit 2
}

# Apply a permission value
apply_perm() {
  local perm="$1" reason="$2"
  case "$perm" in
    allow) allow ;;
    deny)  deny "$reason" ;;
    ask)   ask "$reason" ;;
  esac
}

resolve_path() {
  local p="$1"
  p="${p/#\~/$HOME}"
  if [[ "$p" != /* ]]; then
    p="$WORKSPACE_DIR/$p"
  fi
  local -a out=()
  local seg="" remainder="$p"
  while [[ -n "$remainder" ]]; do
    seg="${remainder%%/*}"
    [[ "$remainder" == */* ]] && remainder="${remainder#*/}" || remainder=""
    if [[ -z "$seg" || "$seg" == "." ]]; then continue
    elif [[ "$seg" == ".." ]]; then [[ ${#out[@]} -gt 0 ]] && unset 'out[${#out[@]}-1]'
    else out+=("$seg"); fi
  done
  local result=""
  for seg in "${out[@]}"; do result="$result/$seg"; done
  echo "${result:-/}"
}

realpath_safe() {
  local p="$1"
  [[ ! -e "$p" && ! -L "$p" ]] && { echo "$p"; return; }
  # Linux/WSL2: readlink -f works
  readlink -f "$p" 2>/dev/null && return
  # macOS fallback: cd + pwd -P
  local dir base
  dir=$(cd "$(dirname "$p")" 2>/dev/null && pwd -P) || { echo "$p"; return; }
  base=$(basename "$p")
  if [[ -L "$dir/$base" ]]; then
    local target
    target=$(readlink "$dir/$base" 2>/dev/null) || { echo "$dir/$base"; return; }
    [[ "$target" == /* ]] && echo "$target" || echo "$dir/$target"
  else
    echo "$dir/$base"
  fi
}

# Pure bash text file detection (replaces `file --mime-type`)
is_text_file() {
  [[ ! -f "$1" ]] && return 1
  local nulls
  nulls=$(head -c 512 "$1" 2>/dev/null | LC_ALL=C tr -cd '\0' | wc -c) || return 1
  [[ "${nulls//[[:space:]]/}" -gt 0 ]] && return 1
  return 0
}

# Pure bash timeout (replaces perl alarm)
run_with_timeout() {
  local secs="$1"; shift
  "$@" &
  local pid=$!
  ( sleep "$secs"; kill "$pid" 2>/dev/null ) &
  local watchdog=$!
  wait "$pid" 2>/dev/null
  local ret=$?
  kill "$watchdog" 2>/dev/null 2>&1
  wait "$watchdog" 2>/dev/null 2>&1
  return "$ret"
}

is_within() {
  [[ "$1" == "$2" || "$1" == "$2"/* ]]
}

# ═══════════════════════════════════════════════════════════════
# HARDCODED RULES (non-configurable, active when any profile is on)
# ═══════════════════════════════════════════════════════════════

_is_protected_single() {
  local p="$1"
  [[ "$p" == *"/.sand-box/"* || "$p" == *"/.sand-box" ]] && return 0
  [[ "$p" == "$HOME/.sand-box/"* || "$p" == "$HOME/.sand-box" ]] && return 0
  [[ "$p" == *"/.sand-box.json"* ]] && return 0
  [[ "$p" == "$HOME/.sand-box.json" ]] && return 0
  [[ "$p" == *"/.claude/settings.json"* ]] && return 0
  [[ "$p" == *"/.claude/settings.local.json"* ]] && return 0
  [[ "$p" == "$HOME/.claude/settings.json" ]] && return 0
  [[ "$p" == "$HOME/.claude/settings.local.json" ]] && return 0
  [[ "$p" == *"/.mcp.json"* ]] && return 0
  return 1
}

is_protected() {
  _is_protected_single "$1" && return 0
  local real
  real=$(realpath_safe "$1")
  [[ "$real" != "$1" ]] && _is_protected_single "$real" && return 0
  return 1
}

_is_sensitive_single() {
  local lower
  lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  [[ "$lower" == *"secret"* ]] && return 0
  [[ "$lower" == *".env"* && "$lower" != *".envrc"* ]] && return 0
  [[ "$lower" == *"credentials"* ]] && return 0
  [[ "$lower" == *"private_key"* ]] && return 0
  [[ "$1" == *.enc.* ]] && return 0
  [[ "$lower" == *"id_rsa"* ]] && return 0
  [[ "$lower" == *"id_ed25519"* ]] && return 0
  return 1
}

is_sensitive() {
  _is_sensitive_single "$1" && return 0
  local real
  real=$(realpath_safe "$1")
  [[ "$real" != "$1" ]] && _is_sensitive_single "$real" && return 0
  return 1
}

_is_system_security_single() {
  local p="$1"
  case "$p" in
    /etc/passwd|/etc/shadow|/etc/sudoers|/etc/sudoers.d/*) return 0 ;;
    /etc/security/*|/etc/pam.d/*) return 0 ;;
    "$HOME"/.ssh|"$HOME"/.ssh/*) return 0 ;;
    "$HOME"/.gnupg|"$HOME"/.gnupg/*) return 0 ;;
    "$HOME"/.aws/credentials|"$HOME"/.aws/credentials.*) return 0 ;;
    "$HOME"/.kube/config|"$HOME"/.kube/config.*) return 0 ;;
    "$HOME"/.netrc) return 0 ;;
    "$HOME"/.npmrc) return 0 ;;
    "$HOME"/.docker/config.json) return 0 ;;
    "$HOME"/.git-credentials) return 0 ;;
  esac
  return 1
}

is_system_security() {
  _is_system_security_single "$1" && return 0
  local real
  real=$(realpath_safe "$1")
  [[ "$real" != "$1" ]] && _is_system_security_single "$real" && return 0
  return 1
}

CLAUDE_CONFIG_DIR=$(realpath_safe "$HOME/.claude")
CLAUDE_JSON_REAL=$(realpath_safe "$HOME/.claude.json")

is_config() {
  local p="$1"
  local real
  real=$(realpath_safe "$p")
  is_within "$p" "$HOME/.claude" && return 0
  is_within "$p" "$CLAUDE_CONFIG_DIR" && return 0
  [[ "$p" == "$HOME/.claude.json" || "$p" == "$CLAUDE_JSON_REAL" ]] && return 0
  if [[ "$real" != "$p" ]]; then
    is_within "$real" "$HOME/.claude" && return 0
    is_within "$real" "$CLAUDE_CONFIG_DIR" && return 0
    [[ "$real" == "$HOME/.claude.json" || "$real" == "$CLAUDE_JSON_REAL" ]] && return 0
  fi
  return 1
}

# ═══════════════════════════════════════════════════════════════
# LOAD PROFILES
# ═══════════════════════════════════════════════════════════════

# PROFILE_CONFIGS: array of raw JSON profile config objects
declare -a PROFILE_CONFIGS=()
GLOBAL_CFG=""
HAS_PROFILES=false

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
VALIDATOR="$PLUGIN_ROOT/hooks/validate-config.sh"

if [[ -f "$GLOBAL_CONFIG" ]]; then
  # Validate config — reuse the validation hook logic
  if [[ -x "$VALIDATOR" ]]; then
    val_result=$(echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$GLOBAL_CONFIG\"}}" | bash "$VALIDATOR" 2>/dev/null) || true
    if echo "$val_result" | grep -q '"decision":"block"'; then
      val_reason=$(echo "$val_result" | jq -r '.reason // "invalid config"' 2>/dev/null) || val_reason="invalid config"
      ask "CORRUPTED CONFIG ~/.sand-box.json: $val_reason"
    fi
  fi
  GLOBAL_CFG=$(cat "$GLOBAL_CONFIG")

  # User-scoped profiles (fire for ALL sessions)
  user_profiles=$(echo "$GLOBAL_CFG" | jq -r '.userProfiles // [] | .[]' 2>/dev/null) || user_profiles=""
  if [[ -n "$user_profiles" ]]; then
    while IFS= read -r pname; do
      [[ -z "$pname" ]] && continue
      pcfg=$(echo "$GLOBAL_CFG" | jq -c --arg n "$pname" '.profiles[$n] // empty' 2>/dev/null) || pcfg=""
      [[ -n "$pcfg" && "$pcfg" != "null" ]] && { PROFILE_CONFIGS+=("$pcfg"); HAS_PROFILES=true; }
    done <<< "$user_profiles"
  fi

  # Folder-specific profiles
  folder_profiles=$(echo "$GLOBAL_CFG" | jq -r --arg folder "$WORKSPACE_DIR" '
    .foldersProfile[$folder] // empty |
    if type == "array" then .[] else . end // empty
  ' 2>/dev/null) || folder_profiles=""
  if [[ -n "$folder_profiles" ]]; then
    while IFS= read -r pname; do
      [[ -z "$pname" ]] && continue
      pcfg=$(echo "$GLOBAL_CFG" | jq -c --arg n "$pname" '.profiles[$n] // empty' 2>/dev/null) || pcfg=""
      [[ -n "$pcfg" && "$pcfg" != "null" ]] && { PROFILE_CONFIGS+=("$pcfg"); HAS_PROFILES=true; }
    done <<< "$folder_profiles"
  fi
fi

# Local config: inline profile (shared with team)
if [[ -f "$LOCAL_CONFIG" ]]; then
  if [[ -x "$VALIDATOR" ]]; then
    val_result=$(echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$LOCAL_CONFIG\"}}" | bash "$VALIDATOR" 2>/dev/null) || true
    if echo "$val_result" | grep -q '"decision":"block"'; then
      val_reason=$(echo "$val_result" | jq -r '.reason // "invalid config"' 2>/dev/null) || val_reason="invalid config"
      ask "CORRUPTED CONFIG .sand-box.json: $val_reason"
    fi
  fi
  inline_profile=$(jq -c '.profile // empty' "$LOCAL_CONFIG" 2>/dev/null) || inline_profile=""
  if [[ -n "$inline_profile" && "$inline_profile" != "null" && "$inline_profile" != '""' ]]; then
    PROFILE_CONFIGS+=("$inline_profile")
    HAS_PROFILES=true
  fi
fi

# No profiles → no protection
[[ "$HAS_PROFILES" != "true" ]] && exit 0

# ═══════════════════════════════════════════════════════════════
# RESOLVE MERGED CONFIG FROM ALL PROFILES
# ═══════════════════════════════════════════════════════════════

ALLOWED_DOMAINS="localhost,127.0.0.1"
SCRIPT_CHECKING=true
DEFAULT_READ="allow"
DEFAULT_WRITE="allow"
declare -a PATH_RULES=()
declare -a TOOL_RULES=()

for profile_cfg in "${PROFILE_CONFIGS[@]}"; do
  # Domains (union)
  pd=$(echo "$profile_cfg" | jq -r '.allowedDomains // [] | join(",")' 2>/dev/null) || pd=""
  [[ -n "$pd" ]] && ALLOWED_DOMAINS="$ALLOWED_DOMAINS,$pd"

  # Script checking
  psc=$(echo "$profile_cfg" | jq -r '.scriptChecking // true' 2>/dev/null) || psc="true"
  [[ "$psc" == "false" ]] && SCRIPT_CHECKING=false

  # Default workspace permission (most restrictive wins: deny > ask > allow)
  dr=$(echo "$profile_cfg" | jq -r '.default.read // empty' 2>/dev/null) || dr=""
  dw=$(echo "$profile_cfg" | jq -r '.default.write // empty' 2>/dev/null) || dw=""
  if [[ -n "$dr" ]]; then
    if [[ "$dr" == "deny" ]] || { [[ "$dr" == "ask" ]] && [[ "$DEFAULT_READ" != "deny" ]]; }; then
      DEFAULT_READ="$dr"
    fi
  fi
  if [[ -n "$dw" ]]; then
    if [[ "$dw" == "deny" ]] || { [[ "$dw" == "ask" ]] && [[ "$DEFAULT_WRITE" != "deny" ]]; }; then
      DEFAULT_WRITE="$dw"
    fi
  fi

  # Paths (union)
  pe=$(echo "$profile_cfg" | jq -r '
    .paths // {} | to_entries[] |
    "\(.key)|\(.value.read // "deny")|\(.value.write // "deny")"
  ' 2>/dev/null) || pe=""
  if [[ -n "$pe" ]]; then
    while IFS= read -r entry; do
      [[ -n "$entry" ]] && PATH_RULES+=("$entry")
    done <<< "$pe"
  fi

  # Tools (union)
  te=$(echo "$profile_cfg" | jq -r '.tools // {} | to_entries[] | "\(.key)|\(.value)"' 2>/dev/null) || te=""
  if [[ -n "$te" ]]; then
    while IFS= read -r entry; do
      [[ -n "$entry" ]] && TOOL_RULES+=("$entry")
    done <<< "$te"
  fi
done

# ═══════════════════════════════════════════════════════════════
# TOOL RULES CHECK
# ═══════════════════════════════════════════════════════════════

# Returns: 0 = no match (continue to path checks), exits via deny/ask/allow if matched
check_tool_rules() {
  [[ ${#TOOL_RULES[@]} -eq 0 ]] && return 0

  local tn="$tool_name"
  local cmd="${command_str:-}"

  for entry in "${TOOL_RULES[@]}"; do
    local pattern="${entry%%|*}"
    local perm="${entry##*|}"
    local matched=false

    # Bash(pattern) — match tool_name=Bash + command matches glob
    if [[ "$pattern" == Bash\(* && "$tn" == "Bash" ]]; then
      local inner="${pattern#Bash(}"
      inner="${inner%)}"
      # shellcheck disable=SC2254
      case "$cmd" in
        $inner) matched=true ;;
      esac

    # Pipe-separated exact match: "Read|Grep|Glob"
    elif [[ "$pattern" == *"|"* ]]; then
      IFS='|' read -ra parts <<< "$pattern"
      for part in "${parts[@]}"; do
        [[ "$tn" == "$part" ]] && { matched=true; break; }
      done

    # Wildcard: "mcp__atlassian__*"
    elif [[ "$pattern" == *"*"* ]]; then
      # shellcheck disable=SC2254
      case "$tn" in
        $pattern) matched=true ;;
      esac

    # Exact match
    elif [[ "$tn" == "$pattern" ]]; then
      matched=true
    fi

    if [[ "$matched" == "true" ]]; then
      case "$perm" in
        deny) deny "tool denied by rule: $pattern" ;;
        ask)  ask "tool requires approval: $pattern" ;;
        allow) return 0 ;;  # allow tool itself, continue to path checks
      esac
    fi
  done

  return 0  # no match, continue to path checks
}

# ═══════════════════════════════════════════════════════════════
# PATH RULES CHECK
# ═══════════════════════════════════════════════════════════════

check_path_rules() {
  local resolved="$1" mode="$2"
  [[ ${#PATH_RULES[@]} -eq 0 ]] && return 0
  for entry in "${PATH_RULES[@]}"; do
    local rule_path="${entry%%|*}"
    local rest="${entry#*|}"
    local read_perm="${rest%%|*}"
    local write_perm="${rest##*|}"

    local rule_resolved
    if [[ "$rule_path" == /* ]]; then
      rule_resolved="$rule_path"
    else
      rule_resolved="$WORKSPACE_DIR/$rule_path"
    fi

    if is_within "$resolved" "$rule_resolved"; then
      if [[ "$mode" == "read" ]]; then
        apply_perm "$read_perm" "read access for: $rule_path"
      else
        apply_perm "$write_perm" "write access for: $rule_path"
      fi
    fi
  done
}

# ═══════════════════════════════════════════════════════════════
# ENFORCEMENT
# ═══════════════════════════════════════════════════════════════

check() {
  local resolved="$1" mode="$2"

  # 1. System security — always deny
  is_system_security "$resolved" && deny "access to system security file: $(basename "$resolved")"

  # 2. Sensitive files — always deny
  is_sensitive "$resolved" && deny "access to sensitive file: $(basename "$resolved")"

  # 3. Protected files (hardcoded) — deny write, allow read
  if is_protected "$resolved"; then
    [[ "$mode" == "read" ]] && allow
    deny "write to protected file: $(basename "$resolved")"
  fi

  # 4. Path rules (from profiles)
  check_path_rules "$resolved" "$mode"

  # 5. Workspace — apply default permission
  if is_within "$resolved" "$WORKSPACE_DIR"; then
    if [[ "$mode" == "read" ]]; then
      apply_perm "$DEFAULT_READ" "workspace read"
    else
      apply_perm "$DEFAULT_WRITE" "workspace write"
    fi
  fi

  # 6. Claude config — read-only
  if is_config "$resolved"; then
    [[ "$mode" == "read" ]] && allow
    deny "write to claude config denied"
  fi

  # 7. Everything else — deny
  deny "access outside workspace: $resolved"
}

# ─── Script inspection ───

check_script_file() {
  local script_path="$1"
  local resolved
  resolved=$(resolve_path "$script_path")

  is_within "$resolved" "$WORKSPACE_DIR" || deny "script outside workspace: $resolved"
  [[ ! -f "$resolved" ]] && return 0
  is_text_file "$resolved" || return 0

  # Static grep — paths outside workspace
  local suspicious
  suspicious=$(grep -noE '(^|[[:space:]"'"'"'>])(~|/|\.\.)[^ |;&"'"'"'<>)*]+' "$resolved" 2>/dev/null | head -30) || suspicious=""
  if [[ -n "$suspicious" ]]; then
    while IFS= read -r line; do
      local path_str
      path_str=$(echo "$line" | grep -oE '(~|/|\.\.)[^ |;&"'"'"'<>)*]*' | head -1) || continue
      [[ -z "$path_str" ]] && continue
      local path_resolved
      path_resolved=$(resolve_path "$path_str")
      if ! is_within "$path_resolved" "$WORKSPACE_DIR" && ! is_config "$path_resolved"; then
        deny "script contains path outside workspace: $path_str (in $(basename "$resolved"))"
      fi
    done <<< "$suspicious"
  fi

  # Static grep — network/exfil imports
  local net_imports
  net_imports=$(grep -nE \
    '(import\s+(urllib|requests|http\.client|socket|aiohttp|httpx|ftplib|smtplib|paramiko|xmlrpc)|from\s+(urllib|requests|http|socket|aiohttp|httpx|ftplib|smtplib|paramiko|xmlrpc)\s+import|require\s*\(\s*['"'"'"](https?|net|dgram|node-fetch|axios|got|superagent|request)['"'"'"]\s*\)|fetch\s*\(|\.urlopen\s*\(|\.Request\s*\(|\.get\s*\(.*https?://|\.post\s*\(.*https?://|curl\s|wget\s|nc\s+-|ncat\s|socat\s)' \
    "$resolved" 2>/dev/null | head -10) || net_imports=""

  if [[ -n "$net_imports" ]]; then
    local urls_found
    urls_found=$(grep -oE 'https?://[a-zA-Z0-9._*-]+' "$resolved" 2>/dev/null | sort -u) || urls_found=""

    if [[ -z "$urls_found" ]]; then
      deny "script imports network libraries without visible URL targets (potential exfil): $(basename "$resolved")"
    fi

    while IFS= read -r url; do
      [[ -z "$url" ]] && continue
      local domain
      domain=$(echo "$url" | sed -E 's|https?://||' | cut -d/ -f1 | cut -d: -f1)
      [[ -z "$domain" ]] && continue
      local domain_allowed=false
      IFS=',' read -ra allowed_list <<< "$ALLOWED_DOMAINS"
      for allowed_domain in "${allowed_list[@]}"; do
        allowed_domain=$(echo "$allowed_domain" | xargs)
        [[ "$allowed_domain" == "$domain" ]] && { domain_allowed=true; break; }
        if [[ "$allowed_domain" == \** ]]; then
          local suffix="${allowed_domain#\*}"
          [[ "$domain" == *"$suffix" ]] && { domain_allowed=true; break; }
        fi
      done
      [[ "$domain_allowed" == "false" ]] && deny "script makes network request to non-allowed domain: $domain (in $(basename "$resolved"))"
    done <<< "$urls_found"

    local has_file_ops
    has_file_ops=$(grep -cE '(open\s*\(|readFile|readFileSync|os\.listdir|os\.walk|glob\.|shutil\.|Path\()' "$resolved" 2>/dev/null) || has_file_ops=0
    [[ "$has_file_ops" -gt 0 ]] && deny "script combines file operations with network requests (exfiltration pattern): $(basename "$resolved")"
  fi

  # Haiku LLM eval — last resort
  if [[ "$SCRIPT_CHECKING" == "true" ]]; then
    local script_content
    script_content=$(head -200 "$resolved" 2>/dev/null) || return 0
    [[ -z "$script_content" ]] && return 0

    local haiku_prompt
    haiku_prompt="You are a security sandbox evaluator. Analyze this script for sandbox escape attempts.

SANDBOX CONFIGURATION:
- Workspace (allowed read/write): ${WORKSPACE_DIR}
- Allowed domains: ${ALLOWED_DOMAINS}
- ALWAYS PROTECTED (no write): any .claude/settings*.json, any .sand-box*, any .mcp.json
- ALWAYS DENIED: /etc/passwd, /etc/shadow, ~/.ssh/*, ~/.gnupg/*, ~/.aws/credentials, ~/.kube/config, ~/.netrc, ~/.npmrc, ~/.docker/config.json, ~/.git-credentials
- ALWAYS DENIED: any .env* files, *secret*, *credentials*, *private_key*, *.enc.*, *id_rsa*, *id_ed25519*

DETECT:
1. File read/write/delete OUTSIDE workspace
2. File read/write/delete of PROTECTED or DENIED paths (even inside workspace)
3. Network requests to domains NOT in allowed list
4. Network requests combined with file reads (exfiltration pattern)
5. Subprocess calls that could escape sandbox
6. Dynamic path/URL construction that could bypass static checks
7. Obfuscated imports, base64-encoded commands, eval() with constructed strings

Answer only YES or NOT SURE.

Script content:
${script_content}"

    local haiku_answer
    haiku_answer=$(echo "$haiku_prompt" | run_with_timeout 10 claude -p --model haiku --output-format json 2>/dev/null \
      | jq -r '.result // empty' 2>/dev/null) || haiku_answer=""
    [[ "$haiku_answer" == "YES" ]] && deny "haiku detected sandbox escape attempt in: $(basename "$resolved")"
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════
# MAIN DISPATCH
# ═══════════════════════════════════════════════════════════════

# For Bash, extract command_str early (needed by tool rules matching)
command_str=""
if [[ "$tool_name" == "Bash" ]]; then
  command_str=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || command_str=""
fi

# Tool rules — checked first (deny/ask exits, allow continues to path checks)
check_tool_rules

# ─── Read tools ───

if [[ "$tool_name" == "Read" ]]; then
  p=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [[ -z "$p" ]] && exit 0
  check "$(resolve_path "$p")" read
fi

if [[ "$tool_name" == "Grep" || "$tool_name" == "Glob" ]]; then
  p=$(echo "$input" | jq -r '.tool_input.path // empty' 2>/dev/null) || exit 0
  [[ -z "$p" ]] && exit 0
  check "$(resolve_path "$p")" read
fi

# ─── Write tools ───

if [[ "$tool_name" == "Edit" || "$tool_name" == "Write" ]]; then
  p=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [[ -z "$p" ]] && exit 0
  check "$(resolve_path "$p")" write
fi

if [[ "$tool_name" == "NotebookEdit" ]]; then
  p=$(echo "$input" | jq -r '.tool_input.notebook_path // empty' 2>/dev/null) || exit 0
  [[ -z "$p" ]] && exit 0
  check "$(resolve_path "$p")" write
fi

# ─── Bash ───

if [[ "$tool_name" == "Bash" ]]; then
  [[ -z "$command_str" ]] && exit 0

  base_cmd=$(echo "$command_str" | sed 's/^[A-Z_]*=[^ ]* *//' | awk '{print $1}' | sed 's|.*/||')
  [[ "$base_cmd" == "chmod" ]] && exit 0

  # Hard blocks
  echo "$command_str" | grep -qE '\-\-dangerously-skip-permissions' && hard_deny "Sand-box: --dangerously-skip-permissions is blocked"

  if echo "$base_cmd" | grep -qE "^(claude|claude-code)$"; then
    claude_args=$(echo "$command_str" | grep -oE '(~|\.\.?|/)[^ |;&"'"'"'<>]*' | sort -u) || claude_args=""
    if [[ -n "$claude_args" ]]; then
      while IFS= read -r cp; do
        [[ -z "$cp" ]] && continue
        cp_resolved=$(resolve_path "$cp")
        is_within "$cp_resolved" "$WORKSPACE_DIR" || deny "claude CLI with path outside workspace: $cp_resolved"
      done <<< "$claude_args"
    fi
    echo "$command_str" | grep -qE "\-\-settings" && deny "claude CLI with --settings flag (could bypass sandbox)"
    echo "$command_str" | grep -qE "\-\-dangerously-skip-permissions" && deny "claude CLI with --dangerously-skip-permissions (bypasses sandbox)"
  fi

  # Path checks
  paths_found=$(echo "$command_str" | grep -oE '(~|\.\.?|/)[^ |;&"'"'"'<>]*' | sort -u) || paths_found=""
  [[ -z "$paths_found" ]] && allow

  local_is_write=false
  echo "$command_str" | grep -qE '(>|>>|tee\s|sed\s+-i|mv\s|cp\s|rm\s|mkdir\s|touch\s|install\s)' && local_is_write=true

  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    resolved=$(resolve_path "$p")
    is_system_security "$resolved" && deny "command accessing system security file: $(basename "$resolved")"
    is_sensitive "$resolved" && deny "command accessing sensitive file: $(basename "$resolved")"
    if is_protected "$resolved"; then
      [[ "$local_is_write" == "true" ]] && deny "command writing to protected file: $(basename "$resolved")"
      continue
    fi
    is_within "$resolved" "$WORKSPACE_DIR" && continue
    is_config "$resolved" && continue
    deny "command accessing path outside workspace: $resolved"
  done <<< "$paths_found"

  # Script inspection
  script_file=""
  if echo "$base_cmd" | grep -qE "^(python3?|node|bash|sh|ruby|perl|ts-node|tsx|bun|deno)$"; then
    script_file=$(echo "$command_str" | sed 's/^[A-Z_]*=[^ ]* *//' | awk '{for(i=2;i<=NF;i++){if($i !~ /^-/){print $i; exit}}}')
  elif [[ "$base_cmd" == "dotnet" ]]; then
    script_file=$(echo "$command_str" | grep -oE '[^ ]+\.cs' | head -1) || script_file=""
  elif [[ "$base_cmd" == "npx" ]]; then
    script_file=$(echo "$command_str" | grep -oE '[^ ]+\.(ts|js)' | head -1) || script_file=""
  fi
  if [[ -z "$script_file" ]]; then
    full_cmd_path=$(echo "$command_str" | sed 's/^[A-Z_]*=[^ ]* *//' | awk '{print $1}')
    # Match by extension
    if echo "$full_cmd_path" | grep -qE "\.($SCRIPT_EXTS)$"; then
      script_file="$full_cmd_path"
    else
      # No extension — check if it's an executable text file in workspace (e.g., ./myscript)
      resolved_cmd=$(resolve_path "$full_cmd_path")
      if is_within "$resolved_cmd" "$WORKSPACE_DIR" && [[ -f "$resolved_cmd" && -x "$resolved_cmd" ]]; then
        is_text_file "$resolved_cmd" && script_file="$full_cmd_path"
      fi
    fi
  fi
  [[ -n "$script_file" && "$script_file" != -* ]] && check_script_file "$script_file"

  allow
fi

# MCP, other tools — no opinion
exit 0
