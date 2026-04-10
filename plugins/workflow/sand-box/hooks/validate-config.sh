#!/bin/bash
#
# Sand-box v2 — PostToolUse validation hook
#
# Fires after Edit/Write on *sand-box.json files.
# Strict schema validation — rejects unknown properties, wrong types, dangling references.
#

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name' 2>/dev/null) || exit 0
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0

# Only validate sand-box config files
case "$file_path" in
  */.sand-box.json|*sand-box.json) ;;
  *) exit 0 ;;
esac

[[ ! -f "$file_path" ]] && exit 0

GLOBAL_CONFIG="$HOME/.sand-box.json"
errors=()

# ─── JSON syntax ───

if ! jq empty "$file_path" 2>/dev/null; then
  errors+=("Invalid JSON syntax")
  printf '{"decision":"block","reason":"Sand-box config validation failed:\\n- %s"}' "${errors[0]}"
  exit 0
fi

cfg=$(cat "$file_path")

# ─── Helper: validate a profile object ───

validate_profile() {
  local profile_json="$1" prefix="$2"
  local VALID_PROFILE_KEYS="default allowedDomains scriptChecking paths tools"

  # Check for unknown properties
  unknown=$(echo "$profile_json" | jq -r --arg valid "$VALID_PROFILE_KEYS" '
    ($valid | split(" ")) as $allowed |
    keys[] | select(. as $k | $allowed | index($k) | not)
  ' 2>/dev/null) || unknown=""
  if [[ -n "$unknown" ]]; then
    while IFS= read -r uk; do
      [[ -n "$uk" ]] && errors+=("${prefix}Unknown property: \"$uk\". Valid: $VALID_PROFILE_KEYS")
    done <<< "$unknown"
  fi

  # default
  local def_type
  def_type=$(echo "$profile_json" | jq -r '.default | type // "null"' 2>/dev/null) || def_type="null"
  if [[ "$def_type" != "null" ]]; then
    [[ "$def_type" != "object" ]] && errors+=("${prefix}default must be an object {read, write}, got: $def_type")
    if [[ "$def_type" == "object" ]]; then
      # Check unknown keys in default
      def_unknown=$(echo "$profile_json" | jq -r '.default | keys[] | select(. != "read" and . != "write")' 2>/dev/null) || def_unknown=""
      [[ -n "$def_unknown" ]] && errors+=("${prefix}default has unknown keys: $def_unknown. Valid: read, write")
      # Check values
      for field in read write; do
        val=$(echo "$profile_json" | jq -r ".default.$field // empty" 2>/dev/null) || val=""
        if [[ -n "$val" && "$val" != "allow" && "$val" != "deny" && "$val" != "ask" ]]; then
          errors+=("${prefix}default.$field must be allow|deny|ask, got: $val")
        fi
      done
    fi
  fi

  # allowedDomains
  local ad_type
  ad_type=$(echo "$profile_json" | jq -r '.allowedDomains | type // "null"' 2>/dev/null) || ad_type="null"
  [[ "$ad_type" != "null" && "$ad_type" != "array" ]] && errors+=("${prefix}allowedDomains must be an array, got: $ad_type")

  # scriptChecking
  local sc_type
  sc_type=$(echo "$profile_json" | jq -r '.scriptChecking | type // "null"' 2>/dev/null) || sc_type="null"
  [[ "$sc_type" != "null" && "$sc_type" != "boolean" ]] && errors+=("${prefix}scriptChecking must be a boolean, got: $sc_type")

  # paths
  local paths_type
  paths_type=$(echo "$profile_json" | jq -r '.paths | type // "null"' 2>/dev/null) || paths_type="null"
  if [[ "$paths_type" != "null" ]]; then
    [[ "$paths_type" != "object" ]] && errors+=("${prefix}paths must be an object, got: $paths_type")
    if [[ "$paths_type" == "object" ]]; then
      path_errs=$(echo "$profile_json" | jq -r '
        .paths | to_entries[] |
        (if (.value | type) != "object"
         then "paths[\(.key)] must be {read, write}, got: \(.value | type)" else empty end),
        (if (.value | type) == "object" then
           (.value | keys[] | select(. != "read" and . != "write")) as $uk |
           "paths[\(.key)] has unknown key: \($uk). Valid: read, write"
         else empty end),
        (if (.value | type) == "object" and .value.read != null
            and .value.read != "allow" and .value.read != "deny" and .value.read != "ask"
         then "paths[\(.key)].read must be allow|deny|ask, got: \(.value.read)" else empty end),
        (if (.value | type) == "object" and .value.write != null
            and .value.write != "allow" and .value.write != "deny" and .value.write != "ask"
         then "paths[\(.key)].write must be allow|deny|ask, got: \(.value.write)" else empty end)
      ' 2>/dev/null) || path_errs=""
      if [[ -n "$path_errs" ]]; then
        while IFS= read -r e; do
          [[ -n "$e" ]] && errors+=("${prefix}$e")
        done <<< "$path_errs"
      fi
    fi
  fi

  # tools
  local tools_type
  tools_type=$(echo "$profile_json" | jq -r '.tools | type // "null"' 2>/dev/null) || tools_type="null"
  if [[ "$tools_type" != "null" ]]; then
    [[ "$tools_type" != "object" ]] && errors+=("${prefix}tools must be an object, got: $tools_type")
    if [[ "$tools_type" == "object" ]]; then
      tool_errs=$(echo "$profile_json" | jq -r '
        .tools | to_entries[] |
        if .value != "allow" and .value != "deny" and .value != "ask"
        then "tools[\(.key)] must be allow|deny|ask, got: \(.value)" else empty end
      ' 2>/dev/null) || tool_errs=""
      if [[ -n "$tool_errs" ]]; then
        while IFS= read -r e; do
          [[ -n "$e" ]] && errors+=("${prefix}$e")
        done <<< "$tool_errs"
      fi
    fi
  fi
}

# ─── Global config validation (~/.sand-box.json) ───

if [[ "$file_path" == "$GLOBAL_CONFIG" ]]; then
  VALID_GLOBAL_KEYS="userProfiles profiles foldersProfile"

  # Unknown top-level properties
  unknown=$(echo "$cfg" | jq -r --arg valid "$VALID_GLOBAL_KEYS" '
    ($valid | split(" ")) as $allowed |
    keys[] | select(. as $k | $allowed | index($k) | not)
  ' 2>/dev/null) || unknown=""
  if [[ -n "$unknown" ]]; then
    while IFS= read -r uk; do
      [[ -n "$uk" ]] && errors+=("Unknown top-level property: \"$uk\". Valid: $VALID_GLOBAL_KEYS")
    done <<< "$unknown"
  fi

  # Required fields + types
  has_userProfiles=$(echo "$cfg" | jq 'has("userProfiles")' 2>/dev/null) || has_userProfiles="false"
  has_profiles=$(echo "$cfg" | jq 'has("profiles")' 2>/dev/null) || has_profiles="false"
  has_foldersProfile=$(echo "$cfg" | jq 'has("foldersProfile")' 2>/dev/null) || has_foldersProfile="false"

  [[ "$has_userProfiles" != "true" ]] && errors+=("Missing required: userProfiles (string[])")
  [[ "$has_profiles" != "true" ]] && errors+=("Missing required: profiles (object)")
  [[ "$has_foldersProfile" != "true" ]] && errors+=("Missing required: foldersProfile (object)")

  if [[ "$has_userProfiles" == "true" ]]; then
    t=$(echo "$cfg" | jq -r '.userProfiles | type' 2>/dev/null) || t=""
    [[ "$t" != "array" ]] && errors+=("userProfiles must be an array, got: $t")
  fi

  if [[ "$has_profiles" == "true" ]]; then
    t=$(echo "$cfg" | jq -r '.profiles | type' 2>/dev/null) || t=""
    [[ "$t" != "object" ]] && errors+=("profiles must be an object, got: $t")
  fi

  if [[ "$has_foldersProfile" == "true" ]]; then
    t=$(echo "$cfg" | jq -r '.foldersProfile | type' 2>/dev/null) || t=""
    [[ "$t" != "object" ]] && errors+=("foldersProfile must be an object, got: $t")
  fi

  # Referenced profiles must exist
  if [[ "$has_profiles" == "true" && "$has_userProfiles" == "true" ]]; then
    missing=$(echo "$cfg" | jq -r '.userProfiles[] as $p | if .profiles[$p] == null then $p else empty end' 2>/dev/null) || missing=""
    if [[ -n "$missing" ]]; then
      while IFS= read -r m; do
        [[ -n "$m" ]] && errors+=("userProfiles references undefined profile: \"$m\"")
      done <<< "$missing"
    fi
  fi

  if [[ "$has_profiles" == "true" && "$has_foldersProfile" == "true" ]]; then
    missing=$(echo "$cfg" | jq -r '
      [.foldersProfile[] | if type == "array" then .[] else . end] | unique[] as $p |
      if .profiles[$p] == null then $p else empty end
    ' 2>/dev/null) || missing=""
    if [[ -n "$missing" ]]; then
      while IFS= read -r m; do
        [[ -n "$m" ]] && errors+=("foldersProfile references undefined profile: \"$m\"")
      done <<< "$missing"
    fi
  fi

  # Validate each profile
  if [[ "$has_profiles" == "true" ]]; then
    profile_names=$(echo "$cfg" | jq -r '.profiles | keys[]' 2>/dev/null) || profile_names=""
    if [[ -n "$profile_names" ]]; then
      while IFS= read -r pname; do
        [[ -z "$pname" ]] && continue
        pcfg=$(echo "$cfg" | jq -c --arg n "$pname" '.profiles[$n]' 2>/dev/null) || continue
        validate_profile "$pcfg" "Profile \"$pname\": "
      done <<< "$profile_names"
    fi
  fi
fi

# ─── Local config validation (<project>/.sand-box.json) ───

if [[ "$file_path" != "$GLOBAL_CONFIG" ]]; then
  VALID_LOCAL_KEYS="profile"

  # Unknown top-level properties
  unknown=$(echo "$cfg" | jq -r --arg valid "$VALID_LOCAL_KEYS" '
    ($valid | split(" ")) as $allowed |
    keys[] | select(. as $k | $allowed | index($k) | not)
  ' 2>/dev/null) || unknown=""
  if [[ -n "$unknown" ]]; then
    while IFS= read -r uk; do
      [[ -n "$uk" ]] && errors+=("Unknown property: \"$uk\". Valid: $VALID_LOCAL_KEYS")
    done <<< "$unknown"
  fi

  has_profile=$(echo "$cfg" | jq 'has("profile")' 2>/dev/null) || has_profile="false"
  [[ "$has_profile" != "true" ]] && errors+=("Missing required: profile (inline profile object)")

  if [[ "$has_profile" == "true" ]]; then
    pt=$(echo "$cfg" | jq -r '.profile | type' 2>/dev/null) || pt=""
    [[ "$pt" != "object" ]] && errors+=("profile must be an object, got: $pt")
    if [[ "$pt" == "object" ]]; then
      pcfg=$(echo "$cfg" | jq -c '.profile' 2>/dev/null) || pcfg="{}"
      validate_profile "$pcfg" "Inline profile: "
    fi
  fi
fi

# ─── Report ───

if [[ ${#errors[@]} -gt 0 ]]; then
  error_msg=$(printf '\\n- %s' "${errors[@]}")
  printf '{"decision":"block","reason":"Sand-box config validation failed:%s"}' "$error_msg"
  exit 0
fi

exit 0
