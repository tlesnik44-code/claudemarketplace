#!/bin/bash
# Claude Profile status line — shows active profile badge with subscription type,
# git info, model, context usage, session cost, and lines changed.
# Install: add to ~/.claude/settings.json → statusLine.command

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$cwd")

# Git branch and status
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        if ! git -C "$cwd" --no-optional-locks diff --quiet 2>/dev/null || ! git -C "$cwd" --no-optional-locks diff --cached --quiet 2>/dev/null; then
            git_info=$(printf " \033[1;34mgit:(\033[0;31m%s\033[1;34m) \033[0;33m✗\033[0m" "$branch")
        else
            git_info=$(printf " \033[1;34mgit:(\033[0;31m%s\033[1;34m)\033[0m" "$branch")
        fi
    fi
fi

# Model information
model_name=$(echo "$input" | jq -r '.model.display_name')
model_id=$(echo "$input" | jq -r '.model.id')
version=$(echo "$input" | jq -r '.version')

# Context window
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Cost calculation
case "$model_id" in
    *opus*)   input_rate=15;  output_rate=75 ;;
    *sonnet*) input_rate=3;   output_rate=15 ;;
    *haiku*)  input_rate=0.8; output_rate=4 ;;
    *)        input_rate=3;   output_rate=15 ;;
esac

if [ -n "$total_input" ] && [ "$total_input" != "null" ] && [ -n "$total_output" ] && [ "$total_output" != "null" ]; then
    input_cost=$(echo "scale=4; $total_input * $input_rate / 1000000" | bc)
    output_cost=$(echo "scale=4; $total_output * $output_rate / 1000000" | bc)
    total_cost=$(echo "scale=4; $input_cost + $output_cost" | bc)
    session_cost=$(printf "\$%.4f" "$total_cost")
else
    session_cost="\$0.0000"
fi

# Context usage
if [ -n "$used_pct" ]; then
    context_info=$(printf "%.1f%%" "$used_pct")
else
    context_info="0.0%"
fi

# Limits
total_k=$(echo "scale=0; $context_size / 1000" | bc)
limits_info="${total_k}K"

# Lines added/removed
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
lines_info=$(printf "\033[0;32m+%s\033[0m/\033[0;31m-%s\033[0m" "$lines_added" "$lines_removed")

# Agent name
agent_name=$(echo "$input" | jq -r '.agent.name // empty')
agent_info=""
if [ -n "$agent_name" ]; then
    agent_info=$(printf " \033[0;90m|\033[0m \033[0;93m%s\033[0m" "$agent_name")
fi

# Project directory
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
project_name=""
if [ -n "$project_dir" ] && [ "$project_dir" != "null" ]; then
    project_name=$(basename "$project_dir")
fi

# Subscription type from keychain (cached)
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
cache_file="$config_dir/subscription-cache.txt"
if [ -f "$cache_file" ]; then
    sub_type=$(cat "$cache_file")
else
    resolved_dir=$(cd "$config_dir" 2>/dev/null && pwd || echo "$config_dir")
    if [ "$resolved_dir" = "$HOME/.claude" ]; then
        keychain_svc="Claude Code-credentials"
    else
        hash=$(echo -n "$resolved_dir" | shasum -a 256 | cut -c1-8)
        keychain_svc="Claude Code-credentials-$hash"
    fi
    sub_type=$(security find-generic-password -s "$keychain_svc" -w 2>/dev/null | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['claudeAiOauth']['subscriptionType'])" 2>/dev/null)
    if [ -n "$sub_type" ]; then
        echo "$sub_type" > "$cache_file"
    fi
fi

sub_label=""
if [ -n "$sub_type" ]; then
    case "$sub_type" in
        max_20|max_5|max*) sub_label="Max" ;;
        pro)               sub_label="Pro" ;;
        team)              sub_label="Team" ;;
        enterprise)        sub_label="Enterprise" ;;
        *)                 sub_label="$(echo "$sub_type" | python3 -c "import sys; print(sys.stdin.read().strip().title())")" ;;
    esac
fi

# Profile badge with dynamic RGB color
if [[ "$CLAUDE_CONFIG_DIR" =~ clp/profiles/([^/]+) ]]; then
    _profile_raw="${BASH_REMATCH[1]}"
elif [[ "$CLAUDE_CONFIG_DIR" == *"claude-personal"* ]]; then
    _profile_raw="personal"
else
    _profile_raw="work"
fi

profile_name=$(echo "$_profile_raw" | python3 -c "import sys; print(sys.stdin.read().strip().title())")

# Derive RGB from profile name letters
_rsum=0; _gsum=0; _bsum=0
_rcnt=0; _gcnt=0; _bcnt=0
for ((_i=0; _i<${#_profile_raw}; _i++)); do
    _ascii=$(printf '%d' "'${_profile_raw:_i:1}")
    _pos=$((_ascii - 96))
    if (( _pos >= 1 && _pos <= 7 )); then
        _bsum=$((_bsum + _ascii * (_i + 1))); _bcnt=$((_bcnt + 1))
    elif (( _pos >= 8 && _pos <= 16 )); then
        _gsum=$((_gsum + _ascii * (_i + 1))); _gcnt=$((_gcnt + 1))
    elif (( _pos >= 17 && _pos <= 26 )); then
        _rsum=$((_rsum + _ascii * (_i + 1))); _rcnt=$((_rcnt + 1))
    fi
done
_r=$(( _rcnt > 0 ? (_rsum % 121) + 80 : 80 ))
_g=$(( _gcnt > 0 ? (_gsum % 121) + 80 : 80 ))
_b=$(( _bcnt > 0 ? (_bsum % 121) + 80 : 80 ))

if [ -n "$sub_label" ]; then
    profile_badge=$(printf "\033[1;97;48;2;%d;%d;%dm %s · %s \033[0m" "$_r" "$_g" "$_b" "$profile_name" "$sub_label")
else
    profile_badge=$(printf "\033[1;97;48;2;%d;%d;%dm %s \033[0m" "$_r" "$_g" "$_b" "$profile_name")
fi

# Additional info bar
additional_info=$(printf " \033[0;90m[\033[0m\033[0;35m%s\033[0m \033[0;90m|\033[0m \033[0;90mv%s\033[0m \033[0;90m|\033[0m \033[0;33m%s used\033[0m \033[0;90m|\033[0m \033[0;32m%s\033[0m \033[0;90m|\033[0m \033[0;36m%s\033[0m \033[0;90m|\033[0m %s%s\033[0;90m]\033[0m" \
    "$model_name" "$version" "$context_info" "$session_cost" "$limits_info" "$lines_info" "$agent_info")

# Project dir display
project_info=""
if [ -n "$project_name" ] && [ "$project_name" != "$dir_name" ]; then
    project_info=$(printf " \033[0;90min\033[0m \033[0;33m%s\033[0m" "$project_name")
fi

# Print the status line
printf "%s \033[1;32m➜\033[0m \033[0;36m%s\033[0m%s%s%s" "$profile_badge" "$dir_name" "$project_info" "$git_info" "$additional_info"