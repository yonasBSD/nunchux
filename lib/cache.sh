#!/usr/bin/env bash
#
# lib/cache.sh - Cache management for nunchux
#

# Guard against double-sourcing
[[ -n "${NUNCHUX_LIB_CACHE_LOADED:-}" ]] && return
NUNCHUX_LIB_CACHE_LOADED=1

# Requires lib/utils.sh for get_mtime
[[ -z "${NUNCHUX_LIB_UTILS_LOADED:-}" ]] && source "${BASH_SOURCE%/*}/utils.sh"

# Cache directory
NUNCHUX_CACHE_DIR="/tmp/nunchux-cache"

# Ensure cache directory exists
ensure_cache_dir() {
  [[ -d "$NUNCHUX_CACHE_DIR" ]] || mkdir -p "$NUNCHUX_CACHE_DIR"
}

# Get cache file path for a given type and name
# Usage: cache_file "main-menu" or cache_file "submenu" "system"
cache_file() {
  local type="$1"
  local name="${2:-}"
  ensure_cache_dir
  if [[ -n "$name" ]]; then
    echo "$NUNCHUX_CACHE_DIR/${type}-${name}.cache"
  else
    echo "$NUNCHUX_CACHE_DIR/${type}.cache"
  fi
}

# Get socket path for fzf hot-swap
# Usage: cache_socket "main-menu" or cache_socket "submenu" "system"
cache_socket() {
  local type="$1"
  local name="${2:-}"
  if [[ -n "$name" ]]; then
    echo "/tmp/nunchux-fzf-${type}-${name}-$$.sock"
  else
    echo "/tmp/nunchux-fzf-${type}-$$.sock"
  fi
}

# Check if cache is still valid (not expired)
# Usage: is_cache_valid "$cache_file" "$ttl"
is_cache_valid() {
  local cache_file="$1"
  local ttl="${2:-300}"

  # TTL of 0 means caching disabled
  [[ "$ttl" == "0" ]] && return 1
  [[ ! -f "$cache_file" ]] && return 1

  local cache_age=$(($(date +%s) - $(get_mtime "$cache_file")))
  [[ $cache_age -lt $ttl ]]
}

# Refresh cache and hot-swap via socket if available
# Usage: refresh_cache "$cache_file" "$socket" generator_function [args...]
# The generator function should output menu content to stdout
refresh_cache() {
  local cache_file="$1"
  local socket="$2"
  local generator="$3"
  shift 3

  # Rebuild to temp file first
  "$generator" "$@" >"${cache_file}.new" 2>/dev/null
  mv "${cache_file}.new" "$cache_file"

  # Hot-swap via socket if fzf is still running
  if [[ -S "$socket" ]]; then
    curl --silent --unix-socket "$socket" "http://localhost" \
      -d "reload(cat '$cache_file')" 2>/dev/null || true
  fi
}

# Clean up old cache files (called on startup)
cleanup_old_caches() {
  # Remove caches older than 1 day
  find "$NUNCHUX_CACHE_DIR" -type f -mtime +1 -delete 2>/dev/null || true
}

# Check if config cache is valid (exists and newer than config file)
# Uses bash -nt builtin - no subprocess!
is_config_cache_valid() {
  local config_file="$1"
  local cache_file="$2"

  [[ -f "$cache_file" && -f "$config_file" && "$cache_file" -nt "$config_file" ]]
}

