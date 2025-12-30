#!/usr/bin/env bash
#
# lib/utils.sh - Shared utilities for nunchux
#

# Guard against double-sourcing
[[ -n "${NUNCHUX_LIB_UTILS_LOADED:-}" ]] && return
NUNCHUX_LIB_UTILS_LOADED=1

# Platform detection for GNU vs BSD tools
if [[ "$OSTYPE" == "darwin"* ]]; then
  IS_MACOS=true
else
  IS_MACOS=false
fi

# Get file modification time as epoch seconds (cross-platform)
get_mtime() {
  if $IS_MACOS; then
    stat -f %m "$1" 2>/dev/null || echo 0
  else
    stat -c %Y "$1" 2>/dev/null || echo 0
  fi
}

# Find files with mtime - outputs: mtime\tpath (cross-platform)
# Usage: find_with_mtime "${find_args[@]}"
find_with_mtime() {
  if $IS_MACOS; then
    # BSD find doesn't have -printf, use stat instead
    find "$@" -exec stat -f '%m' {} \; -print 2>/dev/null | paste - -
  else
    find "$@" -printf '%T@\t%p\n' 2>/dev/null
  fi
}

# Format seconds ago as human-readable string
format_ago() {
  local secs="$1"
  if [[ $secs -lt 60 ]]; then
    echo "${secs}s ago"
  elif [[ $secs -lt 3600 ]]; then
    echo "$((secs / 60))m ago"
  elif [[ $secs -lt 86400 ]]; then
    echo "$((secs / 3600))h ago"
  else
    echo "$((secs / 86400))d ago"
  fi
}

# Minimum required fzf version (for unix socket support)
FZF_MIN_VERSION="0.66"

# Check fzf version meets minimum requirement
# Caches result based on fzf binary mtime to avoid repeated checks
check_fzf_version() {
  local fzf_path cache_file fzf_mtime cached_mtime

  fzf_path=$(command -v fzf 2>/dev/null) || {
    echo "fzf is not installed" >&2
    return 1
  }

  cache_file="/tmp/nunchux-fzf-version-ok"
  fzf_mtime=$(get_mtime "$fzf_path")

  # Check cache
  if [[ -f "$cache_file" ]]; then
    cached_mtime=$(cat "$cache_file" 2>/dev/null)
    if [[ "$cached_mtime" == "$fzf_mtime" ]]; then
      return 0 # Cached OK
    fi
  fi

  # Parse version
  local version major minor
  version=$(fzf --version 2>/dev/null | head -1 | grep -oE '^[0-9]+\.[0-9]+' || echo "0.0")
  major="${version%%.*}"
  minor="${version#*.}"
  minor="${minor%%.*}"

  # Check if >= 0.66
  if [[ "$major" -gt 0 ]] || [[ "$major" -eq 0 && "$minor" -ge 66 ]]; then
    echo "$fzf_mtime" >"$cache_file"
    return 0
  fi

  echo "fzf $version is too old (need $FZF_MIN_VERSION+)" >&2
  return 1
}

# vim: ft=bash ts=2 sw=2 et
