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
declare -gA APP_PRIMARY_ACTION=()   # Per-app primary action override
declare -gA APP_SECONDARY_ACTION=() # Per-app secondary action override
declare -gA APP_SHORTCUT=()         # Per-app keyboard shortcut
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
  local _primary_action="${section_data[primary_action]:-}"
  local _secondary_action="${section_data[secondary_action]:-}"
  local _shortcut="${section_data[shortcut]:-}"

  # Store in arrays (staying in set +u context for array key safety)
  APP_CMD["$name"]="$_cmd"
  APP_DESC["$name"]="$_desc"
  APP_WIDTH["$name"]="$_width"
  APP_HEIGHT["$name"]="$_height"
  APP_ON_EXIT["$name"]="$_on_exit"
  APP_PRIMARY_ACTION["$name"]="$_primary_action"
  APP_SECONDARY_ACTION["$name"]="$_secondary_action"
  APP_SHORTCUT["$name"]="$_shortcut"

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
    local shortcut="${APP_SHORTCUT[$name]:-}"

    # Format: visible_part \t shortcut \t name \t cmd \t width \t height \t on_exit
    printf "%s %-12s  %s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$icon" "$display_name" "$desc" "$shortcut" "$name" "$cmd" "$width" "$height" "$on_exit"
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

  # Determine action based on key pressed
  local action
  if [[ "$key" == "$SECONDARY_KEY" ]]; then
    action="${APP_SECONDARY_ACTION[$name]:-$SECONDARY_ACTION}"
  else
    action="${APP_PRIMARY_ACTION[$name]:-$PRIMARY_ACTION}"
  fi

  # If app already running and action is not background, switch to it
  if is_app_running "$name" && [[ "$action" != "background_window" ]]; then
    switch_to_app "$name"
    return 0
  fi

  # Format display name for popup (e.g., "system/btop" -> "system | btop")
  local display_name="$name"
  if [[ "$name" == */* ]]; then
    display_name="${name%%/*} | ${name#*/}"
  fi

  # Launch via centralized launcher - it handles action-specific behavior
  nunchux_launch --type app --action "$action" --name "$display_name" --cmd "$cmd" \
    --width "$width" --height "$height" --on-exit "$on_exit"

  return 0
}

# Switch to an existing app window
switch_to_app() {
  local name="$1"
  tmux select-window -t "$name" 2>/dev/null
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
