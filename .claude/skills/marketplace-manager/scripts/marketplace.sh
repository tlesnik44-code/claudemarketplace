#!/usr/bin/env bash
# marketplace.sh — Portable Claude Code plugin marketplace client
#
# Manages marketplaces and installs plugins for any AI coding agent.
# Works with Claude, Cursor, Windsurf, Augment, and Codex.
#
# Usage: marketplace.sh <command> [args...]
# Run:   marketplace.sh help

set -euo pipefail

# --- Configuration ---
STATE_DIR=".ai-marketplace"
CONFIG_FILE="$STATE_DIR/config.json"
INSTALLED_FILE="$STATE_DIR/installed.json"
SOURCES_DIR="$STATE_DIR/sources"
LOCAL_MARKETPLACE=".claude-plugin/marketplace.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Dependency Check ---
for cmd in git jq; do
  command -v "$cmd" &>/dev/null || { echo -e "${RED}Error: '$cmd' is required. Install it first.${NC}"; exit 1; }
done

# --- Init ---
init() {
  mkdir -p "$SOURCES_DIR"
  [[ -f "$CONFIG_FILE" ]] || echo '{"marketplaces":[]}' > "$CONFIG_FILE"
  [[ -f "$INSTALLED_FILE" ]] || echo '{"plugins":[]}' > "$INSTALLED_FILE"

  # Auto-register local marketplace
  if [[ -f "$LOCAL_MARKETPLACE" ]]; then
    local name
    name=$(jq -r '.name' "$LOCAL_MARKETPLACE")
    local exists
    exists=$(jq --arg n "$name" '[.marketplaces[] | select(.name == $n)] | length' "$CONFIG_FILE")
    if [[ "$exists" == "0" ]]; then
      local entry
      entry=$(jq -n --arg name "$name" --arg source "local" '{name: $name, source: $source, path: "."}')
      jq --argjson e "$entry" '.marketplaces += [$e]' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
      mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    fi
  fi
}

# --- Helpers ---

get_marketplace_path() {
  local name="$1"
  local source
  source=$(jq -r --arg n "$name" '.marketplaces[] | select(.name == $n) | .source' "$CONFIG_FILE")
  if [[ "$source" == "local" ]]; then
    echo "."
  else
    echo "$SOURCES_DIR/$name"
  fi
}

get_marketplace_json() {
  local name="$1"
  local path
  path=$(get_marketplace_path "$name")
  echo "$path/.claude-plugin/marketplace.json"
}

resolve_plugin_marketplace() {
  # Parse "plugin@marketplace" or just "plugin"
  local input="$1"
  if [[ "$input" == *"@"* ]]; then
    PLUGIN_NAME="${input%%@*}"
    MARKETPLACE_NAME="${input##*@}"
  else
    PLUGIN_NAME="$input"
    MARKETPLACE_NAME=""
    # Find first marketplace containing this plugin
    while IFS= read -r mname; do
      local mj
      mj=$(get_marketplace_json "$mname")
      if [[ -f "$mj" ]]; then
        local found
        found=$(jq --arg p "$PLUGIN_NAME" '[.plugins[] | select(.name == $p)] | length' "$mj")
        if [[ "$found" -gt 0 ]]; then
          MARKETPLACE_NAME="$mname"
          break
        fi
      fi
    done < <(jq -r '.marketplaces[].name' "$CONFIG_FILE")
    if [[ -z "$MARKETPLACE_NAME" ]]; then
      echo -e "${RED}Error: Plugin '$PLUGIN_NAME' not found in any marketplace${NC}"
      exit 1
    fi
  fi
}

