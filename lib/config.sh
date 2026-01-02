#!/usr/bin/env bash
#
# lib/config.sh - Configuration parsing for nunchux
#

# Guard against double-sourcing
[[ -n "${NUNCHUX_LIB_CONFIG_LOADED:-}" ]] && return
NUNCHUX_LIB_CONFIG_LOADED=1

# Config file locations (can be overridden via environment)
NUNCHUX_CONFIG_DIR="${NUNCHUX_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/nunchux}"
# Track if NUNCHUX_RC_FILE was explicitly set (before applying default)
NUNCHUX_RC_FILE_EXPLICIT="${NUNCHUX_RC_FILE:+1}"
NUNCHUX_RC_FILE="${NUNCHUX_RC_FILE:-$NUNCHUX_CONFIG_DIR/config}"

# Global settings defaults
ICON_RUNNING="${ICON_RUNNING:-●}"
ICON_STOPPED="${ICON_STOPPED:-○}"
MENU_WIDTH="${MENU_WIDTH:-60%}"
MENU_HEIGHT="${MENU_HEIGHT:-50%}"
MAX_MENU_WIDTH="${MAX_MENU_WIDTH:-}"   # empty = no limit (columns)
MAX_MENU_HEIGHT="${MAX_MENU_HEIGHT:-}" # empty = no limit (rows)
APP_POPUP_WIDTH="${APP_POPUP_WIDTH:-90%}"
APP_POPUP_HEIGHT="${APP_POPUP_HEIGHT:-90%}"
MAX_POPUP_WIDTH="${MAX_POPUP_WIDTH:-}"   # empty = no limit (columns)
MAX_POPUP_HEIGHT="${MAX_POPUP_HEIGHT:-}" # empty = no limit (rows)
MENU_CACHE_TTL="${MENU_CACHE_TTL:-60}"
SHOW_HELP="${SHOW_HELP:-false}"          # show help header and shortcuts (toggle with ctrl-/)
SHOW_CWD="${SHOW_CWD:-true}"             # show current working directory in menu label

# Keybindings
PRIMARY_KEY="${PRIMARY_KEY:-enter}"
SECONDARY_KEY="${SECONDARY_KEY:-ctrl-o}"

# Actions (popup, window, background_window, pane_horizontal, pane_vertical)
# Note: These are global defaults; modules may have different defaults
PRIMARY_ACTION="${PRIMARY_ACTION:-popup}"
SECONDARY_ACTION="${SECONDARY_ACTION:-window}"

# Direct action shortcuts (bypass primary/secondary)
# Empty by default - users opt in by setting these
POPUP_KEY="${POPUP_KEY:-}"
WINDOW_KEY="${WINDOW_KEY:-}"
BACKGROUND_WINDOW_KEY="${BACKGROUND_WINDOW_KEY:-}"
PANE_HORIZONTAL_KEY="${PANE_HORIZONTAL_KEY:-}"
PANE_VERTICAL_KEY="${PANE_VERTICAL_KEY:-}"

# Action menu key (shows menu to select action)
# Note: ctrl-m is the same as Enter in terminals, so we use ctrl-j by default
ACTION_MENU_KEY="${ACTION_MENU_KEY:-ctrl-j}"

# Taskrunner icons
TASKRUNNER_ICON_RUNNING="${TASKRUNNER_ICON_RUNNING:-🔄}"
TASKRUNNER_ICON_SUCCESS="${TASKRUNNER_ICON_SUCCESS:-✅}"
TASKRUNNER_ICON_FAILED="${TASKRUNNER_ICON_FAILED:-❌}"

# Supported fzf keys (shift-enter and ctrl-enter are NOT supported by terminals)
FZF_SUPPORTED_KEYS=(
  # Basic keys
  enter space tab esc backspace delete insert
  up down left right home end
  page-up page-down pgup pgdn
  # Function keys
  f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12
  # Ctrl combinations
  ctrl-a ctrl-b ctrl-c ctrl-d ctrl-e ctrl-f ctrl-g ctrl-h ctrl-i ctrl-j
  ctrl-k ctrl-l ctrl-m ctrl-n ctrl-o ctrl-p ctrl-q ctrl-r ctrl-s ctrl-t
  ctrl-u ctrl-v ctrl-w ctrl-x ctrl-y ctrl-z
  ctrl-space ctrl-delete ctrl-backspace
  # Alt combinations
  alt-a alt-b alt-c alt-d alt-e alt-f alt-g alt-h alt-i alt-j
  alt-k alt-l alt-m alt-n alt-o alt-p alt-q alt-r alt-s alt-t
  alt-u alt-v alt-w alt-x alt-y alt-z
  alt-enter alt-space alt-backspace alt-delete
  alt-up alt-down alt-left alt-right alt-home alt-end
  alt-page-up alt-page-down
  # Shift combinations (limited - NO shift-enter!)
  shift-tab shift-up shift-down shift-left shift-right
  shift-home shift-end shift-delete shift-page-up shift-page-down
  # Double-click
  double-click
)

