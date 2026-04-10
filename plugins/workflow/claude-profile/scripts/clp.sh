#!/usr/bin/env bash
# clp — Claude Profile: Switch between Claude Code + Desktop profiles
#
# Usage:
#   clp capture <name>        — Capture current config as a named profile
#   clp use <name>            — Switch to a profile
#   clp list                  — List available profiles
#   clp current               — Show active profile
#   clp remove <name>         — Remove a profile
#   clp uninstall [name]      — Restore real folders from profile, remove symlinks
#   clp apply <name> <folder> — Apply profile to a folder with launcher scripts
#   clp path                  — Show/manage config paths
#   clp install               — Install clp + claude wrapper to ~/.clp/bin
#   clp version               — Show version
#   clp help                  — Show help
#
# Supports: macOS, Linux

set -euo pipefail

# ─── Version ───────────────────────────────────────────────────────────────────

CLP_VERSION="1.1.0"

# ─── OS Detection ─────────────────────────────────────────────────────────────

detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      echo "unsupported" ;;
    esac
}

OS="$(detect_os)"
if [[ "$OS" == "unsupported" ]]; then
    echo "Error: Unsupported operating system '$(uname -s)'. Only macOS and Linux are supported." >&2
    exit 1
fi

# ─── Configuration ─────────────────────────────────────────────────────────────

CLP_HOME="${CLP_HOME:-$HOME/.clp}"
CLP_BIN="$CLP_HOME/bin"
PROFILES_BASE="$CLP_HOME/profiles"
META_FILE="$CLP_HOME/.active"
COMMANDS_FILE="$CLP_HOME/commands"
PATHS_FILE="$CLP_HOME/paths"
# OS defaults
DEFAULT_CODE_DIR="$HOME/.claude"
DEFAULT_CODE_JSON="$HOME/.claude.json"

# Claude Desktop (macOS only)
CLAUDE_DESKTOP_APP="/Applications/Claude.app"
CLAUDE_DESKTOP_BIN="$CLAUDE_DESKTOP_APP/Contents/MacOS/Claude"
CLP_ICON="$CLP_HOME/clp-icon.icns"
DESKTOP_APPS_DIR="$HOME/Applications"

# Load overrides from .paths file
load_path_overrides() {
    CLAUDE_CODE_DIR="$DEFAULT_CODE_DIR"
    CLAUDE_CODE_JSON="$DEFAULT_CODE_JSON"

    if [[ -f "$PATHS_FILE" ]]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            value="${value#"${value%%[![:space:]]*}"}"
            case "$key" in
                CODE) CLAUDE_CODE_DIR="$value" ;;
                MCP)  CLAUDE_CODE_JSON="$value" ;;
            esac
        done < "$PATHS_FILE"
    fi
}

load_path_overrides

# ─── Colors ────────────────────────────────────────────────────────────────────

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
BOLD=$'\033[1m'
NC=$'\033[0m'

# ─── Helpers ───────────────────────────────────────────────────────────────────