get_plugin_source_dir() {
  local marketplace="$1"
  local plugin="$2"
  local mj
  mj=$(get_marketplace_json "$marketplace")
  local mpath
  mpath=$(get_marketplace_path "$marketplace")

  local source
  source=$(jq -r --arg p "$plugin" '.plugins[] | select(.name == $p) | .source' "$mj")

  if [[ "$source" == ./* ]]; then
    echo "$mpath/$source"
  else
    local root
    root=$(jq -r '.metadata.pluginRoot // ""' "$mj")
    if [[ -n "$root" ]]; then
      echo "$mpath/${root%/}/$source"
    else
      echo "$mpath/$source"
    fi
  fi
}

detect_agent() {
  if [[ -d ".cursor" ]]; then echo "cursor"
  elif [[ -d ".windsurf" ]]; then echo "windsurf"
  elif [[ -d ".augment" ]]; then echo "augment"
  elif [[ -d ".claude" ]]; then echo "claude"
  else echo "codex"
  fi
}

# --- Frontmatter Parsing ---

parse_frontmatter() {
  local file="$1"
  local in_fm=0 past_fm=0 line_num=0
  PARSED_FM="" PARSED_BODY=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))
    if [[ $line_num -eq 1 && "$line" == "---" ]]; then in_fm=1; continue; fi
    if [[ $in_fm -eq 1 && "$line" == "---" ]]; then in_fm=0; past_fm=1; continue; fi
    if [[ $in_fm -eq 1 ]]; then
      PARSED_FM+="$line"$'\n'
    elif [[ $past_fm -eq 1 ]]; then
      PARSED_BODY+="$line"$'\n'
    fi
  done < "$file"
}

extract_field() {
  echo "$PARSED_FM" | grep "^${1}:" | sed "s/^${1}:[[:space:]]*//" | head -1
}

sanitize_body() {
  echo "$1" | sed 's|\${CLAUDE_PLUGIN_ROOT}/scripts/|./scripts/ (from marketplace plugin) |g' \
             | sed 's|\${CLAUDE_PLUGIN_ROOT}|<plugin-root>|g'
}

strip_leading_blanks() {
  echo "$1" | sed '/./,$!d'
}

# --- Marketplace Commands ---

cmd_marketplace_add() {
  local url="${1:?Usage: marketplace add <git-url>}"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf '$tmp_dir'" EXIT

  echo -e "${CYAN}Cloning marketplace...${NC}"
  git clone --depth 1 "$url" "$tmp_dir" 2>&1 | tail -1

  local mj="$tmp_dir/.claude-plugin/marketplace.json"
  if [[ ! -f "$mj" ]]; then
    echo -e "${RED}Error: No .claude-plugin/marketplace.json found in repository${NC}"
    exit 1
  fi

  local name
  name=$(jq -r '.name' "$mj")

  rm -rf "$SOURCES_DIR/$name"
  cp -r "$tmp_dir" "$SOURCES_DIR/$name"

  local entry
  entry=$(jq -n --arg name "$name" --arg source "remote" --arg url "$url" \
    '{name: $name, source: $source, url: $url}')
  jq --argjson e "$entry" '.marketplaces = [.marketplaces[] | select(.name != $e.name)] + [$e]' \
    "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
  mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

  local count
  count=$(jq '.plugins | length' "$mj")
  echo -e "${GREEN}Added marketplace:${NC} $name ($count plugins)"
  trap - EXIT
}

cmd_marketplace_update() {
  local target="${1:-}"

  if [[ -n "$target" ]]; then
    local mpath
    mpath=$(get_marketplace_path "$target")
    local source
    source=$(jq -r --arg n "$target" '.marketplaces[] | select(.name == $n) | .source' "$CONFIG_FILE")
    if [[ "$source" == "local" ]]; then
      echo -e "${YELLOW}$target is a local marketplace — update via git pull in repo root${NC}"
    elif [[ -d "$mpath" ]]; then
      echo -e "${CYAN}Updating $target...${NC}"
      git -C "$mpath" pull --rebase 2>&1 | tail -1
      echo -e "${GREEN}Updated:${NC} $target"
    else
      echo -e "${RED}Error: Marketplace '$target' source not found${NC}"
      exit 1
    fi
    return
  fi

  # Update all remote marketplaces
  while IFS= read -r line; do
    local mname msource
    mname=$(echo "$line" | jq -r '.name')
    msource=$(echo "$line" | jq -r '.source')
    if [[ "$msource" == "remote" ]]; then
      echo -e "${CYAN}Updating $mname...${NC}"
      git -C "$SOURCES_DIR/$mname" pull --rebase 2>&1 | tail -1
      echo -e "${GREEN}Updated:${NC} $mname"
    fi
  done < <(jq -c '.marketplaces[]' "$CONFIG_FILE")
}

cmd_marketplace_list() {
  echo ""
  echo -e "${BOLD}Registered Marketplaces${NC}"
  echo ""
  printf "  %-35s %-10s %s\n" "NAME" "SOURCE" "PLUGINS"
  printf "  %-35s %-10s %s\n" "----" "------" "-------"

  while IFS= read -r line; do
    local mname msource mcount
    mname=$(echo "$line" | jq -r '.name')
    msource=$(echo "$line" | jq -r '.source')
    local mj
    mj=$(get_marketplace_json "$mname")
    if [[ -f "$mj" ]]; then
      mcount=$(jq '.plugins | length' "$mj")
    else
      mcount="?"
    fi
    printf "  %-35s %-10s %s\n" "$mname" "$msource" "$mcount"
  done < <(jq -c '.marketplaces[]' "$CONFIG_FILE")
  echo ""
}

cmd_marketplace_remove() {
  local name="${1:?Usage: marketplace remove <name>}"
  local source
  source=$(jq -r --arg n "$name" '.marketplaces[] | select(.name == $n) | .source' "$CONFIG_FILE")

  if [[ -z "$source" ]]; then
    echo -e "${RED}Error: Marketplace '$name' not found${NC}"
    exit 1
  fi

  if [[ "$source" == "remote" ]]; then
    rm -rf "$SOURCES_DIR/$name"
  fi

  jq --arg n "$name" '.marketplaces = [.marketplaces[] | select(.name != $n)]' \
    "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
  mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

  echo -e "${GREEN}Removed:${NC} $name"
}

# --- Plugin Commands ---

cmd_plugins() {
  local filter="${1:-}"
  echo ""
  echo -e "${BOLD}Available Plugins${NC}"
  echo ""
  printf "  %-20s %-10s %-12s %s\n" "NAME" "VERSION" "CATEGORY" "DESCRIPTION"
  printf "  %-20s %-10s %-12s %s\n" "----" "-------" "--------" "-----------"

  while IFS= read -r mname; do
    if [[ -n "$filter" && "$mname" != "$filter" ]]; then continue; fi
    local mj
    mj=$(get_marketplace_json "$mname")
    [[ -f "$mj" ]] || continue

    while IFS= read -r plugin; do
      local pname pver pcat pdesc
      pname=$(echo "$plugin" | jq -r '.name')
      pver=$(echo "$plugin" | jq -r '.version // "—"')
      pcat=$(echo "$plugin" | jq -r '.category // "—"')
      pdesc=$(echo "$plugin" | jq -r '.description // ""')
      # Truncate description for display
      if [[ ${#pdesc} -gt 60 ]]; then
        pdesc="${pdesc:0:57}..."
      fi
      printf "  %-20s %-10s %-12s %s\n" "$pname" "$pver" "$pcat" "$pdesc"
    done < <(jq -c '.plugins[]' "$mj")
  done < <(jq -r '.marketplaces[].name' "$CONFIG_FILE")
  echo ""
}

cmd_view() {
  local input="${1:?Usage: view <plugin>[@<marketplace>]}"
  resolve_plugin_marketplace "$input"

  local plugin_dir
  plugin_dir=$(get_plugin_source_dir "$MARKETPLACE_NAME" "$PLUGIN_NAME")

  echo ""
  echo -e "${BOLD}Plugin: ${PLUGIN_NAME}${NC} (from ${MARKETPLACE_NAME})"
  echo ""

  # Show plugin.json info
  local pj="$plugin_dir/.claude-plugin/plugin.json"
  if [[ -f "$pj" ]]; then
    echo -e "${CYAN}Manifest:${NC}"
    echo "  Name:        $(jq -r '.name' "$pj")"
    echo "  Description: $(jq -r '.description // "—"' "$pj")"
    echo "  Version:     $(jq -r '.version // "—"' "$pj")"
    echo "  Author:      $(jq -r '.author.name // "—"' "$pj")"
    echo "  Keywords:    $(jq -r '(.keywords // []) | join(", ")' "$pj")"
    echo ""
  fi

  # List skills
  local skill_files
  skill_files=$(find "$plugin_dir/skills" -name 'SKILL.md' 2>/dev/null | sort)
  if [[ -n "$skill_files" ]]; then
    echo -e "${CYAN}Skills:${NC}"
    printf "  %-30s %s\n" "NAME" "DESCRIPTION"
    printf "  %-30s %s\n" "----" "-----------"
    for sf in $skill_files; do
      parse_frontmatter "$sf"
      local sname sdesc
      sname=$(extract_field "name")
      sdesc=$(extract_field "description")
      [[ -z "$sname" ]] && sname=$(basename "$(dirname "$sf")")
      if [[ ${#sdesc} -gt 60 ]]; then sdesc="${sdesc:0:57}..."; fi
      printf "  %-30s %s\n" "$sname" "$sdesc"
    done
    echo ""
  fi

  # Show README excerpt
  local readme="$plugin_dir/README.md"
  if [[ -f "$readme" ]]; then
    echo -e "${CYAN}README:${NC}"
    head -20 "$readme" | sed 's/^/  /'
    echo ""
  fi
}

# --- Install/Uninstall ---

convert_skill() {
  local agent="$1" plugin_name="$2" skill_name="$3" description="$4" body="$5" target="$6"
  local sanitized
  sanitized=$(sanitize_body "$body")

  case "$agent" in
    augment)
      mkdir -p "$target/.augment/rules"
      local outfile="$target/.augment/rules/${plugin_name}--${skill_name}.md"
      printf '%s\n\n%s\n\n%s\n' "# ${skill_name}" "${description}" "${sanitized}" > "$outfile"
      echo -e "  ${GREEN}+${NC} .augment/rules/${plugin_name}--${skill_name}.md"
      ;;

    cursor)
      mkdir -p "$target/.cursor/rules"
      local outfile="$target/.cursor/rules/${plugin_name}--${skill_name}.mdc"
      printf '%s\n%s\n%s\n\n%s\n\n%s\n' "---" "description: ${description}" "alwaysApply: false" "---" "" > "$outfile"
      printf '%s\n\n%s\n' "# ${skill_name}" "${sanitized}" >> "$outfile"
      echo -e "  ${GREEN}+${NC} .cursor/rules/${plugin_name}--${skill_name}.mdc"
      ;;

    windsurf)
      mkdir -p "$target/.windsurf/rules"
      local outfile="$target/.windsurf/rules/${plugin_name}--${skill_name}.md"
      local header="# ${skill_name}"$'\n\n'"${description}"$'\n\n'
      local max_body=$((5500 - ${#header}))
      local truncated=""
      if [[ ${#sanitized} -gt $max_body ]]; then
        sanitized="${sanitized:0:$max_body}"$'\n\n'"<!-- Truncated for Windsurf 6K limit. Full version in marketplace plugin. -->"
        truncated="yes"
      fi
      printf '%s\n\n%s\n\n%s\n' "# ${skill_name}" "${description}" "${sanitized}" > "$outfile"
      echo -e "  ${GREEN}+${NC} .windsurf/rules/${plugin_name}--${skill_name}.md"
      if [[ -n "$truncated" ]]; then echo -e "  ${YELLOW}!${NC} Content truncated for Windsurf 6K limit"; fi
      ;;

    codex)
      local outfile="$target/AGENTS.md"
      if [[ ! -f "$outfile" ]]; then
        printf '%s\n\n' "# Agent Instructions" > "$outfile"
      fi
      printf '\n%s\n\n%s\n\n%s\n\n%s\n' "## ${plugin_name}: ${skill_name}" "${description}" "${sanitized}" "---" >> "$outfile"
      echo -e "  ${GREEN}+${NC} AGENTS.md (appended ${plugin_name}:${skill_name})"
      ;;

    claude)
      local dest="$target/.claude/plugins/${plugin_name}"
      echo -e "  ${YELLOW}Note:${NC} For Claude, use '/plugin install ${plugin_name}@marketplace' natively."
      echo -e "  Copying plugin source to $dest as fallback..."
      mkdir -p "$dest"
      cp -r "$plugin_dir/." "$dest/"
      echo -e "  ${GREEN}+${NC} .claude/plugins/${plugin_name}/"
      ;;
  esac
}

cmd_install() {
  local input="" agent="" target="."

  # Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent="$2"; shift 2 ;;
      --target) target="$2"; shift 2 ;;
      *) input="$1"; shift ;;
    esac
  done

  [[ -z "$input" ]] && { echo -e "${RED}Usage: install <plugin>[@<marketplace>] [--agent <agent>] [--target <dir>]${NC}"; exit 1; }

  resolve_plugin_marketplace "$input"
  [[ -z "$agent" ]] && agent=$(detect_agent)

  local plugin_dir
  plugin_dir=$(get_plugin_source_dir "$MARKETPLACE_NAME" "$PLUGIN_NAME")

  if [[ ! -d "$plugin_dir/skills" ]]; then
    echo -e "${RED}Error: No skills/ directory in plugin '$PLUGIN_NAME' at $plugin_dir${NC}"
    exit 1
  fi

  echo ""
  echo -e "${BOLD}Installing ${PLUGIN_NAME}${NC} → ${agent} (target: ${target})"
  echo ""

  local agents=("$agent")
  [[ "$agent" == "all" ]] && agents=(augment cursor windsurf codex)

  local skill_files
  skill_files=$(find "$plugin_dir/skills" -name 'SKILL.md' 2>/dev/null | sort)
  local count=0

  for sf in $skill_files; do
    parse_frontmatter "$sf"
    local sname sdesc sbody
    sname=$(extract_field "name")
    sdesc=$(extract_field "description")
    sbody=$(strip_leading_blanks "$PARSED_BODY")
    [[ -z "$sname" ]] && sname=$(basename "$(dirname "$sf")")
    [[ -z "$sdesc" ]] && sdesc="Skill from ${PLUGIN_NAME} plugin"

    for a in "${agents[@]}"; do
      convert_skill "$a" "$PLUGIN_NAME" "$sname" "$sdesc" "$sbody" "$target"
      count=$((count + 1))
    done
  done

  # Track installation
  local record
  record=$(jq -n --arg p "$PLUGIN_NAME" --arg m "$MARKETPLACE_NAME" --arg a "$agent" --arg t "$target" \
    '{plugin: $p, marketplace: $m, agent: $a, target: $t, installed_at: (now | todate)}')
  jq --argjson r "$record" '.plugins = [.plugins[] | select(.plugin != $r.plugin or .agent != $r.agent)] + [$r]' \
    "$INSTALLED_FILE" > "$INSTALLED_FILE.tmp"
  mv "$INSTALLED_FILE.tmp" "$INSTALLED_FILE"

  echo ""
  echo -e "${GREEN}Done:${NC} ${count} rule(s) installed"
  echo ""
}

cmd_uninstall() {
  local input="" agent="" target="."

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent="$2"; shift 2 ;;
      --target) target="$2"; shift 2 ;;
      *) input="$1"; shift ;;
    esac
  done

  [[ -z "$input" ]] && { echo -e "${RED}Usage: uninstall <plugin> [--agent <agent>] [--target <dir>]${NC}"; exit 1; }

  local plugin_name="$input"
  [[ -z "$agent" ]] && agent=$(detect_agent)

  echo ""
  echo -e "${BOLD}Uninstalling ${plugin_name}${NC} from ${agent}"
  echo ""

  local agents=("$agent")
  [[ "$agent" == "all" ]] && agents=(augment cursor windsurf codex claude)
  local count=0

  for a in "${agents[@]}"; do
    case "$a" in
      augment)
        for f in "$target/.augment/rules/${plugin_name}--"*.md; do
          [[ -f "$f" ]] && { rm "$f"; echo -e "  ${RED}-${NC} $(basename "$f")"; count=$((count + 1)); }
        done
        ;;
      cursor)
        for f in "$target/.cursor/rules/${plugin_name}--"*.mdc; do
          [[ -f "$f" ]] && { rm "$f"; echo -e "  ${RED}-${NC} $(basename "$f")"; count=$((count + 1)); }
        done
        ;;
      windsurf)
        for f in "$target/.windsurf/rules/${plugin_name}--"*.md; do
          [[ -f "$f" ]] && { rm "$f"; echo -e "  ${RED}-${NC} $(basename "$f")"; count=$((count + 1)); }
        done
        ;;
      codex)
        if [[ -f "$target/AGENTS.md" ]]; then
          # Remove sections for this plugin
          local tmp
          tmp=$(mktemp)
          python3 -c "
import re, sys
content = open('$target/AGENTS.md').read()
pattern = r'\n## ${plugin_name}: .*?(?=\n## |\Z)'
cleaned = re.sub(pattern, '', content, flags=re.DOTALL)
open('$tmp', 'w').write(cleaned.rstrip() + '\n')
" 2>/dev/null && {
            mv "$tmp" "$target/AGENTS.md"
            echo -e "  ${RED}-${NC} AGENTS.md (removed ${plugin_name} sections)"
            count=$((count + 1))
          }
        fi
        ;;
      claude)
        if [[ -d "$target/.claude/plugins/${plugin_name}" ]]; then
          rm -rf "$target/.claude/plugins/${plugin_name}"
          echo -e "  ${RED}-${NC} .claude/plugins/${plugin_name}/"
          count=$((count + 1))
        fi
        ;;
    esac
  done

  # Update tracking
  jq --arg p "$plugin_name" --arg a "$agent" \
    '.plugins = [.plugins[] | select(.plugin != $p or .agent != $a)]' \
    "$INSTALLED_FILE" > "$INSTALLED_FILE.tmp"
  mv "$INSTALLED_FILE.tmp" "$INSTALLED_FILE"

  echo ""
  echo -e "${GREEN}Done:${NC} ${count} rule(s) removed"
  echo ""
}

