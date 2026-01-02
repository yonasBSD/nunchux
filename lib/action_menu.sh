#!/usr/bin/env bash
#
# action_menu.sh - Action selection menu for nunchux
#
# This module handles displaying and selecting launch actions.
# It's designed to be extensible for future user-defined actions.
#

# Constant for cancelled action (avoids magic strings)
ACTION_CANCELLED="__cancel__"

# Built-in actions available for all items
# Format: "action_id<tab>Display label"
_get_builtin_actions() {
  cat <<'EOF'
popup	Open in popup
window	Open in window
background_window	Open in background window
pane_horizontal	Open in horizontal split
pane_vertical	Open in vertical split
EOF
}

# Resolve the action for a key press
# Handles: direct action keys, action menu, primary/secondary fallback
# Arguments:
#   $1 - key pressed
#   $2 - item name (for action menu title)
#   $3 - primary action (fallback for Enter)
#   $4 - secondary action (fallback for secondary key)
# Returns:
#   - action name on stdout
#   - ACTION_CANCELLED if user cancelled action menu
resolve_action() {
  local key="$1"
  local item_name="$2"
  local primary_action="$3"
  local secondary_action="$4"

  local action
  action=$(key_to_action "$key")

  if [[ "$action" == "action_menu" ]]; then
    action=$(show_action_menu "$item_name")
    [[ "$action" == "$ACTION_CANCELLED" ]] && { echo "$ACTION_CANCELLED"; return; }
  fi

  if [[ -z "$action" ]]; then
    if [[ "$key" == "$SECONDARY_KEY" ]]; then
      echo "$secondary_action"
    else
      echo "$primary_action"
    fi
  else
    echo "$action"
  fi
}

# Show action selection menu and return selected action
# Arguments:
#   $1 - item name (shown in menu title)
# Returns:
#   - selected action name on stdout
#   - ACTION_CANCELLED if user pressed Esc
show_action_menu() {
  local item_name="${1:-}"
  local label=" Action "
  [[ -n "$item_name" ]] && label=" Action: $item_name "

  local selected
  selected=$(_get_builtin_actions | fzf \
    --delimiter='	' \
    --with-nth=2 \
    --height=100% \
    --layout=reverse \
    --border=rounded \
    --border-label="$label" \
    --no-info \
    --prompt=" " \
    --color="$FZF_COLORS" \
    | cut -f1)

  if [[ -n "$selected" ]]; then
    echo "$selected"
  else
    echo "$ACTION_CANCELLED"
  fi
}

# vim: ft=bash ts=2 sw=2 et