info()  { echo -e "${BLUE}ℹ${NC}  $*"; }
ok()    { echo -e "${GREEN}✓${NC}  $*"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $*"; }
err()   { echo -e "${RED}✗${NC}  $*" >&2; }

die() { err "$@"; exit 1; }

confirm() {
    local prompt="$1"
    local answer
    echo -en "${YELLOW}?${NC}  ${prompt} [y/N] "
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ─── Claude Process Management ────────────────────────────────────────────────

kill_claude_sessions() {
    local found_something=false
    local messages=()

    # --- Detect Claude Desktop App ---
    local desktop_pid=""
    desktop_pid="$(pgrep -x "Claude" 2>/dev/null || true)"

    if [[ -n "$desktop_pid" ]]; then
        found_something=true
        messages+=("Claude Desktop App (PID: $desktop_pid)")
    fi

    # --- Detect Claude Code CLI sessions ---
    # Find the claude process that is the parent of this script's shell
    local parent_claude_pid=""
    local ppid_check=$$
    while [[ "$ppid_check" -gt 1 ]]; do
        ppid_check="$(ps -p "$ppid_check" -o ppid= 2>/dev/null | tr -d ' ')" || break
        local pcmd
        pcmd="$(ps -p "$ppid_check" -o args= 2>/dev/null)" || break
        if [[ "$pcmd" == *".local/share/claude/versions"* ]]; then
            parent_claude_pid="$ppid_check"
            break
        fi
    done

    local cli_pids=""
    while read -r pid; do
        [[ -z "$pid" ]] && continue
        [[ "$pid" == "$$" ]] && continue
        [[ "$pid" == "$parent_claude_pid" ]] && continue
        cli_pids="${cli_pids:+$cli_pids }$pid"
    done < <(pgrep -f "\.local/share/claude/versions" 2>/dev/null)

    if [[ -n "$cli_pids" ]]; then
        found_something=true
        local count
        count="$(echo "$cli_pids" | wc -w | tr -d ' ')"
        messages+=("$count Claude Code CLI session(s)")
    fi

    # --- Nothing running, nothing to do ---
    [[ "$found_something" == false ]] && return 0

    # --- Single prompt for everything ---
    warn "Running Claude instances detected:"
    for msg in "${messages[@]}"; do
        echo "     • $msg"
    done
    if confirm "Kill them to proceed?"; then
        # Kill Desktop App
        if [[ -n "$desktop_pid" ]]; then
            kill "$desktop_pid" 2>/dev/null || true
            ok "Claude Desktop App killed."
        fi
        # Kill CLI sessions
        if [[ -n "$cli_pids" ]]; then
            kill $cli_pids 2>/dev/null || true
            sleep 1
            local remaining=""
            for pid in $cli_pids; do
                kill -0 "$pid" 2>/dev/null && remaining="$remaining $pid"
            done
            if [[ -n "$remaining" ]]; then
                warn "Graceful kill timed out, force killing..."
                kill -9 $remaining 2>/dev/null || true
                sleep 1
            fi
            ok "Claude Code CLI sessions killed."
        fi
    else
        die "Cannot switch profiles while other Claude instances are running. Aborting."
    fi
}

# ─── Status Detection ─────────────────────────────────────────────────────────

has_claude_code_cli() {
    command -v claude >/dev/null 2>&1
}

has_claude_code_config() {
    [[ -d "$CLAUDE_CODE_DIR" || -L "$CLAUDE_CODE_DIR" ]]
}

# ─── Claude Desktop (macOS only) ─────────────────────────────────────────────

has_claude_desktop() {
    [[ "$OS" == "macos" && -d "$CLAUDE_DESKTOP_APP" ]]
}

# Detect which CLP profile Claude Desktop is running with (if any).
# Returns profile name, "default" if running without --user-data-dir, or empty if not running.
detect_desktop_profile() {
    local user_data_dir=""
    user_data_dir="$(ps -eo args= 2>/dev/null | grep -F "Claude.app/Contents/MacOS/Claude" | grep -oE '\-\-user-data-dir=[^ ]+' | head -1 | sed 's/--user-data-dir=//')" || true

    if ! pgrep -f "Claude.app/Contents/MacOS/Claude" >/dev/null 2>&1; then
        echo ""
        return
    fi

    if [[ -z "$user_data_dir" ]]; then
        echo "default"
        return
    fi

    # Try to extract profile name from path like .../profiles/<name>/claude-desktop
    local profile_name=""
    if [[ "$user_data_dir" == *"/profiles/"*"/claude-desktop"* ]]; then
        profile_name="$(echo "$user_data_dir" | sed 's|.*/profiles/||' | sed 's|/claude-desktop.*||')"
    fi

    if [[ -n "$profile_name" ]]; then
        echo "$profile_name"
    else
        echo "unknown"
    fi
}

_ensure_clp_icon() {
    [[ -f "$CLP_ICON" ]] && return 0
    [[ "$OS" != "macos" ]] && return 0
    command -v swift >/dev/null 2>&1 || return 0

    info "Generating CLP icon..."
    local tmpdir
    tmpdir="$(mktemp -d)"
    local iconset="$tmpdir/clp.iconset"
    mkdir -p "$iconset"

    swift - "$iconset" <<'SWIFT' 2>/dev/null || { warn "Icon generation failed (non-critical)."; rm -rf "$tmpdir"; return 0; }
import Cocoa
let iconsetPath = CommandLine.arguments[1]
func createIcon(size: Int) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { img.unlockFocus(); return img }
    let s = CGFloat(size), center = s / 2, radius = s * 0.45
    let c1 = CGColor(red: 0.85, green: 0.45, blue: 0.32, alpha: 1.0)
    let c2 = CGColor(red: 0.72, green: 0.35, blue: 0.24, alpha: 1.0)
    ctx.saveGState()
    ctx.addPath(CGPath(ellipseIn: CGRect(x: center-radius, y: center-radius, width: radius*2, height: radius*2), transform: nil))
    ctx.clip()
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [c1, c2] as CFArray, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(g, start: CGPoint(x: center, y: center+radius), end: CGPoint(x: center, y: center-radius), options: [])
    ctx.restoreGState()
    let cream = CGColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 0.95)
    ctx.setFillColor(cream)
    let sy = center + s * 0.12, arm = s * 0.18, w = arm * 0.22
    let sp = CGMutablePath()
    sp.addEllipse(in: CGRect(x: center-w, y: sy-arm, width: w*2, height: arm*2))
    sp.addEllipse(in: CGRect(x: center-arm, y: sy-w, width: arm*2, height: w*2))
    ctx.addPath(sp); ctx.fillPath()
    let font = NSFont.systemFont(ofSize: s * 0.16, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 0.95)]
    let text = "CLP" as NSString, ts = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: center - ts.width/2, y: center - s * 0.28), withAttributes: attrs)
    img.unlockFocus(); return img
}
for (size, name) in [(16,"icon_16x16.png"),(32,"icon_16x16@2x.png"),(32,"icon_32x32.png"),(64,"icon_32x32@2x.png"),(128,"icon_128x128.png"),(256,"icon_128x128@2x.png"),(256,"icon_256x256.png"),(512,"icon_256x256@2x.png"),(512,"icon_512x512.png"),(1024,"icon_512x512@2x.png")] {
    let icon = createIcon(size: size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    icon.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name)"))
}
SWIFT

    iconutil -c icns "$iconset" -o "$CLP_ICON" 2>/dev/null || true
    rm -rf "$tmpdir"

    if [[ -f "$CLP_ICON" ]]; then
        ok "CLP icon generated."
    fi
}

_create_desktop_app() {
    local app_name="$1"         # e.g. "Claude CLP" or "Claude mywork"
    local applescript_body="$2" # AppleScript source code

    local app_path="$DESKTOP_APPS_DIR/${app_name}.app"

    # Compile AppleScript into a proper .app bundle
    osacompile -o "$app_path" -e "$applescript_body" 2>/dev/null \
        || { err "Failed to compile ${app_name}.app"; return 1; }

    # Replace default icon with CLP icon
    _ensure_clp_icon
    if [[ -f "$CLP_ICON" ]]; then
        cp "$CLP_ICON" "$app_path/Contents/Resources/applet.icns"
        # Force macOS to pick up the new icon
        touch "$app_path"
        /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$app_path" 2>/dev/null || true
    fi

    ok "Created ${BOLD}${app_name}.app${NC} in ~/Applications/"
}

_remove_desktop_app() {
    local app_name="$1"
    local app_path="$DESKTOP_APPS_DIR/${app_name}.app"

    if [[ -d "$app_path" ]]; then
        rm -rf "$app_path"
        ok "Removed ${BOLD}${app_name}.app${NC} from ~/Applications/"
    fi
}

