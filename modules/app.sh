#!/usr/bin/env bash
#
# modules/app.sh - Regular app handling
#
# Config format:
#   [app:lazygit]
#   cmd = lazygit
#   desc = Git TUI
#   width = 95
#   height = 95
#   status = n=$(git status -s 2>/dev/null | wc -l); [[ $n -gt 0 ]] && echo "($n changed)"
#   on_exit = echo "done"
#

# Guard against double-sourcing
[[ -n "${NUNCHUX_MOD_APP_LOADED:-}" ]] && return
NUNCHUX_MOD_APP_LOADED=1

# App storage (declare -g for global scope when sourced from function)
declare -gA APP_CMD=()
declare -gA APP_DESC=()
declare -gA APP_WIDTH=()
declare -gA APP_HEIGHT=()
declare -gA APP_STATUS=()
declare -gA APP_ON_EXIT=()
declare -gA APP_PARENT=() # For submenu membership: app_name -> parent_menu
declare -ga APP_ORDER=()  # Preserve order

# Register with core
register_module "app"

# Parse a config section for an app
# Called by config parser when [app:name] is encountered
app_parse_section() {
  local name="$1"
  local data_decl="$2"

  # Temporarily disable set -u for associative array access
  set +u

  # Reconstruct associative array from declaration
  eval "$data_decl"

  # Store app configuration using intermediate vars to avoid / interpretation
  local _cmd="${section_data[cmd]:-}"
  local _desc="${section_data[desc]:-}"
  local _width="${section_data[width]:-}"
  local _height="${section_data[height]:-}"
  local _on_exit="${section_data[on_exit]:-}"
  local _status="${section_data[status]:-}"
  local _status_script="${section_data[status_script]:-}"

  # Store in arrays (staying in set +u context for array key safety)
  APP_CMD["$name"]="$_cmd"
  APP_DESC["$name"]="$_desc"
  APP_WIDTH["$name"]="$_width"
  APP_HEIGHT["$name"]="$_height"
  APP_ON_EXIT["$name"]="$_on_exit"

  # Handle status or status_script
  if [[ -n "$_status_script" ]]; then
    APP_STATUS["$name"]="source ${_status_script/#\~/$HOME}"
  elif [[ -n "$_status" ]]; then
    APP_STATUS["$name"]="$_status"
  fi

  # Track parent menu if name contains /
  if [[ "$name" == */* ]]; then
    local _parent="${name%%/*}"
    APP_PARENT["$name"]="$_parent"
  fi

  APP_ORDER+=("$name")

  # Track in global order with optional explicit order
  local _order="${section_data[order]:-}"
  track_config_item "app:$name" "$_order"

  set -u
}

# Check if app is running (has a tmux window with that name)
is_app_running() {
  local name="$1"
  tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx "$name"
}

# Get list of running app windows
get_running_apps() {
  tmux list-windows -F '#{window_name}' 2>/dev/null || true
}

# Build menu entries for apps
# Usage: app_build_menu [current_menu]
app_build_menu() {
  local current_menu="${1:-}"
  local running_apps
  running_apps=$(get_running_apps)

  for name in "${APP_ORDER[@]}"; do
    local cmd="${APP_CMD[$name]:-}"
    [[ -z "$cmd" ]] && continue

    local parent="${APP_PARENT[$name]:-}"
    local display_name="$name"

    # Handle menu filtering
    if [[ -z "$current_menu" ]]; then
      # Main menu: skip items that belong to a submenu
      [[ -n "$parent" ]] && continue
    else
      # Submenu mode: only show items in this menu
      [[ "$parent" != "$current_menu" ]] && continue
      # Display name is the part after the /
      display_name="${name#*/}"
    fi

    local icon desc
    if echo "$running_apps" | grep -qx "$name"; then
      icon="$ICON_RUNNING"
    else
      icon="$ICON_STOPPED"
    fi

    desc="${APP_DESC[$name]:-}"

    # Run status command if defined
    if [[ -n "${APP_STATUS[$name]:-}" ]]; then
      local status_output
      status_output=$(eval "${APP_STATUS[$name]}" 2>/dev/null || true)
      if [[ -n "$status_output" ]]; then
        if [[ -n "$desc" ]]; then
          desc="$desc $status_output"
        else
          desc="$status_output"
        fi
      fi
    fi

    local width="${APP_WIDTH[$name]:-}"
    local height="${APP_HEIGHT[$name]:-}"
    local on_exit="${APP_ON_EXIT[$name]:-}"

    # Format: visible_part \t name \t cmd \t width \t height \t on_exit
    printf "%s  %-12s  %s\t%s\t%s\t%s\t%s\t%s\n" \
      "$icon" "$display_name" "$desc" "$name" "$cmd" "$width" "$height" "$on_exit"
  done
}

# Launch an app
# Returns 0 if handled, 1 if not our item
app_launch() {
  local name="$1"
  local key="$2"
  local cmd="$3"
  local width="$4"
  local height="$5"
  local on_exit="$6"

  # Check if this is one of our apps
  [[ -z "${APP_CMD[$name]:-}" ]] && return 1

  if [[ "$key" == "$SECONDARY_KEY" ]]; then
    # Open in window
    if is_app_running "$name"; then
      switch_to_app "$name"
    else
      open_app "$name" "$cmd"
    fi
  elif is_app_running "$name"; then
    switch_to_app "$name"
  else
    open_popup "$name" "$cmd" "$width" "$height" "$on_exit"
  fi

  return 0
}

# Switch to an existing app window
switch_to_app() {
  local name="$1"
  tmux select-window -t "$name" 2>/dev/null
}

# Open a new app in a new tmux window
open_app() {
  local name="$1"
  local cmd="$2"
  local dir
  dir=$(get_current_dir)

  # Use nunchux-run to apply parent shell environment
  tmux new-window -n "$name" -c "$dir" "$NUNCHUX_BIN_DIR/nunchux-run" bash -c "$cmd"
}

# Open app in a popup with app-specific dimensions
open_popup() {
  local name="$1"
  local cmd="$2"
  local app_width="$3"
  local app_height="$4"
  local on_exit="$5"
  local dir
  dir=$(get_current_dir)

  # Use app-specific dimensions, fall back to defaults
  local width height
  width="${app_width:-$APP_POPUP_WIDTH}"
  height="${app_height:-$APP_POPUP_HEIGHT}"
  # Add % suffix if just a number
  [[ "$width" =~ ^[0-9]+$ ]] && width="${width}%"
  [[ "$height" =~ ^[0-9]+$ ]] && height="${height}%"

  # Set up variables for substitution
  local pane_id tmp script_file
  pane_id=$(tmux display-message -p '#{pane_id}')
  tmp="/tmp/nunchux-tmp-$$"
  script_file="/tmp/nunchux-script-$$"

  # Substitute variables in cmd and on_exit
  local expanded_cmd="$cmd"
  local expanded_on_exit="${on_exit:-}"
  expanded_cmd="${expanded_cmd//\{pane_id\}/$pane_id}"
  expanded_cmd="${expanded_cmd//\{tmp\}/$tmp}"
  expanded_cmd="${expanded_cmd//\{dir\}/$dir}"
  expanded_on_exit="${expanded_on_exit//\{pane_id\}/$pane_id}"
  expanded_on_exit="${expanded_on_exit//\{tmp\}/$tmp}"
  expanded_on_exit="${expanded_on_exit//\{dir\}/$dir}"

  # Pick a random Chuck Norris fact for potential error display
  local fact="${CHUCK_FACTS[$RANDOM % ${#CHUCK_FACTS[@]}]}"

  # Write command to temp script with error handling
  cat >"$script_file" <<NUNCHUX_EOF
#!/usr/bin/env bash

# Apply parent shell environment (for nvm, pyenv, etc.)
source "$NUNCHUX_BIN_DIR/nunchux-run"

export PATH="$NUNCHUX_BIN_DIR:\$PATH"
cd "$dir"

# Run the command
$expanded_cmd
exit_code=\$?

# Run on_exit if defined
$expanded_on_exit

# If command failed, show error popup
if [[ \$exit_code -ne 0 ]]; then
    clear

    center() {
        local text="\$1"
        local width=\$(tput cols)
        local plain=\$(echo -e "\$text" | sed 's/\x1b\[[0-9;]*m//g')
        local text_len=\${#plain}
        local padding=\$(( (width - text_len) / 2 ))
        [[ \$padding -gt 0 ]] && printf "%*s" \$padding ""
        echo -e "\$text"
    }

    height=\$(tput lines)
    top_padding=\$(( (height - 18) / 2 ))
    for ((i=0; i<top_padding; i++)); do echo; done

    center "\033[1;33m$fact\033[0m"
    echo ""
    center "\033[90mbut...\033[0m"
    echo ""
    while IFS= read -r line; do
        center "\$line"
    done <<< "$NUNCHUCKS_ART"
    echo ""
    echo ""
    if [[ \$exit_code -eq 127 ]]; then
        center "\033[1;31mCommand not found: $name\033[0m"
    else
        center "\033[1;31m$name exited with code \$exit_code\033[0m"
    fi
    echo ""
    center "\033[90mpress any key\033[0m"
    read -n 1 -s
fi

rm -f "$script_file"
NUNCHUX_EOF
  chmod +x "$script_file"

  tmux run-shell -b "sleep 0.05; tmux display-popup -E -b rounded -T ' nunchux: $name ' -w $width -h $height '$script_file'"
  exit 0
}

# Kill a running app window
# Returns 0 if killed, 1 if not found
kill_app() {
  local name="$1"
  if is_app_running "$name"; then
    tmux kill-window -t "$name" 2>/dev/null
    return 0
  fi
  return 1
}

# Check if we have any apps configured
app_has_items() {
  [[ ${#APP_ORDER[@]} -gt 0 ]]
}

# vim: ft=bash ts=2 sw=2 et