cmd_update_plugin() {
  local input="" agent="" target="."

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent="$2"; shift 2 ;;
      --target) target="$2"; shift 2 ;;
      *) input="$1"; shift ;;
    esac
  done

  [[ -z "$input" ]] && { echo -e "${RED}Usage: update-plugin <plugin>[@<marketplace>] [--agent <agent>] [--target <dir>]${NC}"; exit 1; }

  # Parse plugin@marketplace
  local pname
  if [[ "$input" == *"@"* ]]; then
    pname="${input%%@*}"
  else
    pname="$input"
  fi

  [[ -z "$agent" ]] && agent=$(detect_agent)

  echo -e "${CYAN}Updating plugin: ${pname}${NC}"

  # Uninstall old
  cmd_uninstall "$pname" --agent "$agent" --target "$target"

  # Update marketplace source if remote
  resolve_plugin_marketplace "$input"
  local msource
  msource=$(jq -r --arg n "$MARKETPLACE_NAME" '.marketplaces[] | select(.name == $n) | .source' "$CONFIG_FILE")
  if [[ "$msource" == "remote" ]]; then
    cmd_marketplace_update "$MARKETPLACE_NAME"
  fi

  # Reinstall
  cmd_install "$input" --agent "$agent" --target "$target"
}

# --- Help ---