_ensure_main_desktop_app() {
    has_claude_desktop || return 0

    local app_path="$DESKTOP_APPS_DIR/Claude CLP.app"
    [[ -d "$app_path" ]] && return 0

    mkdir -p "$DESKTOP_APPS_DIR"

    local script='
set clpHome to (POSIX path of (path to home folder)) & ".clp"
try
    set activeProfile to do shell script "cat " & quoted form of (clpHome & "/.active")
    set desktopDir to clpHome & "/profiles/" & activeProfile & "/claude-desktop"
    set dirExists to do shell script "test -d " & quoted form of desktopDir & " && echo yes || echo no"
    if dirExists is "yes" then
        do shell script "open -n -a Claude --args --user-data-dir=" & quoted form of desktopDir
    else
        do shell script "open -a Claude"
    end if
on error
    do shell script "open -a Claude"
end try'

    _create_desktop_app "Claude CLP" "$script"
}

_create_named_desktop_app() {
    local command_name="$1"
    local profile_name="$2"

    has_claude_desktop || return 0
    mkdir -p "$DESKTOP_APPS_DIR"

    local script="
set clpHome to (POSIX path of (path to home folder)) & \".clp\"
set desktopDir to clpHome & \"/profiles/${profile_name}/claude-desktop\"
do shell script \"mkdir -p \" & quoted form of desktopDir
do shell script \"open -n -a Claude --args --user-data-dir=\" & quoted form of desktopDir"

    _create_desktop_app "Claude ${command_name}" "$script"
}

# ─── Profile Directory Layout ─────────────────────────────────────────────────
# ~/.clp/
#   .active                          — name of active profile
#   paths                            — path overrides
#   profiles/
#     <profile>/
#       claude-code/                 — copy of Claude Code config dir
#       claude-code-json/            — contains .claude.json

profile_dir() { echo "$PROFILES_BASE/$1"; }

validate_profile_name() {
    local name="$1"
    if [[ -z "$name" ]]; then
        die "Profile name cannot be empty."
    fi
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        die "Profile name must contain only letters, numbers, hyphens, and underscores."
    fi
}

# ─── Symlink Management ───────────────────────────────────────────────────────

create_links() {
    local pdir="$1"
    if [[ -d "$pdir/claude-code" ]]; then
        ln -sfn "$pdir/claude-code" "$CLAUDE_CODE_DIR"
    fi
    if [[ -f "$pdir/claude-code-json/.claude.json" ]]; then
        ln -sf "$pdir/claude-code-json/.claude.json" "$CLAUDE_CODE_JSON"
    fi
}

# ─── Save Current State to Profile ────────────────────────────────────────────

save_current_to_profile() {
    local pdir="$1"

    # Claude Code config dir
    if [[ -L "$CLAUDE_CODE_DIR" ]]; then
        local resolved
        resolved="$(readlink "$CLAUDE_CODE_DIR")"
        if [[ -d "$resolved" && "$resolved" != "$pdir/claude-code" ]]; then
            mkdir -p "$pdir/claude-code"
            rsync -a --delete "$resolved/" "$pdir/claude-code/"
        fi
    elif [[ -d "$CLAUDE_CODE_DIR" ]]; then
        mkdir -p "$pdir/claude-code"
        rsync -a --delete "$CLAUDE_CODE_DIR/" "$pdir/claude-code/"
    fi

    # MCP config file
    if [[ -L "$CLAUDE_CODE_JSON" ]]; then
        local resolved
        resolved="$(readlink "$CLAUDE_CODE_JSON")"
        if [[ -f "$resolved" && "$resolved" != "$pdir/claude-code-json/.claude.json" ]]; then
            mkdir -p "$pdir/claude-code-json"
            cp "$resolved" "$pdir/claude-code-json/.claude.json"
        fi
    elif [[ -f "$CLAUDE_CODE_JSON" ]]; then
        mkdir -p "$pdir/claude-code-json"
        cp "$CLAUDE_CODE_JSON" "$pdir/claude-code-json/.claude.json"
    fi
}

convert_to_symlinks() {
    local pdir="$1"

    if [[ -d "$CLAUDE_CODE_DIR" && ! -L "$CLAUDE_CODE_DIR" ]]; then
        rm -rf "$CLAUDE_CODE_DIR"
    fi

    if [[ -f "$CLAUDE_CODE_JSON" && ! -L "$CLAUDE_CODE_JSON" ]]; then
        rm -f "$CLAUDE_CODE_JSON"
    fi

    create_links "$pdir"
}

# ─── Commands ──────────────────────────────────────────────────────────────────

cmd_capture() {
    local name="${1:-}"
    validate_profile_name "$name"

    local pdir
    pdir="$(profile_dir "$name")"

    if [[ -d "$pdir" ]]; then
        if ! confirm "Profile '$name' already exists. Overwrite?"; then
            die "Aborted."
        fi
        info "Overwriting profile '${BOLD}$name${NC}'..."
    fi

    mkdir -p "$pdir"

    info "Capturing current configuration as profile '${BOLD}$name${NC}'..."

    if ! has_claude_code_config && [[ ! -f "$CLAUDE_CODE_JSON" && ! -L "$CLAUDE_CODE_JSON" ]]; then
        die "Nothing to capture. Claude Code config not found."
    fi

    save_current_to_profile "$pdir"

    # Create desktop data dir for this profile
    if has_claude_desktop; then
        mkdir -p "$pdir/claude-desktop"
    fi

    ok "Profile '${BOLD}$name${NC}' captured."
    echo ""
    info "Contents saved:"
    [[ -d "$pdir/claude-code" ]]                  && info "  Claude Code config → $pdir/claude-code/"
    [[ -f "$pdir/claude-code-json/.claude.json" ]] && info "  Claude Code MCP    → $pdir/claude-code-json/"
    [[ -d "$pdir/claude-desktop" ]]               && info "  Claude Desktop     → $pdir/claude-desktop/"
    echo ""
    info "To activate this profile, run: ${BOLD}clp use $name${NC}"
    info "To create a named command:     ${BOLD}clp use $name <command>${NC}"
}

