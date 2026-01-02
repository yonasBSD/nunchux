#!/usr/bin/env bash
#
# lib/menu.sh - fzf menu integration for nunchux
#

# Guard against double-sourcing
[[ -n "${NUNCHUX_LIB_MENU_LOADED:-}" ]] && return
NUNCHUX_LIB_MENU_LOADED=1

# Show shortcuts column (toggled with ctrl-/)
SHOW_SHORTCUTS="${SHOW_SHORTCUTS:-}"

# FZF styling defaults (can be overridden in config)
FZF_PROMPT="${FZF_PROMPT:- }"
FZF_POINTER="${FZF_POINTER:-▶}"
FZF_BORDER="${FZF_BORDER:-none}"
FZF_COLORS="${FZF_COLORS:-fg+:white:bold,bg+:-1,hl:cyan,hl+:cyan:bold,pointer:cyan,marker:green,header:gray,border:gray}"

# Label used in borders and popup titles (can be overridden in config)
NUNCHUX_LABEL="${NUNCHUX_LABEL:-nunchux}"
FZF_BORDER_LABEL=" $NUNCHUX_LABEL "

# Build border label with optional cwd
# Usage: build_border_label [submenu_name]
# Sets FZF_BORDER_LABEL global variable
build_border_label() {
  local submenu="${1:-}"
  local label=" $NUNCHUX_LABEL"

  # Add submenu if provided
  if [[ -n "$submenu" ]]; then
    label="$label: $submenu"
  fi

  # Add cwd if configured
  if [[ "${SHOW_CWD:-true}" == "true" ]]; then
    local cwd
    cwd=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null || pwd)
    # Shorten home directory to ~
    cwd="${cwd/#$HOME/\~}"
    label="$label ($cwd)"
  fi

  FZF_BORDER_LABEL="$label "
}

# Build common fzf options array
# Usage: build_fzf_opts opts_array "header text"
build_fzf_opts() {
  local -n opts=$1
  local header="$2"

  # Build expect list: secondary key + all action keys + action menu key
  local expect_keys="$SECONDARY_KEY"
  [[ -n "$POPUP_KEY" ]] && expect_keys="$expect_keys,$POPUP_KEY"
  [[ -n "$WINDOW_KEY" ]] && expect_keys="$expect_keys,$WINDOW_KEY"
  [[ -n "$BACKGROUND_WINDOW_KEY" ]] && expect_keys="$expect_keys,$BACKGROUND_WINDOW_KEY"
  [[ -n "$PANE_HORIZONTAL_KEY" ]] && expect_keys="$expect_keys,$PANE_HORIZONTAL_KEY"
  [[ -n "$PANE_VERTICAL_KEY" ]] && expect_keys="$expect_keys,$PANE_VERTICAL_KEY"
  [[ -n "$ACTION_MENU_KEY" ]] && expect_keys="$expect_keys,$ACTION_MENU_KEY"

  opts=(
    --ansi
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
    --border-label="$FZF_BORDER_LABEL"
    --border-label-pos=3
    --no-preview
    --expect="$expect_keys"
    --color="$FZF_COLORS"
  )
}

# Map a pressed key to an action
# Usage: action=$(key_to_action "$key")
# Returns:
#   - action name (popup, window, etc.) for direct action keys
#   - "action_menu" for ACTION_MENU_KEY (caller should show menu)
#   - empty string if key doesn't map to any action
key_to_action() {
  local key="$1"
  # Empty key (e.g., Enter pressed) doesn't map to any action
  [[ -z "$key" ]] && return
  case "$key" in
    "$POPUP_KEY") [[ -n "$POPUP_KEY" ]] && echo "popup" ;;
    "$WINDOW_KEY") [[ -n "$WINDOW_KEY" ]] && echo "window" ;;
    "$BACKGROUND_WINDOW_KEY") [[ -n "$BACKGROUND_WINDOW_KEY" ]] && echo "background_window" ;;
    "$PANE_HORIZONTAL_KEY") [[ -n "$PANE_HORIZONTAL_KEY" ]] && echo "pane_horizontal" ;;
    "$PANE_VERTICAL_KEY") [[ -n "$PANE_VERTICAL_KEY" ]] && echo "pane_vertical" ;;
    "$ACTION_MENU_KEY") [[ -n "$ACTION_MENU_KEY" ]] && echo "action_menu" ;;
  esac
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

# Build fzf --bind options for all registered shortcuts
# Usage: build_shortcut_binds binds_array script_path
build_shortcut_binds() {
  local -n binds=$1
  local script_path="$2"

  for key in "${!SHORTCUT_REGISTRY[@]}"; do
    local item="${SHORTCUT_REGISTRY[$key]}"
    binds+=("--bind=$key:become($script_path --launch-shortcut '$item')")
  done
}

# Build shortcut prefix for menu display (legacy - returns empty, shortcuts added at display time)
# Usage: prefix=$(build_shortcut_prefix "$shortcut")
build_shortcut_prefix() {
  # Always return empty - shortcuts are now added dynamically via add_shortcut_prefixes
  return
}

# Add shortcut prefixes to menu lines
# Reads from stdin, writes to stdout
# Menu line format: display\tshortcut\trest...
# If shortcut field is non-empty, prepends [shortcut] │ to display
add_shortcut_prefixes() {
  while IFS= read -r line; do
    # Use cut to properly handle empty fields (bash read collapses consecutive delimiters)
    local display shortcut rest
    display=$(printf '%s' "$line" | cut -f1)
    shortcut=$(printf '%s' "$line" | cut -f2)
    rest=$(printf '%s' "$line" | cut -f3-)

    if [[ -n "$shortcut" ]]; then
      printf '\033[38;5;244m%-9s\033[0m│ %s\t%s\t%s\n' "[$shortcut]" "$display" "$shortcut" "$rest"
    else
      printf '%9s│ %s\t%s\t%s\n' "" "$display" "$shortcut" "$rest"
    fi
  done
}

# vim: ft=bash ts=2 sw=2 et
