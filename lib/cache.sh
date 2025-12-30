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

# vim: ft=bash ts=2 sw=2 et