cmd_use() {
    local name="${1:-}"
    local command_name="${2:-}"
    validate_profile_name "$name"

    local pdir
    pdir="$(profile_dir "$name")"

    if [[ ! -d "$pdir" ]]; then
        die "Profile '$name' does not exist. Use 'clp list' to see available profiles."
    fi

    # Handle named command
    if [[ -n "$command_name" ]]; then
        _use_with_command "$name" "$command_name"
        return $?
    fi

    local current=""
    if [[ -f "$META_FILE" ]]; then
        current="$(cat "$META_FILE")"
    fi

    if [[ "$current" == "$name" ]]; then
        ok "Already on profile '${BOLD}$name${NC}'."
        return 0
    fi

    kill_claude_sessions

    # Save current state back to active profile
    if [[ -n "$current" && -d "$(profile_dir "$current")" ]]; then
        info "Saving current state back to profile '${BOLD}$current${NC}'..."
        save_current_to_profile "$(profile_dir "$current")"
    fi

    # Remove current symlinks
    for path in "$CLAUDE_CODE_DIR" "$CLAUDE_CODE_JSON"; do
        if [[ -L "$path" ]]; then
            rm "$path"
        elif [[ -e "$path" ]]; then
            warn "Found non-symlink at $path — backing up to ${path}.bak"
            mv "$path" "${path}.bak.$(date +%s)"
        fi
    done

    create_links "$pdir"
    echo "$name" > "$META_FILE"

    ok "Switched to profile '${BOLD}$name${NC}'."
    echo ""
    info "Symlinks:"
    [[ -L "$CLAUDE_CODE_DIR" ]]  && info "  $CLAUDE_CODE_DIR → $pdir/claude-code/"
    [[ -L "$CLAUDE_CODE_JSON" ]] && info "  $CLAUDE_CODE_JSON → $pdir/claude-code-json/.claude.json"

    # ── Desktop integration (macOS only) ──
    if has_claude_desktop; then
        # Warn if Desktop is running on a different profile
        local desktop_profile
        desktop_profile="$(detect_desktop_profile)"
        if [[ -n "$desktop_profile" && "$desktop_profile" != "$name" ]]; then
            echo ""
            warn "Claude Desktop is running on profile '${BOLD}$desktop_profile${NC}'."
            warn "Running multiple desktop profiles simultaneously is not recommended."
            warn "Restart Desktop or use ${BOLD}Claude CLP.app${NC} to switch."
        fi

        # First-time desktop config for this profile
        if [[ ! -d "$pdir/claude-desktop" ]]; then
            echo ""
            info "Desktop not yet configured for profile '${BOLD}$name${NC}'."
            warn "You'll need to log in again in Claude Desktop."
            if confirm "Configure desktop for this profile?"; then
                mkdir -p "$pdir/claude-desktop"
                ok "Created desktop data dir at $pdir/claude-desktop/"
            fi
        fi

        # Ensure the main wrapper app exists
        _ensure_main_desktop_app
    fi
}