# Check if a key is supported by fzf
is_valid_fzf_key() {
  local key="$1"
  local k
  for k in "${FZF_SUPPORTED_KEYS[@]}"; do
    [[ "$key" == "$k" ]] && return 0
  done
  return 1
}

# Reserved keys that cannot be used as shortcuts
FZF_RESERVED_KEYS=(enter esc ctrl-x)

# Global shortcut registry for duplicate detection
declare -gA SHORTCUT_REGISTRY=()  # key -> item_name

# Validate a shortcut key
# Returns 0 if valid, 1 if invalid (with warning to stderr)
validate_shortcut() {
  local key="$1"
  local item="$2"

  # Empty is allowed (no shortcut)
  [[ -z "$key" ]] && return 0

  # Check if it's a valid fzf key
  if ! is_valid_fzf_key "$key"; then
    echo "Warning: invalid shortcut key '$key' for $item" >&2
    return 1
  fi

  # Check reserved keys:
  # - FZF_RESERVED_KEYS: static keys used by fzf/nunchux
  # - PRIMARY_KEY: configured key for primary action (default: enter)
  # - SECONDARY_KEY: configured key for secondary action (default: ctrl-o)
  # - Action keys: direct shortcuts for specific actions
  # - ACTION_MENU_KEY: shows action selection menu
  # - "/": used for jump mode
  for reserved in "${FZF_RESERVED_KEYS[@]}" "$PRIMARY_KEY" "$SECONDARY_KEY" \
      "$POPUP_KEY" "$WINDOW_KEY" "$BACKGROUND_WINDOW_KEY" \
      "$PANE_HORIZONTAL_KEY" "$PANE_VERTICAL_KEY" "$ACTION_MENU_KEY" "/"; do
    if [[ "$key" == "$reserved" ]]; then
      echo "Warning: shortcut key '$key' is reserved" >&2
      return 1
    fi
  done

  return 0
}

# Register a shortcut, checking for duplicates
# Returns 0 if registered, 1 if duplicate (with warning to stderr)
register_shortcut() {
  local key="$1"
  local item="$2"

  [[ -z "$key" ]] && return 0

  if [[ -n "${SHORTCUT_REGISTRY[$key]:-}" ]]; then
    echo "Warning: duplicate shortcut '$key' - already used by ${SHORTCUT_REGISTRY[$key]}" >&2
    return 1
  fi

  SHORTCUT_REGISTRY["$key"]="$item"
  return 0
}