cmd_help() {
  echo ""
  echo -e "${BOLD}marketplace.sh${NC} — Portable Claude Code plugin marketplace client"
  echo ""
  echo -e "${BOLD}Marketplace Commands:${NC}"
  echo "  marketplace add <git-url>          Clone and register a marketplace"
  echo "  marketplace update [<name>]        Pull latest from remote"
  echo "  marketplace list                   Show registered marketplaces"
  echo "  marketplace remove <name>          Unregister and delete"
  echo ""
  echo -e "${BOLD}Plugin Commands:${NC}"
  echo "  plugins [<marketplace>]            List available plugins"
  echo "  view <plugin>[@<marketplace>]      Show plugin details"
  echo "  install <plugin>[@<mp>] [opts]     Install plugin for an agent"
  echo "  uninstall <plugin> [opts]          Remove installed plugin rules"
  echo "  update-plugin <plugin>[@<mp>] [opts]  Uninstall + reinstall"
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  --agent <name>    Target: claude|augment|cursor|windsurf|codex|all"
  echo "  --target <dir>    Project directory (default: current directory)"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  marketplace.sh marketplace add https://github.com/eskygroup/esky-ai-knowledge-base"
  echo "  marketplace.sh plugins"
  echo "  marketplace.sh install esky-devops --agent cursor"
  echo "  marketplace.sh install esky-dotnet --agent all --target ~/my-project"
  echo "  marketplace.sh uninstall esky-devops --agent cursor"
  echo ""
}

# --- Main Dispatch ---

init

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  marketplace)
    SUB="${1:-list}"
    shift || true
    case "$SUB" in
      add)    cmd_marketplace_add "$@" ;;
      update) cmd_marketplace_update "$@" ;;
      list)   cmd_marketplace_list ;;
      remove) cmd_marketplace_remove "$@" ;;
      *)      echo -e "${RED}Unknown: marketplace $SUB${NC}"; cmd_help; exit 1 ;;
    esac
    ;;
  plugins)       cmd_plugins "$@" ;;
  view)          cmd_view "$@" ;;
  install)       cmd_install "$@" ;;
  uninstall)     cmd_uninstall "$@" ;;
  update-plugin) cmd_update_plugin "$@" ;;
  help|--help|-h) cmd_help ;;
  *)             echo -e "${RED}Unknown command: $COMMAND${NC}"; cmd_help; exit 1 ;;
esac