_use_with_command() {
    local name="$1"
    local command_name="$2"

    # Validate command name (same rules as profile name)
    if [[ ! "$command_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        die "Command name must contain only letters, numbers, hyphens, and underscores."
    fi

    # Don't allow overriding the main claude wrapper
    if [[ "$command_name" == "claude" ]]; then
        die "Cannot use 'claude' as a command name — it's the main wrapper."
    fi

    # Check if command already exists for a DIFFERENT profile
    if [[ -f "$COMMANDS_FILE" ]]; then
        while IFS='=' read -r cmd prof; do
            [[ -z "$cmd" || "$cmd" =~ ^# ]] && continue
            if [[ "$cmd" == "$command_name" && "$prof" != "$name" ]]; then
                die "Command '$command_name' already exists for profile '$prof'. Remove it first with: clp remove -c $command_name"
            fi
        done < "$COMMANDS_FILE"
    fi

    # Remove existing command for this profile (if any, different name)
    if [[ -f "$COMMANDS_FILE" ]]; then
        local old_cmd=""
        while IFS='=' read -r cmd prof; do
            [[ -z "$cmd" || "$cmd" =~ ^# ]] && continue
            if [[ "$prof" == "$name" && "$cmd" != "$command_name" ]]; then
                old_cmd="$cmd"
            fi
        done < "$COMMANDS_FILE"
        if [[ -n "$old_cmd" ]]; then
            rm -f "$CLP_BIN/$old_cmd"
            # Remove from registry
            local tmpfile
            tmpfile="$(mktemp)"
            grep -v "^${old_cmd}=" "$COMMANDS_FILE" > "$tmpfile" 2>/dev/null || true
            mv "$tmpfile" "$COMMANDS_FILE"
            info "Removed previous command '${BOLD}$old_cmd${NC}' for profile '$name'."
        fi
    fi

    # Create the named wrapper
    _create_named_wrapper "$command_name" "$name"

    # Update registry
    touch "$COMMANDS_FILE"
    # Remove any existing entry for this command
    local tmpfile
    tmpfile="$(mktemp)"
    grep -v "^${command_name}=" "$COMMANDS_FILE" > "$tmpfile" 2>/dev/null || true
    mv "$tmpfile" "$COMMANDS_FILE"
    echo "${command_name}=${name}" >> "$COMMANDS_FILE"

    ok "Command '${BOLD}$command_name${NC}' → profile '${BOLD}$name${NC}'"
    info "  CLI wrapper: $CLP_BIN/$command_name"

    # Create named Desktop app (macOS only)
    _create_named_desktop_app "$command_name" "$name"
}

cmd_list() {
    if [[ ! -d "$PROFILES_BASE" ]]; then
        info "No profiles found. Use 'clp capture <name>' to create one."
        return 0
    fi

    local current=""
    if [[ -f "$META_FILE" ]]; then
        current="$(cat "$META_FILE")"
    fi

    local found=false
    echo -e "${BOLD}Available profiles:${NC}"
    echo ""
    for dir in "$PROFILES_BASE"/*/; do
        [[ -d "$dir" ]] || continue
        found=true
        local name
        name="$(basename "$dir")"
        local desktop_badge=""
        if [[ -d "$PROFILES_BASE/$name/claude-desktop" ]]; then
            desktop_badge="  ${BLUE}[desktop]${NC}"
        fi
        if [[ "$name" == "$current" ]]; then
            echo -e "  ${GREEN}● $name${NC}  (active)${desktop_badge}"
        else
            echo -e "  ○ $name${desktop_badge}"
        fi
    done

    if [[ "$found" == false ]]; then
        info "No profiles found. Use 'clp capture <name>' to create one."
    fi
    echo ""

    # Show named commands
    if [[ -f "$COMMANDS_FILE" && -s "$COMMANDS_FILE" ]]; then
        echo -e "${BOLD}Named commands:${NC}"
        echo ""
        while IFS='=' read -r cmd prof; do
            [[ -z "$cmd" || "$cmd" =~ ^# ]] && continue
            if [[ -x "$CLP_BIN/$cmd" ]]; then
                echo -e "  ${BLUE}$cmd${NC} → $prof"
            else
                echo -e "  ${RED}$cmd${NC} → $prof  (wrapper missing)"
            fi
        done < "$COMMANDS_FILE"
        echo ""
    fi
}

cmd_current() {
    if [[ -f "$META_FILE" ]]; then
        local current
        current="$(cat "$META_FILE")"
        echo -e "Active profile: ${GREEN}${BOLD}$current${NC}"
    else
        info "No active profile. Use 'clp capture <name>' to create one."
    fi
}

cmd_remove() {
    # Handle -c flag for removing named commands
    if [[ "${1:-}" == "-c" ]]; then
        local command_name="${2:-}"
        if [[ -z "$command_name" ]]; then
            die "Usage: clp remove -c <command>"
        fi
        _remove_command "$command_name"
        return $?
    fi

    local name="${1:-}"
    validate_profile_name "$name"

    local pdir
    pdir="$(profile_dir "$name")"

    if [[ ! -d "$pdir" ]]; then
        die "Profile '$name' does not exist."
    fi

    local current=""
    if [[ -f "$META_FILE" ]]; then
        current="$(cat "$META_FILE")"
    fi

    if [[ "$current" == "$name" ]]; then
        die "Cannot remove active profile. Switch first."
    fi

    if ! confirm "Remove profile '$name'? This cannot be undone."; then
        die "Aborted."
    fi

    # Remove any named command for this profile
    if [[ -f "$COMMANDS_FILE" ]]; then
        while IFS='=' read -r cmd prof; do
            [[ -z "$cmd" || "$cmd" =~ ^# ]] && continue
            if [[ "$prof" == "$name" ]]; then
                rm -f "$CLP_BIN/$cmd"
                _remove_desktop_app "Claude ${cmd}"
                info "Removed command '${BOLD}$cmd${NC}'."
            fi
        done < "$COMMANDS_FILE"
        local tmpfile
        tmpfile="$(mktemp)"
        grep -v "=$name$" "$COMMANDS_FILE" > "$tmpfile" 2>/dev/null || true
        mv "$tmpfile" "$COMMANDS_FILE"
        [[ ! -s "$COMMANDS_FILE" ]] && rm -f "$COMMANDS_FILE"
    fi

    rm -rf "$pdir"
    ok "Profile '${BOLD}$name${NC}' removed."
}

_remove_command() {
    local command_name="$1"

    if [[ ! -f "$COMMANDS_FILE" ]]; then
        die "No named commands registered."
    fi

    local found=false
    while IFS='=' read -r cmd prof; do
        [[ -z "$cmd" || "$cmd" =~ ^# ]] && continue
        if [[ "$cmd" == "$command_name" ]]; then
            found=true
            break
        fi
    done < "$COMMANDS_FILE"

    if [[ "$found" == false ]]; then
        die "Command '$command_name' not found."
    fi

    # Remove CLI wrapper
    rm -f "$CLP_BIN/$command_name"

    # Remove Desktop app
    _remove_desktop_app "Claude ${command_name}"

    # Remove from registry
    local tmpfile
    tmpfile="$(mktemp)"
    grep -v "^${command_name}=" "$COMMANDS_FILE" > "$tmpfile" 2>/dev/null || true
    mv "$tmpfile" "$COMMANDS_FILE"

    # Clean up empty file
    if [[ ! -s "$COMMANDS_FILE" ]]; then
        rm -f "$COMMANDS_FILE"
    fi

    ok "Command '${BOLD}$command_name${NC}' removed."
}

cmd_uninstall() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        if [[ -f "$META_FILE" ]]; then
            name="$(cat "$META_FILE")"
        else
            die "No active profile. Specify a profile name: clp uninstall <name>"
        fi
    fi

    validate_profile_name "$name"

    local pdir
    pdir="$(profile_dir "$name")"

    if [[ ! -d "$pdir" ]]; then
        die "Profile '$name' does not exist."
    fi

    if ! confirm "Uninstall profile '$name'? This will restore original folders from the profile and remove all symlinks."; then
        die "Aborted."
    fi

    kill_claude_sessions

    # Remove symlinks
    for path in "$CLAUDE_CODE_DIR" "$CLAUDE_CODE_JSON"; do
        if [[ -L "$path" ]]; then
            rm "$path"
        fi
    done

    # Restore from profile
    if [[ -d "$pdir/claude-code" ]]; then
        rsync -a "$pdir/claude-code/" "$CLAUDE_CODE_DIR/"
        ok "Restored $CLAUDE_CODE_DIR"
    fi

    if [[ -f "$pdir/claude-code-json/.claude.json" ]]; then
        cp "$pdir/claude-code-json/.claude.json" "$CLAUDE_CODE_JSON"
        ok "Restored $CLAUDE_CODE_JSON"
    fi

    rm -f "$META_FILE"

    ok "Profile '${BOLD}$name${NC}' uninstalled. Config paths restored to real directories."
}

_create_named_wrapper() {
    local command_name="$1"
    local profile_name="$2"

    cat > "$CLP_BIN/$command_name" <<WRAPPER
#!/usr/bin/env bash
# clp named wrapper — runs claude with profile '$profile_name'

CLP_HOME="\${CLP_HOME:-\$HOME/.clp}"
PROFILE_DIR="\$CLP_HOME/profiles/$profile_name/claude-code"

if [[ ! -d "\$PROFILE_DIR" ]]; then
    echo "clp: profile '$profile_name' not found at \$PROFILE_DIR" >&2
    exit 1
fi

export CLAUDE_CONFIG_DIR="\$PROFILE_DIR"

echo ""
echo -e "  \033[1;36m▶ CLP\033[0m  \033[1;33m$profile_name\033[0m  (\033[0;36m$command_name\033[0m)"
echo ""

# Find the real claude binary (skip clp wrappers)
REAL_CLAUDE=""
if [[ -L "\$HOME/.local/bin/claude" ]]; then
    REAL_CLAUDE="\$(readlink "\$HOME/.local/bin/claude")"
fi
if [[ -z "\$REAL_CLAUDE" || ! -x "\$REAL_CLAUDE" ]]; then
    VERSIONS_DIR="\$HOME/.local/share/claude/versions"
    if [[ -d "\$VERSIONS_DIR" ]]; then
        REAL_CLAUDE="\$(ls -t "\$VERSIONS_DIR" 2>/dev/null | head -1)"
        if [[ -n "\$REAL_CLAUDE" ]]; then
            REAL_CLAUDE="\$VERSIONS_DIR/\$REAL_CLAUDE"
        fi
    fi
fi
if [[ -z "\$REAL_CLAUDE" || ! -x "\$REAL_CLAUDE" ]]; then
    SEARCH_PATH="\${PATH//\$CLP_HOME\/bin:/}"
    SEARCH_PATH="\${SEARCH_PATH//:$CLP_HOME\/bin/}"
    REAL_CLAUDE="\$(PATH="\$SEARCH_PATH" command -v claude 2>/dev/null)" || true
fi

if [[ -z "\$REAL_CLAUDE" || ! -x "\$REAL_CLAUDE" ]]; then
    echo "clp: cannot find real claude binary. Is Claude Code installed?" >&2
    exit 1
fi

# Detect if current directory (or any component) is a symlink
# If so, add the real path so Claude sees both workspaces
EXTRA_ARGS=()
CUR_DIR="\$(pwd)"
REAL_DIR="\$(pwd -P)"
if [[ "\$CUR_DIR" != "\$REAL_DIR" ]]; then
    EXTRA_ARGS+=(--add-dir "\$REAL_DIR")
fi

exec "\$REAL_CLAUDE" "\${EXTRA_ARGS[@]}" "\$@"
WRAPPER
    chmod +x "$CLP_BIN/$command_name"
}

cmd_path() {
    local subcmd="${1:-show}"
    shift || true

    case "$subcmd" in
        show|"")
            _path_show
            ;;
        set)
            _path_set "$@"
            ;;
        clear)
            _path_clear "$@"
            ;;
        *)
            die "Unknown path subcommand: $subcmd. Use: clp path [show|set|clear]"
            ;;
    esac
}

_path_show() {
    echo -e "${BOLD}Effective paths:${NC}"
    echo ""

    local override_code="" override_mcp=""
    if [[ -f "$PATHS_FILE" ]]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            value="${value#"${value%%[![:space:]]*}"}"
            case "$key" in
                CODE) override_code="$value" ;;
                MCP)  override_mcp="$value" ;;
            esac
        done < "$PATHS_FILE"
    fi

    if [[ -n "$override_code" ]]; then
        echo -e "  CODE  ${BOLD}$override_code${NC}  ${YELLOW}(override)${NC}"
    else
        echo -e "  CODE  $DEFAULT_CODE_DIR  (default)"
    fi

    if [[ -n "$override_mcp" ]]; then
        echo -e "  MCP   ${BOLD}$override_mcp${NC}  ${YELLOW}(override)${NC}"
    else
        echo -e "  MCP   $DEFAULT_CODE_JSON  (default)"
    fi

    echo ""

    # Detection status
    echo -e "${BOLD}Detection status:${NC}"
    echo ""
    if has_claude_code_cli; then
        echo -e "  ${GREEN}✓${NC}  Claude Code CLI installed"
    else
        echo -e "  ${RED}✗${NC}  Claude Code CLI not found"
    fi
    if has_claude_code_config; then
        echo -e "  ${GREEN}✓${NC}  Claude Code config exists"
    else
        echo -e "  ${RED}✗${NC}  Claude Code config not found"
    fi
    echo ""
}

_path_set() {
    if [[ $# -eq 0 ]]; then
        die "Usage: clp path set CODE=<path> [MCP=<path>]"
    fi

    mkdir -p "$CLP_HOME"

    local ov_CODE="" ov_MCP=""
    if [[ -f "$PATHS_FILE" ]]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            value="${value#"${value%%[![:space:]]*}"}"
            case "$key" in
                CODE) ov_CODE="$value" ;;
                MCP)  ov_MCP="$value" ;;
            esac
        done < "$PATHS_FILE"
    fi

    for arg in "$@"; do
        if [[ "$arg" =~ ^(CODE|MCP)=(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            case "$key" in
                CODE) ov_CODE="$value" ;;
                MCP)  ov_MCP="$value" ;;
            esac
            ok "Set $key=$value"
        else
            die "Invalid format: '$arg'. Use KEY=value where KEY is CODE or MCP."
        fi
    done

    > "$PATHS_FILE"
    [[ -n "$ov_CODE" ]] && echo "CODE=$ov_CODE" >> "$PATHS_FILE"
    [[ -n "$ov_MCP" ]]  && echo "MCP=$ov_MCP" >> "$PATHS_FILE"

    load_path_overrides
}

_path_clear() {
    if [[ ! -f "$PATHS_FILE" ]]; then
        info "No path overrides to clear."
        return 0
    fi

    if [[ $# -eq 0 ]]; then
        rm "$PATHS_FILE"
        ok "All path overrides cleared."
        load_path_overrides
        return 0
    fi

    local ov_CODE="" ov_MCP=""
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        value="${value#"${value%%[![:space:]]*}"}"
        case "$key" in
            CODE) ov_CODE="$value" ;;
            MCP)  ov_MCP="$value" ;;
        esac
    done < "$PATHS_FILE"

    for key in "$@"; do
        case "$key" in
            CODE) ov_CODE=""; ok "Cleared CODE override." ;;
            MCP)  ov_MCP=""; ok "Cleared MCP override." ;;
            *)    warn "Unknown key '$key'. Valid keys: CODE, MCP." ;;
        esac
    done

    > "$PATHS_FILE"
    [[ -n "$ov_CODE" ]] && echo "CODE=$ov_CODE" >> "$PATHS_FILE"
    [[ -n "$ov_MCP" ]]  && echo "MCP=$ov_MCP" >> "$PATHS_FILE"

    if [[ ! -s "$PATHS_FILE" ]]; then
        rm "$PATHS_FILE"
    fi

    load_path_overrides
}

# ─── Find Real Claude Binary ──────────────────────────────────────────────────
# Finds the actual claude binary, skipping our wrapper

_find_real_claude() {
    # Check the native install location directly
    if [[ -L "$HOME/.local/bin/claude" ]]; then
        # It's the native install symlink pointing to a version
        local target
        target="$(readlink "$HOME/.local/bin/claude")"
        if [[ -x "$target" ]]; then
            echo "$target"
            return 0
        fi
    elif [[ -x "$HOME/.local/bin/claude" && ! -f "$CLP_BIN/claude" ]] || \
         [[ -x "$HOME/.local/bin/claude" && "$HOME/.local/bin/claude" -nt "$CLP_BIN/claude" ]]; then
        echo "$HOME/.local/bin/claude"
        return 0
    fi

    # Find the latest version in the versions directory
    local versions_dir="$HOME/.local/share/claude/versions"
    if [[ -d "$versions_dir" ]]; then
        local latest
        latest="$(ls -t "$versions_dir" 2>/dev/null | head -1)"
        if [[ -n "$latest" && -x "$versions_dir/$latest" ]]; then
            echo "$versions_dir/$latest"
            return 0
        fi
    fi

    # Fallback: search PATH excluding our wrapper dir
    local original_path
    original_path="${PATH//$CLP_BIN:/}"
    original_path="${original_path//:$CLP_BIN/}"
    local found
    found="$(PATH="$original_path" command -v claude 2>/dev/null)"
    if [[ -n "$found" ]]; then
        echo "$found"
        return 0
    fi

    return 1
}

# ─── Install Command ──────────────────────────────────────────────────────────

cmd_install() {
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

    # 1. Install clp itself to ~/.local/bin
    local clp_install_dir="$HOME/.local/bin"
    local clp_install_path="$clp_install_dir/clp"
    mkdir -p "$clp_install_dir"
    if [[ "$script_path" != "$clp_install_path" ]]; then
        cp "$script_path" "$clp_install_path"
        chmod +x "$clp_install_path"
        ok "Installed clp to $clp_install_path"
    else
        ok "clp already at $clp_install_path"
    fi

    # 2. Create the claude wrapper at ~/.clp/bin/claude
    mkdir -p "$CLP_BIN"
    _create_claude_wrapper
    ok "Created claude wrapper at $CLP_BIN/claude"

    # 3. Ensure ~/.clp/bin is in PATH BEFORE ~/.local/bin
    local rc_file=""
    if [[ -f "$HOME/.zshrc" ]]; then
        rc_file="$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        rc_file="$HOME/.bashrc"
    fi

    local path_line='export PATH="$HOME/.clp/bin:$PATH"'
    local needs_path=false

    if [[ ":$PATH:" != *":$CLP_BIN:"* ]]; then
        needs_path=true
    fi

    if [[ "$needs_path" == true && -n "$rc_file" ]]; then
        # Check if already added
        if ! grep -qF '.clp/bin' "$rc_file" 2>/dev/null; then
            echo '' >> "$rc_file"
            echo '# Added by clp install — claude wrapper for profile switching' >> "$rc_file"
            echo "$path_line" >> "$rc_file"
            ok "Added ~/.clp/bin to PATH in $rc_file"
        else
            info "~/.clp/bin PATH entry already in $rc_file"
        fi
        warn "Restart your shell or run: source $rc_file"
    elif [[ "$needs_path" == true ]]; then
        warn "~/.clp/bin is not in your PATH."
        warn "Add this to your shell config: $path_line"
    else
        info "~/.clp/bin is already in your PATH."
    fi

    # Also ensure ~/.local/bin is in PATH (for clp itself)
    if [[ ":$PATH:" != *":$clp_install_dir:"* && -n "$rc_file" ]]; then
        if ! grep -qF '.local/bin' "$rc_file" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc_file"
            ok "Added ~/.local/bin to PATH in $rc_file"
        fi
    fi

    # 4. Create Desktop wrapper app (macOS only)
    if has_claude_desktop; then
        _ensure_main_desktop_app
    fi

    echo ""
    info "Setup complete. After restarting your shell:"
    info "  • 'claude' command will use the active clp profile"
    if has_claude_desktop; then
        info "  • 'Claude CLP.app' in ~/Applications/ launches Desktop with active profile"
    fi
}

_create_claude_wrapper() {
    cat > "$CLP_BIN/claude" <<'WRAPPER'
#!/usr/bin/env bash
# clp claude wrapper — sets CLAUDE_CONFIG_DIR based on the active clp profile
# before calling the real claude binary.

CLP_HOME="${CLP_HOME:-$HOME/.clp}"
META_FILE="$CLP_HOME/.active"

# Read active profile
ACTIVE=""
if [[ -f "$META_FILE" ]]; then
    ACTIVE="$(cat "$META_FILE")"
fi

if [[ -n "$ACTIVE" ]]; then
    PROFILE_DIR="$CLP_HOME/profiles/$ACTIVE/claude-code"
    if [[ -d "$PROFILE_DIR" ]]; then
        export CLAUDE_CONFIG_DIR="$PROFILE_DIR"
    fi
    if [[ -t 1 ]]; then
        echo ""
        echo -e "  \033[1;36m▶ CLP\033[0m  \033[1;33m$ACTIVE\033[0m"
        echo ""
    fi
fi

# Find the real claude binary (skip this wrapper)
REAL_CLAUDE=""
# Check native install symlink
if [[ -L "$HOME/.local/bin/claude" ]]; then
    REAL_CLAUDE="$(readlink "$HOME/.local/bin/claude")"
fi
# Check versions dir
if [[ -z "$REAL_CLAUDE" || ! -x "$REAL_CLAUDE" ]]; then
    VERSIONS_DIR="$HOME/.local/share/claude/versions"
    if [[ -d "$VERSIONS_DIR" ]]; then
        REAL_CLAUDE="$(ls -t "$VERSIONS_DIR" 2>/dev/null | head -1)"
        if [[ -n "$REAL_CLAUDE" ]]; then
            REAL_CLAUDE="$VERSIONS_DIR/$REAL_CLAUDE"
        fi
    fi
fi
# Fallback: search PATH excluding this wrapper's dir
if [[ -z "$REAL_CLAUDE" || ! -x "$REAL_CLAUDE" ]]; then
    SEARCH_PATH="${PATH//$CLP_HOME\/bin:/}"
    SEARCH_PATH="${SEARCH_PATH//:$CLP_HOME\/bin/}"
    REAL_CLAUDE="$(PATH="$SEARCH_PATH" command -v claude 2>/dev/null)" || true
fi

if [[ -z "$REAL_CLAUDE" || ! -x "$REAL_CLAUDE" ]]; then
    echo "clp: cannot find real claude binary. Is Claude Code installed?" >&2
    exit 1
fi

# Detect if current directory (or any component) is a symlink
# If so, add the real path so Claude sees both workspaces
EXTRA_ARGS=()
CUR_DIR="$(pwd)"
REAL_DIR="$(pwd -P)"
if [[ "$CUR_DIR" != "$REAL_DIR" ]]; then
    EXTRA_ARGS+=(--add-dir "$REAL_DIR")
fi

exec "$REAL_CLAUDE" "${EXTRA_ARGS[@]}" "$@"
WRAPPER
    chmod +x "$CLP_BIN/claude"
}

cmd_version() {
    echo "clp $CLP_VERSION"
}

cmd_help() {
    cat <<EOF
${BOLD}clp${NC} — Claude Profile: Switch between Claude Code profiles

${BOLD}USAGE:${NC}
  clp capture <name>            Capture current config as a named profile
  clp use <name>                Switch to a profile
  clp use <name> <command>      Create named command to run a profile without switching
                                (use this to run multiple profiles side by side)
  clp list                      List available profiles and named commands
  clp current                   Show active profile
  clp remove <name>             Remove a profile (cannot remove active)
  clp remove -c <command>       Remove a named command wrapper
  clp uninstall [name]          Restore real folders from profile, remove symlinks
  clp path                      Show current effective paths & detection status
  clp path set KEY=<path>       Override a path (KEY: CODE, MCP)
  clp path clear [KEY...]       Clear path overrides (all, or specific keys)
  clp install                   Install clp + claude wrapper to ~/.clp/bin
  clp version                   Show version
  clp help                      Show this help

${BOLD}HOW IT WORKS:${NC}
  Profiles are stored in ~/.clp/profiles/<name>/
  Each profile contains full copies of:
    • Claude Code config dir     (default: ~/.claude/)
    • MCP server config file     (default: ~/.claude.json)

  The real directories are replaced with symlinks pointing to the active
  profile. Switching profiles swaps these symlinks after saving the current
  state back.

  Claude Desktop App and other Claude Code CLI sessions are killed before switching.

${BOLD}PATH OVERRIDES:${NC}
  clp path set CODE=/custom/path    Override Claude Code config dir
  clp path set MCP=/custom/path     Override MCP config file path
  clp path clear                    Clear all overrides (revert to OS defaults)

${BOLD}FIRST-TIME SETUP:${NC}
  1. Run: clp install              (installs clp + claude wrapper)
  2. Configure Claude Code as User A
  3. Run: clp capture userA
  4. Configure Claude Code as User B
  5. Run: clp capture userB
  6. Switch freely: clp use userA / clp use userB

${BOLD}WRAPPER:${NC}
  After 'clp install', the 'claude' command routes through ~/.clp/bin/claude
  which sets CLAUDE_CONFIG_DIR based on the active profile, then calls the
  real binary.

  Named commands (created via 'clp use <name> <command>') let you run
  multiple profiles simultaneously — each command always uses its assigned
  profile, independent of the active one. For example:
    clp use work wk        # 'wk' always runs the 'work' profile
    clp use personal ps    # 'ps' always runs the 'personal' profile
  Now you can run 'wk' and 'ps' in separate terminals at the same time.

${BOLD}CLAUDE DESKTOP (macOS):${NC}
  If Claude Desktop is installed, clp also manages desktop profiles:
    • Each profile stores its own Desktop data in claude-desktop/
    • 'Claude CLP.app' in ~/Applications/ launches with the active profile
    • Named commands also get Desktop apps (e.g. 'Claude wk.app')
    • Desktop is not auto-killed/launched — use wrapper apps to switch
    • First-time desktop setup for a profile requires re-login

${BOLD}ENVIRONMENT:${NC}
  CLP_HOME              Override clp home directory (default: ~/.clp)

EOF
}

# ─── Main ──────────────────────────────────────────────────────────────────────

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        capture)            cmd_capture "$@" ;;
        use)                cmd_use "$@" ;;
        list)               cmd_list ;;
        current)            cmd_current ;;
        remove)             cmd_remove "$@" ;;
        uninstall)          cmd_uninstall "$@" ;;
        path)               cmd_path "$@" ;;
        install)            cmd_install ;;
        version|--version)  cmd_version ;;
        help|-h|--help)     cmd_help ;;
        *)                  die "Unknown command: $cmd. Run 'clp help' for usage." ;;
    esac
}

main "$@"