# Validate keybindings and return error message if invalid
validate_keybindings() {
  local invalid_keys=()

  if ! is_valid_fzf_key "$PRIMARY_KEY"; then
    invalid_keys+=("primary_key: $PRIMARY_KEY")
  fi

  if ! is_valid_fzf_key "$SECONDARY_KEY"; then
    invalid_keys+=("secondary_key: $SECONDARY_KEY")
  fi

  # Validate action keys (only if non-empty)
  [[ -n "$POPUP_KEY" ]] && ! is_valid_fzf_key "$POPUP_KEY" && \
    invalid_keys+=("popup_key: $POPUP_KEY")
  [[ -n "$WINDOW_KEY" ]] && ! is_valid_fzf_key "$WINDOW_KEY" && \
    invalid_keys+=("window_key: $WINDOW_KEY")
  [[ -n "$BACKGROUND_WINDOW_KEY" ]] && ! is_valid_fzf_key "$BACKGROUND_WINDOW_KEY" && \
    invalid_keys+=("background_window_key: $BACKGROUND_WINDOW_KEY")
  [[ -n "$PANE_HORIZONTAL_KEY" ]] && ! is_valid_fzf_key "$PANE_HORIZONTAL_KEY" && \
    invalid_keys+=("pane_horizontal_key: $PANE_HORIZONTAL_KEY")
  [[ -n "$PANE_VERTICAL_KEY" ]] && ! is_valid_fzf_key "$PANE_VERTICAL_KEY" && \
    invalid_keys+=("pane_vertical_key: $PANE_VERTICAL_KEY")
  [[ -n "$ACTION_MENU_KEY" ]] && ! is_valid_fzf_key "$ACTION_MENU_KEY" && \
    invalid_keys+=("action_menu_key: $ACTION_MENU_KEY")

  if [[ ${#invalid_keys[@]} -gt 0 ]]; then
    echo "${invalid_keys[*]}"
    return 1
  fi
  return 0
}

# Directory browser exclusion patterns
EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS:-.git, node_modules, Cache, cache, .cache, GPUCache, CachedData, blob_storage, Code Cache, Session Storage, Local Storage, IndexedDB, databases, *.db, *.db-*, *.sqlite*, *.log, *.png, *.jpg, *.jpeg, *.gif, *.ico, *.webp, *.woff*, *.ttf, *.lock, lock, *.pid}"

# Module dispatch table: type -> handler function
declare -gA CONFIG_TYPE_HANDLERS

# Order section storage
declare -ga MAIN_ORDER=()              # Items from [order] section (including taskrunner:name)
declare -gA SUBMENU_ORDER=()           # Associative: submenu_name -> "item1 item2 item3"

# Register a config type handler
# Usage: register_config_type "app" "app_parse_section"
register_config_type() {
  local type="$1"
  local handler="$2"
  CONFIG_TYPE_HANDLERS["$type"]="$handler"
}

# Parse INI config file
# Supports [settings] for global config and [type:name] for typed sections
parse_config() {
  local config_file="$1"
  local current_section=""
  local current_type=""
  local current_name=""
  local line key value
  local continued_value="" continued_key=""

  # Temporary storage for section data
  declare -A section_data

  # Flush current section to appropriate handler
  flush_section() {
    if [[ -n "$current_type" && -n "$current_name" ]]; then
      local handler="${CONFIG_TYPE_HANDLERS[$current_type]:-}"
      if [[ -n "$handler" && $(type -t "$handler") == "function" ]]; then
        # Pass section data to handler
        "$handler" "$current_name" "$(declare -p section_data)"
      fi
    fi
    section_data=()
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Handle line continuation
    if [[ -n "$continued_key" ]]; then
      line="${line#"${line%%[![:space:]]*}"}"
      if [[ "$line" == *\\ ]]; then
        continued_value+="${line%\\}"
        continue
      else
        continued_value+="$line"
        line="$continued_key = $continued_value"
        continued_key=""
        continued_value=""
      fi
    fi

    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    # Section header: [type:name] or [settings] or [order] or [order:*]
    if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
      flush_section
      current_section="${BASH_REMATCH[1]}"

      if [[ "$current_section" == "settings" ]]; then
        current_type=""
        current_name=""
      elif [[ "$current_section" == "order" ]]; then
        # [order] section - main menu order
        current_type="order"
        current_name=""
      elif [[ "$current_section" =~ ^order:(.+)$ ]]; then
        # [order:submenu] or [order:taskrunner] section
        current_type="order"
        current_name="${BASH_REMATCH[1]}"
      elif [[ "$current_section" =~ ^([^:]+):(.+)$ ]]; then
        # [type:name] format
        current_type="${BASH_REMATCH[1]}"
        current_name="${BASH_REMATCH[2]}"
      else
        # Unknown section format - treat as old-style (for migration)
        current_type=""
        current_name=""
      fi
      continue
    fi

    # Key = value (split on first =)
    if [[ "$line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      # Trim whitespace
      key="${key%"${key##*[![:space:]]}"}"
      key="${key#"${key%%[![:space:]]*}"}"
      value="${value#"${value%%[![:space:]]*}"}"

      # Line continuation
      if [[ "$value" == *\\ ]]; then
        continued_key="$key"
        continued_value="${value%\\}"
        continue
      fi

      if [[ "$current_section" == "settings" ]]; then
        # Handle global settings
        case "$key" in
        icon_running) ICON_RUNNING="$value" ;;
        icon_stopped) ICON_STOPPED="$value" ;;
        menu_width) MENU_WIDTH="$value" ;;
        menu_height) MENU_HEIGHT="$value" ;;
        max_menu_width) MAX_MENU_WIDTH="$value" ;;
        max_menu_height) MAX_MENU_HEIGHT="$value" ;;
        popup_width) APP_POPUP_WIDTH="$value" ;;
        popup_height) APP_POPUP_HEIGHT="$value" ;;
        max_popup_width) MAX_POPUP_WIDTH="$value" ;;
        max_popup_height) MAX_POPUP_HEIGHT="$value" ;;
        fzf_prompt) FZF_PROMPT="$value" ;;
        fzf_pointer) FZF_POINTER="$value" ;;
        fzf_border) FZF_BORDER="$value" ;;
        label) NUNCHUX_LABEL="$value" ;;
        fzf_colors) FZF_COLORS="$value" ;;
        cache_ttl) MENU_CACHE_TTL="$value" ;;
        exclude_patterns) EXCLUDE_PATTERNS="$value" ;;
        primary_key) PRIMARY_KEY="$value" ;;
        secondary_key) SECONDARY_KEY="$value" ;;
        primary_action) PRIMARY_ACTION="$value" ;;
        secondary_action) SECONDARY_ACTION="$value" ;;
        show_help) SHOW_HELP="$value" ;;
        show_cwd) SHOW_CWD="$value" ;;
        popup_key) POPUP_KEY="$value" ;;
        window_key) WINDOW_KEY="$value" ;;
        background_window_key) BACKGROUND_WINDOW_KEY="$value" ;;
        pane_horizontal_key) PANE_HORIZONTAL_KEY="$value" ;;
        pane_vertical_key) PANE_VERTICAL_KEY="$value" ;;
        action_menu_key) ACTION_MENU_KEY="$value" ;;
        esac
      elif [[ "$current_section" == "taskrunner" ]]; then
        # Handle taskrunner defaults
        case "$key" in
        icon_running) TASKRUNNER_ICON_RUNNING="$value" ;;
        icon_success) TASKRUNNER_ICON_SUCCESS="$value" ;;
        icon_failed) TASKRUNNER_ICON_FAILED="$value" ;;
        esac
      else
        # Store in section_data for module handler
        section_data["$key"]="$value"
      fi
    elif [[ "$current_type" == "order" ]]; then
      # Order section: lines are item names, not key=value
      # Trim whitespace from line
      local item="${line#"${line%%[![:space:]]*}"}"
      item="${item%"${item##*[![:space:]]}"}"
      [[ -z "$item" ]] && continue

      if [[ -z "$current_name" ]]; then
        # [order] - main menu order (apps, dirbrowsers, submenus, taskrunner:name)
        MAIN_ORDER+=("$item")
      else
        # [order:submenu_name] - submenu item order
        if [[ -v SUBMENU_ORDER[$current_name] ]]; then
          SUBMENU_ORDER[$current_name]+=" $item"
        else
          SUBMENU_ORDER[$current_name]="$item"
        fi
      fi
    fi
  done <"$config_file"

  flush_section
}