# Save parsed config state to cache file
# Call this after normal config parsing
save_config_cache() {
  local cache_file="$1"

  ensure_cache_dir
  {
    # Settings
    echo "ICON_RUNNING='$ICON_RUNNING'"
    echo "ICON_STOPPED='$ICON_STOPPED'"
    echo "MENU_WIDTH='$MENU_WIDTH'"
    echo "MENU_HEIGHT='$MENU_HEIGHT'"
    echo "MAX_MENU_WIDTH='$MAX_MENU_WIDTH'"
    echo "MAX_MENU_HEIGHT='$MAX_MENU_HEIGHT'"
    echo "APP_POPUP_WIDTH='$APP_POPUP_WIDTH'"
    echo "APP_POPUP_HEIGHT='$APP_POPUP_HEIGHT'"
    echo "MAX_POPUP_WIDTH='$MAX_POPUP_WIDTH'"
    echo "MAX_POPUP_HEIGHT='$MAX_POPUP_HEIGHT'"
    echo "MENU_CACHE_TTL='$MENU_CACHE_TTL'"
    echo "SHOW_HELP='$SHOW_HELP'"
    echo "SHOW_CWD='$SHOW_CWD'"
    echo "NUNCHUX_LABEL='$NUNCHUX_LABEL'"

    # Keybindings
    echo "PRIMARY_KEY='$PRIMARY_KEY'"
    echo "SECONDARY_KEY='$SECONDARY_KEY'"
    echo "PRIMARY_ACTION='$PRIMARY_ACTION'"
    echo "SECONDARY_ACTION='$SECONDARY_ACTION'"
    echo "POPUP_KEY='$POPUP_KEY'"
    echo "WINDOW_KEY='$WINDOW_KEY'"
    echo "BACKGROUND_WINDOW_KEY='$BACKGROUND_WINDOW_KEY'"
    echo "PANE_RIGHT_KEY='$PANE_RIGHT_KEY'"
    echo "PANE_LEFT_KEY='$PANE_LEFT_KEY'"
    echo "PANE_ABOVE_KEY='$PANE_ABOVE_KEY'"
    echo "PANE_BELOW_KEY='$PANE_BELOW_KEY'"
    echo "ACTION_MENU_KEY='$ACTION_MENU_KEY'"

    # FZF settings
    echo "FZF_PROMPT='$FZF_PROMPT'"
    echo "FZF_POINTER='$FZF_POINTER'"
    echo "FZF_BORDER='$FZF_BORDER'"
    echo "FZF_COLORS='$FZF_COLORS'"

    # Taskrunner icons
    echo "TASKRUNNER_ICON_RUNNING='$TASKRUNNER_ICON_RUNNING'"
    echo "TASKRUNNER_ICON_SUCCESS='$TASKRUNNER_ICON_SUCCESS'"
    echo "TASKRUNNER_ICON_FAILED='$TASKRUNNER_ICON_FAILED'"

    # App data (use declare -p for associative arrays)
    declare -p APP_CMD 2>/dev/null || echo "declare -gA APP_CMD=()"
    declare -p APP_DESC 2>/dev/null || echo "declare -gA APP_DESC=()"
    declare -p APP_STATUS 2>/dev/null || echo "declare -gA APP_STATUS=()"
    declare -p APP_WIDTH 2>/dev/null || echo "declare -gA APP_WIDTH=()"
    declare -p APP_HEIGHT 2>/dev/null || echo "declare -gA APP_HEIGHT=()"
    declare -p APP_ON_EXIT 2>/dev/null || echo "declare -gA APP_ON_EXIT=()"
    declare -p APP_SHORTCUT 2>/dev/null || echo "declare -gA APP_SHORTCUT=()"
    declare -p APP_PRIMARY_ACTION 2>/dev/null || echo "declare -gA APP_PRIMARY_ACTION=()"
    declare -p APP_SECONDARY_ACTION 2>/dev/null || echo "declare -gA APP_SECONDARY_ACTION=()"
    declare -p APP_PARENT 2>/dev/null || echo "declare -gA APP_PARENT=()"
    declare -p APP_ORDER 2>/dev/null || echo "declare -ga APP_ORDER=()"

    # Menu data
    declare -p MAIN_ORDER 2>/dev/null || echo "declare -ga MAIN_ORDER=()"
    declare -p MENU_STATUS 2>/dev/null || echo "declare -gA MENU_STATUS=()"
    declare -p MENU_ORDER 2>/dev/null || echo "declare -ga MENU_ORDER=()"
    declare -p SUBMENU_ORDER 2>/dev/null || echo "declare -gA SUBMENU_ORDER=()"
    declare -p SUBMENU_CACHE_TTL 2>/dev/null || echo "declare -gA SUBMENU_CACHE_TTL=()"

    # Dirbrowser data
    declare -p DIRBROWSE_DIR 2>/dev/null || echo "declare -gA DIRBROWSE_DIR=()"
    declare -p DIRBROWSE_DEPTH 2>/dev/null || echo "declare -gA DIRBROWSE_DEPTH=()"
    declare -p DIRBROWSE_SORT 2>/dev/null || echo "declare -gA DIRBROWSE_SORT=()"
    declare -p DIRBROWSE_SORT_DIRECTION 2>/dev/null || echo "declare -gA DIRBROWSE_SORT_DIRECTION=()"
    declare -p DIRBROWSE_WIDTH 2>/dev/null || echo "declare -gA DIRBROWSE_WIDTH=()"
    declare -p DIRBROWSE_HEIGHT 2>/dev/null || echo "declare -gA DIRBROWSE_HEIGHT=()"
    declare -p DIRBROWSE_CACHE_TTL 2>/dev/null || echo "declare -gA DIRBROWSE_CACHE_TTL=()"
    declare -p DIRBROWSE_SHORTCUT 2>/dev/null || echo "declare -gA DIRBROWSE_SHORTCUT=()"
    declare -p DIRBROWSE_ORDER 2>/dev/null || echo "declare -ga DIRBROWSE_ORDER=()"

    # Taskrunner data
    declare -p TASKRUNNER_ENABLED 2>/dev/null || echo "declare -gA TASKRUNNER_ENABLED=()"
    declare -p TASKRUNNER_ICON 2>/dev/null || echo "declare -gA TASKRUNNER_ICON=()"
    declare -p TASKRUNNER_LABEL 2>/dev/null || echo "declare -gA TASKRUNNER_LABEL=()"
    declare -p TASKRUNNER_PRIMARY_ACTION 2>/dev/null || echo "declare -gA TASKRUNNER_PRIMARY_ACTION=()"
    declare -p TASKRUNNER_SECONDARY_ACTION 2>/dev/null || echo "declare -gA TASKRUNNER_SECONDARY_ACTION=()"
    declare -p TASKRUNNER_ORDER 2>/dev/null || echo "declare -ga TASKRUNNER_ORDER=()"
    declare -p LOADED_TASKRUNNERS 2>/dev/null || echo "declare -ga LOADED_TASKRUNNERS=()"
  } > "$cache_file"
}

# vim: ft=bash ts=2 sw=2 et
