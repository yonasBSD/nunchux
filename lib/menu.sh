#!/usr/bin/env bash
#
# lib/menu.sh - fzf menu integration for nunchux
#

# Guard against double-sourcing
[[ -n "${NUNCHUX_LIB_MENU_LOADED:-}" ]] && return
NUNCHUX_LIB_MENU_LOADED=1

# FZF styling defaults (can be overridden in config)
FZF_PROMPT="${FZF_PROMPT:- }"
FZF_POINTER="${FZF_POINTER:-▶}"
FZF_BORDER="${FZF_BORDER:-none}"
FZF_BORDER_LABEL="${FZF_BORDER_LABEL:- nunchux }"
FZF_COLORS="${FZF_COLORS:-fg+:white:bold,bg+:-1,hl:cyan,hl+:cyan:bold,pointer:cyan,marker:green,header:gray,border:gray}"

# Build common fzf options array
# Usage: build_fzf_opts opts_array "header text"
build_fzf_opts() {
  local -n opts=$1
  local header="$2"
  opts=(
    --delimiter='\t'
    --with-nth=1
    --tiebreak=begin
    --header="$header"
    --header-first
    --prompt="$FZF_PROMPT"
    --pointer="$FZF_POINTER"
    --layout=reverse
    --height=100%
    --border="$FZF_BORDER"
    --no-preview
    --expect="$SECONDARY_KEY"
    --color="$FZF_COLORS"
  )
}

# Parse fzf selection output (handles --expect keys)
# Returns: key on first line, selection on second
# Usage: parse_fzf_selection "$selection"
parse_fzf_selection() {
  local selection="$1"
  local key selected_line
  key=$(echo "$selection" | head -1)
  selected_line=$(echo "$selection" | tail -1)
  printf '%s\n%s\n' "$key" "$selected_line"
}

# vim: ft=bash ts=2 sw=2 et