# Search upward from current directory for .nunchuxrc (including ~/.nunchuxrc)
# Similar to how .gitignore, .nvmrc, .editorconfig work
find_nunchuxrc() {
  local dir="$PWD"

  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.nunchuxrc" ]]; then
      echo "$dir/.nunchuxrc"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  return 1
}

# Get config file path (returns first existing)
# Priority: .nunchuxrc (upward search) > ~/.config/nunchux/config
# Note: If NUNCHUX_RC_FILE is explicitly set via env, search is skipped
get_config_file() {
  # If explicitly set via env, use that
  if [[ -n "$NUNCHUX_RC_FILE_EXPLICIT" ]]; then
    [[ -f "$NUNCHUX_RC_FILE" ]] && echo "$NUNCHUX_RC_FILE"
    return
  fi

  # Search upward for .nunchuxrc (including ~/.nunchuxrc)
  local rc_file
  if rc_file=$(find_nunchuxrc); then
    echo "$rc_file"
    return
  fi

  # Fall back to XDG config
  if [[ -f "$NUNCHUX_RC_FILE" ]]; then
    echo "$NUNCHUX_RC_FILE"
  fi
}

# Check if config exists
has_config_file() {
  find_nunchuxrc &>/dev/null || [[ -f "$NUNCHUX_RC_FILE" ]]
}

# vim: ft=bash ts=2 sw=2 et
